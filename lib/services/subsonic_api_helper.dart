import 'dart:convert';

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../models/jellyfin_models.dart';
import '../models/subsonic_models.dart';
import 'subsonic_api.dart';
import 'subsonic_user_helper.dart';

final _log = Logger('SubsonicApiHelper');

const _apiVersion = '1.16.1';
const _clientName = 'naviamp';
const _secondsToTicks = 10000000; // 1 s = 10,000,000 × 100 ns ticks

class SubsonicApiHelper {
  final _api = SubsonicApi.create();
  final _userHelper = GetIt.instance<SubsonicUserHelper>();

  // ── Ping / server probe ───────────────────────────────────────────────────

  /// Full authenticated ping. Returns server metadata; throws [SubsonicException]
  /// on auth failure or server error.
  Future<SubsonicServerInfo> ping() async {
    final inner = _unwrap(await _api.ping());
    _log.fine('ping ok: ${inner['version']}');
    return SubsonicServerInfo.fromInner(inner);
  }

  /// Probes [url] to check if a Subsonic-compatible server is present.
  /// Does NOT require credentials — error 10 (missing params) still means a
  /// valid Subsonic server. Returns null if the URL is unreachable or not
  /// a Subsonic server.
  ///
  /// Uses a plain HTTP client to avoid Chopper's converter pipeline, which
  /// has issues parsing responses without credentials.
  Future<SubsonicServerInfo?> probeServer(String url) async {
    final normalised = url.trim().replaceAll(RegExp(r'/+$'), '');
    try {
      final uri = Uri.parse('$normalised/rest/ping.view').replace(
        queryParameters: {'v': _apiVersion, 'c': _clientName, 'f': 'json'},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (!body.containsKey('subsonic-response')) return null;
      return SubsonicServerInfo.fromInner(
        body['subsonic-response'] as Map<String, dynamic>,
      );
    } catch (e) {
      _log.warning('probeServer failed for $normalised: $e');
      return null;
    }
  }

  // ── Music folders (libraries) ─────────────────────────────────────────────

  Future<List<BaseItemDto>> getMusicFolders() async {
    final inner = _unwrap(await _api.getMusicFolders());
    final data = SubsonicMusicFolders.fromJson(inner['musicFolders'] as Map<String, dynamic>);
    return [
      for (final folder in data.musicFolder ?? <SubsonicMusicFolder>[])
        BaseItemDto(
          id: BaseItemId(folder.id.toString()),
          name: folder.name,
          collectionType: 'music',
          type: 'CollectionFolder',
        ),
    ];
  }

  // ── Artists ───────────────────────────────────────────────────────────────

  Future<List<BaseItemDto>> getArtists({int? musicFolderId}) async {
    final inner = _unwrap(await _api.getArtists(musicFolderId: musicFolderId));
    final data = SubsonicArtistsID3.fromJson(inner['artists'] as Map<String, dynamic>);
    return [
      for (final index in data.index ?? <SubsonicIndexID3>[])
        for (final artist in index.artist ?? <SubsonicArtistID3>[])
          _artistToDto(artist),
    ];
  }

  /// Returns (artist, albums). Call when opening an artist detail page.
  Future<(BaseItemDto, List<BaseItemDto>)> getArtist(String id) async {
    final inner = _unwrap(await _api.getArtist(id: id));
    final artist = SubsonicArtistWithAlbumsID3.fromJson(inner['artist'] as Map<String, dynamic>);
    return (
      _artistToDto(artist),
      (artist.album ?? <SubsonicAlbumID3>[]).map(_albumToDto).toList(),
    );
  }

  // ── Albums ────────────────────────────────────────────────────────────────

  /// Returns (album, songs). Call when opening an album detail page.
  Future<(BaseItemDto, List<BaseItemDto>)> getAlbum(String id) async {
    final inner = _unwrap(await _api.getAlbum(id: id));
    final album = SubsonicAlbumWithSongsID3.fromJson(inner['album'] as Map<String, dynamic>);
    return (
      _albumToDto(album),
      (album.song ?? <SubsonicChild>[]).map(_childToDto).toList(),
    );
  }

  /// Returns just the album [BaseItemDto] for a given album ID.
  Future<BaseItemDto?> getAlbumDto(BaseItemId id) async {
    try {
      final (album, _) = await getAlbum(id.raw);
      return album;
    } catch (e) {
      _log.warning('getAlbumDto failed for ${id.raw}: $e');
      return null;
    }
  }

  Future<List<BaseItemDto>> getAlbumList2({
    required String type,
    int? size,
    int? offset,
    int? fromYear,
    int? toYear,
    String? genre,
    int? musicFolderId,
  }) async {
    final inner = _unwrap(await _api.getAlbumList2(
      type: type,
      size: size,
      offset: offset,
      fromYear: fromYear,
      toYear: toYear,
      genre: genre,
      musicFolderId: musicFolderId,
    ));
    final list = SubsonicAlbumList2.fromJson(inner['albumList2'] as Map<String, dynamic>);
    return (list.album ?? <SubsonicAlbumID3>[]).map(_albumToDto).toList();
  }

  /// Returns just the song [BaseItemDto] for a given song ID, or null on error.
  Future<BaseItemDto?> getSongDto(String id) async {
    try {
      final inner = _unwrap(await _api.getSong(id: id));
      final song = SubsonicChild.fromJson(inner['song'] as Map<String, dynamic>);
      return _childToDto(song);
    } catch (e) {
      _log.warning('getSongDto failed for $id: $e');
      return null;
    }
  }

  /// Fetches all albums (paginated) for the given music folder, or all folders
  /// if [musicFolderId] is null. Stops when a page returns fewer than [pageSize].
  Future<List<BaseItemDto>> getAllAlbums({int? musicFolderId, int pageSize = 500}) async {
    final albums = <BaseItemDto>[];
    var offset = 0;
    while (true) {
      final page = await getAlbumList2(
        type: 'alphabeticalByName',
        size: pageSize,
        offset: offset,
        musicFolderId: musicFolderId,
      );
      albums.addAll(page);
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return albums;
  }

  // ── Songs ─────────────────────────────────────────────────────────────────

  Future<List<BaseItemDto>> getRandomSongs({
    int? size,
    String? genre,
    int? fromYear,
    int? toYear,
    int? musicFolderId,
  }) async {
    final inner = _unwrap(await _api.getRandomSongs(
      size: size,
      genre: genre,
      fromYear: fromYear,
      toYear: toYear,
      musicFolderId: musicFolderId,
    ));
    final list = SubsonicSongList.fromJson(inner['randomSongs'] as Map<String, dynamic>);
    return (list.song ?? <SubsonicChild>[]).map(_childToDto).toList();
  }

  Future<List<BaseItemDto>> getSongsByGenre(
    String genre, {
    int? count,
    int? offset,
    int? musicFolderId,
  }) async {
    final inner = _unwrap(await _api.getSongsByGenre(
      genre: genre,
      count: count,
      offset: offset,
      musicFolderId: musicFolderId,
    ));
    final list = SubsonicSongsByGenre.fromJson(inner['songsByGenre'] as Map<String, dynamic>);
    return (list.child ?? <SubsonicChild>[]).map(_childToDto).toList();
  }

  // ── Genres ────────────────────────────────────────────────────────────────

  Future<List<BaseItemDto>> getGenres() async {
    final inner = _unwrap(await _api.getGenres());
    final data = SubsonicGenres.fromJson(inner['genres'] as Map<String, dynamic>);
    return (data.genre ?? <SubsonicGenre>[]).map(_genreToDto).toList();
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<({List<BaseItemDto> artists, List<BaseItemDto> albums, List<BaseItemDto> songs})>
      search3(
    String query, {
    int? artistCount,
    int? albumCount,
    int? songCount,
    int? artistOffset,
    int? albumOffset,
    int? songOffset,
    int? musicFolderId,
  }) async {
    final inner = _unwrap(await _api.search3(
      query: query,
      artistCount: artistCount,
      albumCount: albumCount,
      songCount: songCount,
      artistOffset: artistOffset,
      albumOffset: albumOffset,
      songOffset: songOffset,
      musicFolderId: musicFolderId,
    ));
    final result = SubsonicSearchResult3.fromJson(inner['searchResult3'] as Map<String, dynamic>);
    return (
      artists: (result.artist ?? <SubsonicArtistID3>[]).map(_artistToDto).toList(),
      albums: (result.album ?? <SubsonicAlbumID3>[]).map(_albumToDto).toList(),
      songs: (result.song ?? <SubsonicChild>[]).map(_childToDto).toList(),
    );
  }

  // ── Starred ───────────────────────────────────────────────────────────────

  Future<({List<BaseItemDto> artists, List<BaseItemDto> albums, List<BaseItemDto> songs})>
      getStarred({int? musicFolderId}) async {
    final inner = _unwrap(await _api.getStarred2(musicFolderId: musicFolderId));
    final starred = SubsonicStarred2.fromJson(inner['starred2'] as Map<String, dynamic>);
    return (
      artists: (starred.artist ?? <SubsonicArtistID3>[]).map(_artistToDto).toList(),
      albums: (starred.album ?? <SubsonicAlbumID3>[]).map(_albumToDto).toList(),
      songs: (starred.song ?? <SubsonicChild>[]).map(_childToDto).toList(),
    );
  }

  Future<void> star({String? id, String? albumId, String? artistId}) async {
    _unwrap(await _api.star(id: id, albumId: albumId, artistId: artistId));
  }

  Future<void> unstar({String? id, String? albumId, String? artistId}) async {
    _unwrap(await _api.unstar(id: id, albumId: albumId, artistId: artistId));
  }

  // ── Playlists ─────────────────────────────────────────────────────────────

  Future<List<BaseItemDto>> getPlaylists() async {
    final inner = _unwrap(await _api.getPlaylists());
    final data = SubsonicPlaylists.fromJson(inner['playlists'] as Map<String, dynamic>);
    return (data.playlist ?? <SubsonicPlaylist>[]).map(_playlistToDto).toList();
  }

  /// Returns (playlist metadata, songs).
  Future<(BaseItemDto, List<BaseItemDto>)> getPlaylist(String id) async {
    final inner = _unwrap(await _api.getPlaylist(id: id));
    final playlist = SubsonicPlaylistWithSongs.fromJson(inner['playlist'] as Map<String, dynamic>);
    return (
      _playlistToDto(playlist),
      (playlist.entry ?? <SubsonicChild>[]).map(_childToDto).toList(),
    );
  }

  Future<void> createPlaylist({String? name, List<String>? songIds}) async {
    _unwrap(await _api.createPlaylist(name: name, songId: songIds));
  }

  Future<void> updatePlaylist({
    required String id,
    String? name,
    String? comment,
    bool? public,
    List<String>? songIdsToAdd,
    List<int>? songIndexesToRemove,
  }) async {
    _unwrap(await _api.updatePlaylist(
      playlistId: id,
      name: name,
      comment: comment,
      public: public,
      songIdToAdd: songIdsToAdd,
      songIndexToRemove: songIndexesToRemove,
    ));
  }

  Future<void> deletePlaylist(String id) async {
    _unwrap(await _api.deletePlaylist(id: id));
  }

  // ── Scrobble ──────────────────────────────────────────────────────────────

  Future<void> scrobble({required String id, int? time, bool? submission}) async {
    _unwrap(await _api.scrobble(id: id, time: time, submission: submission));
  }

  // ── Similar / Mix ─────────────────────────────────────────────────────────

  Future<List<BaseItemDto>> getSimilarSongs2(String id, {int? count}) async {
    final inner = _unwrap(await _api.getSimilarSongs2(id: id, count: count));
    final list = SubsonicSongList.fromJson(inner['similarSongs2'] as Map<String, dynamic>);
    return (list.song ?? <SubsonicChild>[]).map(_childToDto).toList();
  }

  Future<List<BaseItemDto>> getInstantMix(String id, {int? count, int? offset}) async {
    final inner = _unwrap(await _api.getInstantMix(id: id, count: count, offset: offset));
    final list = SubsonicSongList.fromJson(inner['instantMix'] as Map<String, dynamic>);
    return (list.song ?? <SubsonicChild>[]).map(_childToDto).toList();
  }

  // ── Lyrics ────────────────────────────────────────────────────────────────

  Future<SubsonicLyricsList?> getLyricsBySongId(String id) async {
    final inner = _unwrap(await _api.getLyricsBySongId(id: id));
    if (!inner.containsKey('lyricsList')) return null;
    return SubsonicLyricsList.fromJson(inner['lyricsList'] as Map<String, dynamic>);
  }

  /// Fetches lyrics for [id] and converts them to a [LyricDto] compatible with
  /// the Finamp player. Prefers synced lyrics; falls back to unsynced. Returns
  /// null if the server has no lyrics for this song.
  Future<LyricDto?> getLyricsAsDto(String id) async {
    final list = await getLyricsBySongId(id);
    if (list == null || (list.structuredLyrics?.isEmpty ?? true)) return null;

    // Prefer synced; fall back to unsynced.
    final best = list.structuredLyrics!.firstWhere(
      (l) => l.synced,
      orElse: () => list.structuredLyrics!.first,
    );

    final offsetMs = best.offset?.round() ?? 0;
    return LyricDto(
      lyrics: best.line.map((l) {
        final startTicks = l.start != null ? (l.start! + offsetMs) * 10000 : null;
        return LyricLine(text: l.value, start: startTicks);
      }).toList(),
    );
  }

  // ── URL builders ──────────────────────────────────────────────────────────

  /// Cover art URL. Uses the coverArt ID stored in `imageTags['Primary']`.
  /// Returns null if the item has no cover art.
  Uri? getCoverArtUrl(BaseItemDto item, {int? size}) {
    final coverArtId = item.imageTags?['Primary'];
    if (coverArtId == null || coverArtId.isEmpty) return null;
    return _buildAuthUri('/rest/getCoverArt.view', {
      'id': coverArtId,
      if (size != null) 'size': size.toString(),
    });
  }

  /// Direct stream URL for a song. Specify [format] + [maxBitRate] to
  /// transcode; omit both for the original file.
  Uri getStreamUrl(BaseItemDto item, {String? format, int? maxBitRate}) {
    return _buildAuthUri('/rest/stream.view', {
      'id': item.id.raw,
      if (format != null) 'format': format,
      if (maxBitRate != null) 'maxBitRate': maxBitRate.toString(),
    });
  }

  /// Download URL — same as stream but with Content-Disposition: attachment.
  Uri getDownloadUrl(BaseItemDto item) {
    return _buildAuthUri('/rest/download.view', {'id': item.id.raw});
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Unwraps the body returned by a Chopper API call through [SubsonicEnvelope],
  /// throwing [SubsonicException] on Subsonic-level errors.
  /// HTTP-level errors are already thrown by Chopper's bodyOrThrow before we get here.
  Map<String, dynamic> _unwrap(dynamic body) {
    return SubsonicEnvelope.unwrap(body as Map<String, dynamic>);
  }

  /// Builds a fully-authenticated Subsonic URI with auth params appended.
  Uri _buildAuthUri(String path, Map<String, String> extraParams) {
    final serverUrl = _userHelper.serverUrl;
    if (serverUrl == null) throw StateError('Subsonic: no server URL configured');
    final creds = _userHelper.credentials;
    if (creds == null) throw StateError('Subsonic: no credentials configured');

    final salt = SubsonicAuth.generateSalt();
    final token = SubsonicAuth.generateToken(creds.password, salt);
    final base = Uri.parse(serverUrl);
    return base.replace(
      pathSegments: base.pathSegments.followedBy(Uri.parse(path).pathSegments),
      queryParameters: {
        ...extraParams,
        'u': creds.username,
        't': token,
        's': salt,
        'v': _apiVersion,
        'c': _clientName,
        'f': 'json',
      },
    );
  }

  // ── DTO mappers ───────────────────────────────────────────────────────────

  static BaseItemDto _childToDto(SubsonicChild child) {
    final runTimeTicks =
        child.duration != null ? child.duration! * _secondsToTicks : null;
    return BaseItemDto(
      id: BaseItemId(child.id),
      name: child.title,
      sortName: child.sortName,
      type: 'Audio',
      album: child.album,
      albumId: child.albumId != null ? BaseItemId(child.albumId!) : null,
      albumArtist: child.displayAlbumArtist ?? child.artist,
      albumArtists: child.albumArtists
          ?.map((a) => NameIdPair(name: a.name, id: BaseItemId(a.id)))
          .toList(),
      artists: child.displayArtist != null
          ? [child.displayArtist!]
          : child.artist != null
              ? [child.artist!]
              : null,
      artistItems: child.artists
          ?.map((a) => NameIdPair(name: a.name, id: BaseItemId(a.id)))
          .toList(),
      indexNumber: child.track,
      parentIndexNumber: child.discNumber,
      productionYear: child.year,
      genres: child.genres?.map((g) => g.name).toList() ??
          (child.genre != null ? [child.genre!] : null),
      runTimeTicks: runTimeTicks,
      imageTags: child.coverArt != null ? {'Primary': child.coverArt!} : null,
      normalizationGain:
          child.replayGain?.baseGain ?? child.replayGain?.trackGain,
      communityRating: child.averageRating,
      userData: UserItemDataDto(
        isFavorite: child.starred != null,
        played: child.played != null,
        playCount: child.playCount ?? 0,
        playbackPositionTicks: 0,
      ),
      container: child.suffix,
      mediaSources: [
        MediaSourceInfo(
          id: BaseItemId(child.id),
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
          container: child.suffix,
          name: child.title,
          size: child.size,
          bitrate: child.bitRate != null ? child.bitRate! * 1000 : null,
          runTimeTicks: runTimeTicks,
          mediaStreams: [
            MediaStream(
              index: 0,
              type: 'Audio',
              codec: child.suffix,
              bitRate: child.bitRate != null ? child.bitRate! * 1000 : null,
              sampleRate: child.samplingRate,
              channels: child.channelCount,
              bitDepth: child.bitDepth,
              isInterlaced: false,
              isDefault: true,
              isForced: false,
              isExternal: false,
              isTextSubtitleStream: false,
              supportsExternalStream: false,
            ),
          ],
        ),
      ],
    );
  }

  static BaseItemDto _artistToDto(SubsonicArtistID3 artist) => BaseItemDto(
        id: BaseItemId(artist.id),
        name: artist.name,
        sortName: artist.sortName,
        type: 'MusicArtist',
        albumCount: artist.albumCount,
        imageTags: artist.coverArt != null ? {'Primary': artist.coverArt!} : null,
        userData: UserItemDataDto(
          isFavorite: artist.starred != null,
          played: false,
          playCount: 0,
          playbackPositionTicks: 0,
        ),
      );

  static BaseItemDto _albumToDto(SubsonicAlbumID3 album) => BaseItemDto(
        id: BaseItemId(album.id),
        name: album.name,
        sortName: album.sortName,
        type: 'MusicAlbum',
        albumArtist: album.displayArtist ?? album.artist,
        albumArtists: album.artistId != null
            ? [NameIdPair(name: album.artist, id: BaseItemId(album.artistId!))]
            : album.artists
                ?.map((a) => NameIdPair(name: a.name, id: BaseItemId(a.id)))
                .toList(),
        productionYear: album.year,
        genres: album.genres?.map((g) => g.name).toList() ??
            (album.genre != null ? [album.genre!] : null),
        runTimeTicks: album.duration * _secondsToTicks,
        songCount: album.songCount,
        imageTags: album.coverArt != null ? {'Primary': album.coverArt!} : null,
        userData: UserItemDataDto(
          isFavorite: album.starred != null,
          played: album.played != null,
          playCount: album.playCount ?? 0,
          playbackPositionTicks: 0,
        ),
      );

  static BaseItemDto _playlistToDto(SubsonicPlaylist playlist) => BaseItemDto(
        id: BaseItemId(playlist.id),
        name: playlist.name,
        type: 'Playlist',
        overview: playlist.comment,
        runTimeTicks: playlist.duration * _secondsToTicks,
        songCount: playlist.songCount,
        imageTags: playlist.coverArt != null ? {'Primary': playlist.coverArt!} : null,
        userData: UserItemDataDto(
          isFavorite: false,
          played: false,
          playCount: 0,
          playbackPositionTicks: 0,
        ),
      );

  static BaseItemDto _genreToDto(SubsonicGenre genre) => BaseItemDto(
        id: BaseItemId(genre.value),
        name: genre.value,
        type: 'Genre',
        songCount: genre.songCount,
        albumCount: genre.albumCount,
        userData: UserItemDataDto(
          isFavorite: false,
          played: false,
          playCount: 0,
          playbackPositionTicks: 0,
        ),
      );
}
