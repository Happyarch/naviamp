import 'package:collection/collection.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import '../models/jellyfin_models.dart';
import 'downloads_service.dart';
import 'finamp_settings_helper.dart';
import 'subsonic_api_helper.dart';

final metadataProviderLogger = Logger("MetadataProvider");

/// A storage container for metadata about a track.  The codec information will reflect
/// the downloaded file if appropriate, even for transcoded downloads.  Online
/// transcoding will not be reflected.
class MetadataProvider {
  static const speedControlGenres = ["audiobook", "podcast", "speech"];
  static const speedControlLongTrackDuration = Duration(minutes: 15);
  static const speedControlLongAlbumDuration = Duration(hours: 3);

  final PlaybackInfoResponse playbackInfo;
  final BaseItemDto item;
  LyricDto? lyrics;
  bool isDownloaded;
  bool qualifiesForPlaybackSpeedControl;
  double? parentNormalizationGain;

  MetadataProvider({
    required this.item,
    required this.playbackInfo,
    this.lyrics,
    this.isDownloaded = false,
    this.qualifiesForPlaybackSpeedControl = false,
    this.parentNormalizationGain,
  });

  MediaSourceInfo get mediaSourceInfo => playbackInfo.mediaSources!.first;

  bool get hasLyrics => mediaSourceInfo.mediaStreams.any((e) => e.type == "Lyric");
}

/// Synthesises a [PlaybackInfoResponse] from the song's own [BaseItemDto].
/// The DTO is populated by [SubsonicApiHelper._childToDto] with audio codec
/// metadata from the Subsonic response.
PlaybackInfoResponse _buildPlaybackInfo(BaseItemDto item) {
  final source = item.mediaSources?.firstOrNull;
  if (source != null) {
    return PlaybackInfoResponse(mediaSources: [source]);
  }
  // Fallback for items without mediaSources (should not happen for songs).
  return PlaybackInfoResponse(
    mediaSources: [
      MediaSourceInfo(
        id: item.id,
        protocol: 'Http',
        type: 'Default',
        isRemote: true,
        supportsTranscoding: true,
        supportsDirectStream: true,
        supportsDirectPlay: false,
        isInfiniteStream: false,
        requiresOpening: false,
        requiresClosing: false,
        requiresLooping: false,
        supportsProbing: false,
        readAtNativeFramerate: false,
        ignoreDts: false,
        ignoreIndex: false,
        genPtsInput: false,
        container: item.container,
        name: item.name,
        runTimeTicks: item.runTimeTicks,
        mediaStreams: const [],
      ),
    ],
  );
}

final AutoDisposeFutureProviderFamily<MetadataProvider?, BaseItemDto> metadataProvider = FutureProvider.autoDispose
    .family<MetadataProvider?, BaseItemDto>((ref, item) async {
      Future<BaseItemDto?>? parentFuture;
      if (item.parentId != null) {
        parentFuture = ref.watch(albumProvider(item.parentId!).future);
      }

      final subsonicApiHelper = GetIt.instance<SubsonicApiHelper>();
      final downloadsService = GetIt.instance<DownloadsService>();

      metadataProviderLogger.fine("Fetching metadata for '${item.name}' (${item.id})");

      PlaybackInfoResponse? playbackInfo;
      PlaybackInfoResponse? localPlaybackInfo;

      final downloadStub = await downloadsService.getTrackInfo(id: item.id);
      if (downloadStub != null) {
        final downloadItem = await ref.watch(downloadsService.itemProvider(downloadStub).future);
        if (downloadItem != null && downloadItem.state.isComplete) {
          metadataProviderLogger.fine("Got offline metadata for '${item.name}'");
          var profile = downloadItem.fileTranscodingProfile;
          var audioStream =
              downloadItem.baseItem!.mediaStreams?.firstWhereOrNull((s) => s.type == "Audio") ??
              downloadItem.baseItem!.mediaStreams?.firstOrNull;
          var codec = profile?.codec != FinampTranscodingCodec.original ? profile?.codec.name : audioStream?.codec;
          var container = profile?.codec != FinampTranscodingCodec.original
              ? profile?.codec.container
              : downloadItem.baseItem!.mediaSources?.firstOrNull?.container;
          var bitrate = profile?.codec != FinampTranscodingCodec.original
              ? profile?.stereoBitrate
              : downloadItem.baseItem!.mediaSources?.firstOrNull?.bitrate;

          List<MediaStream> mediaStream = profile?.codec != FinampTranscodingCodec.original
              ? [
                      MediaStream(
                        index: 0,
                        type: "Audio",
                        codec: codec,
                        bitRate: bitrate,
                        sampleRate: null,
                        channels: null,
                        bitDepth: null,
                        isInterlaced: false,
                        isDefault: true,
                        isForced: false,
                        isExternal: false,
                        isTextSubtitleStream: false,
                        supportsExternalStream: false,
                      ),
                    ]
                    .followedBy(downloadItem.baseItem!.mediaStreams?.where((x) => x.type == "Lyric").toList() ?? [])
                    .toList()
              : downloadItem.baseItem!.mediaStreams ?? [];

          localPlaybackInfo = PlaybackInfoResponse(
            mediaSources: [
              MediaSourceInfo(
                id: downloadItem.baseItem!.id,
                protocol: "File",
                type: "Default",
                isRemote: false,
                supportsTranscoding: false,
                supportsDirectStream: false,
                supportsDirectPlay: true,
                isInfiniteStream: false,
                requiresOpening: false,
                requiresClosing: false,
                requiresLooping: false,
                supportsProbing: false,
                mediaStreams: mediaStream,
                readAtNativeFramerate: false,
                ignoreDts: false,
                ignoreIndex: false,
                genPtsInput: false,
                bitrate: bitrate,
                container: container,
                name: downloadItem.baseItem!.mediaSources?.first.name,
                size: await downloadsService.getFileSize(downloadStub),
              ),
            ],
          );
        }
      }

      if (ref.watch(finampSettingsProvider.isOffline)) {
        playbackInfo = localPlaybackInfo;
      } else {
        // Build playback info from the song's own DTO (populated by _childToDto).
        playbackInfo = _buildPlaybackInfo(item);

        // Merge downloaded file metadata when available.
        if (localPlaybackInfo != null && (playbackInfo.mediaSources?.isNotEmpty ?? false)) {
          playbackInfo.mediaSources!.first.protocol = localPlaybackInfo.mediaSources!.first.protocol;
          playbackInfo.mediaSources!.first.bitrate = localPlaybackInfo.mediaSources!.first.bitrate;
          var remoteBitDepth = playbackInfo.mediaSources!.first.mediaStreams
              .firstWhereOrNull((x) => x.type == "Audio")
              ?.bitDepth;
          playbackInfo.mediaSources!.first.mediaStreams = playbackInfo.mediaSources!.first.mediaStreams
              .where((x) => x.type == "Lyric")
              .toList();
          playbackInfo.mediaSources!.first.mediaStreams.addAll(
            localPlaybackInfo.mediaSources!.first.mediaStreams.where((x) => x.type != "Lyric"),
          );
          var audioStream = playbackInfo.mediaSources!.first.mediaStreams.firstWhereOrNull((x) => x.type == "Audio");
          if (audioStream != null) {
            audioStream.bitDepth = remoteBitDepth;
          }
          playbackInfo.mediaSources!.first.container = localPlaybackInfo.mediaSources!.first.container;
          playbackInfo.mediaSources!.first.size = localPlaybackInfo.mediaSources!.first.size;
        }
      }

      if (playbackInfo == null) {
        metadataProviderLogger.warning("Couldn't load metadata for '${item.name}' (${item.id})");
        return null;
      }

      BaseItemDto? parent;
      if (parentFuture != null) {
        parent = await parentFuture;
      }

      final metadata = MetadataProvider(
        item: item,
        playbackInfo: playbackInfo,
        isDownloaded: localPlaybackInfo != null,
        parentNormalizationGain: parent?.normalizationGain,
      );

      for (final genre in item.genres ?? []) {
        if (MetadataProvider.speedControlGenres.contains(genre.toLowerCase())) {
          metadata.qualifiesForPlaybackSpeedControl = true;
          break;
        }
      }
      if (!metadata.qualifiesForPlaybackSpeedControl &&
          (metadata.mediaSourceInfo.runTimeTicks ?? 0) >
              MetadataProvider.speedControlLongTrackDuration.inMicroseconds * 10) {
        metadata.qualifiesForPlaybackSpeedControl = true;
      }

      if (!metadata.qualifiesForPlaybackSpeedControl &&
          parent != null &&
          (parent.runTimeTicks ?? 0) > MetadataProvider.speedControlLongAlbumDuration.inMicroseconds * 10) {
        metadata.qualifiesForPlaybackSpeedControl = true;
      }

      // Lyrics: try fetching from server when online, offline download when offline.
      if (ref.watch(finampSettingsProvider.isOffline)) {
        final downloadedLyrics = await downloadsService.getLyricsDownload(baseItem: item);
        if (downloadedLyrics != null) {
          metadata.lyrics = downloadedLyrics.lyricDto;
          metadataProviderLogger.fine("Got offline lyrics for '${item.name}'");
        } else {
          metadataProviderLogger.fine("No offline lyrics for '${item.name}'");
        }
      } else {
        metadataProviderLogger.fine("Fetching lyrics for '${item.name}' (${item.id})");
        try {
          metadata.lyrics = await subsonicApiHelper.getLyricsAsDto(item.id.raw);
        } catch (e) {
          metadataProviderLogger.warning(
            "Failed to fetch lyrics for '${item.name}' (${item.id}). Metadata might be stale",
            e,
          );
        }
      }

      metadataProviderLogger.fine(
        "Fetched metadata for '${item.name}' (${item.id}): ${metadata.lyrics} ${metadata.hasLyrics}",
      );

      return metadata;
    });

final AutoDisposeFutureProviderFamily<BaseItemDto?, BaseItemId> albumProvider = FutureProvider.autoDispose
    .family<BaseItemDto?, BaseItemId>((ref, parentId) async {
      final subsonicApiHelper = GetIt.instance<SubsonicApiHelper>();
      final downloadsService = GetIt.instance<DownloadsService>();

      if (ref.watch(finampSettingsProvider.isOffline)) {
        final parentInfo = await downloadsService.getCollectionInfo(id: parentId);
        if (parentInfo == null) {
          metadataProviderLogger.warning("Couldn't find parent collection '$parentId' in offline mode");
        } else if (parentInfo.baseItem == null) {
          metadataProviderLogger.warning("Offline metadata for '$parentId' does not include jellyfin BaseItemDto");
        } else {
          return parentInfo.baseItem;
        }
      } else {
        return await subsonicApiHelper.getAlbumDto(parentId);
      }
      return null;
    });
