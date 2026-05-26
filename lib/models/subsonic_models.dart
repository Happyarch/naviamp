/// Models for the OpenSubsonic API as implemented by Navidrome.
/// These are transient API response types — they are parsed and converted to
/// internal types (BaseItemDto etc.) by SubsonicApiHelper before reaching the UI.
///
/// Spec: https://opensubsonic.netlify.app/docs/
/// Navidrome compatibility: https://www.navidrome.org/docs/developers/subsonic-api/
library;

import 'package:json_annotation/json_annotation.dart';

part 'subsonic_models.g.dart';

// ─── Envelope / error handling ────────────────────────────────────────────────

/// Unwraps the 'subsonic-response' envelope and throws [SubsonicException]
/// on failure. Returns the inner map ready for payload parsing.
///
/// Usage: `final inner = SubsonicEnvelope.unwrap(responseJson);`
class SubsonicEnvelope {
  static Map<String, dynamic> unwrap(Map<String, dynamic> json) {
    final inner = json['subsonic-response'] as Map<String, dynamic>;
    if (inner['status'] == 'failed') {
      final err = inner['error'] as Map<String, dynamic>?;
      throw SubsonicException(
        code: (err?['code'] as num?)?.toInt() ?? 0,
        message: err?['message'] as String? ?? 'Unknown error',
      );
    }
    return inner;
  }
}

class SubsonicException implements Exception {
  final int code;
  final String message;

  SubsonicException({required this.code, required this.message});

  // Standard Subsonic error codes
  bool get isRequiredParamMissing => code == 10;
  bool get isAuthError => code == 40 || code == 41;
  bool get isNotFound => code == 70;
  bool get isNotAuthorized => code == 50;

  @override
  String toString() => 'SubsonicException($code): $message';
}

// ─── Music folders ────────────────────────────────────────────────────────────

@JsonSerializable()
class SubsonicMusicFolder {
  final int id;
  final String? name;

  SubsonicMusicFolder({required this.id, this.name});

  factory SubsonicMusicFolder.fromJson(Map<String, dynamic> json) =>
      _$SubsonicMusicFolderFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicMusicFolderToJson(this);
}

@JsonSerializable(explicitToJson: true)
class SubsonicMusicFolders {
  final List<SubsonicMusicFolder>? musicFolder;

  SubsonicMusicFolders({this.musicFolder});

  factory SubsonicMusicFolders.fromJson(Map<String, dynamic> json) =>
      _$SubsonicMusicFoldersFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicMusicFoldersToJson(this);
}

// ─── Genres ───────────────────────────────────────────────────────────────────

@JsonSerializable()
class SubsonicGenre {
  final int songCount;
  final int albumCount;
  final String value; // the genre name — stored as element text in XML, 'value' in JSON

  SubsonicGenre({
    required this.songCount,
    required this.albumCount,
    required this.value,
  });

  factory SubsonicGenre.fromJson(Map<String, dynamic> json) =>
      _$SubsonicGenreFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicGenreToJson(this);
}

@JsonSerializable(explicitToJson: true)
class SubsonicGenres {
  final List<SubsonicGenre>? genre;

  SubsonicGenres({this.genre});

  factory SubsonicGenres.fromJson(Map<String, dynamic> json) =>
      _$SubsonicGenresFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicGenresToJson(this);
}

/// OpenSubsonic: a genre tag on an album or song.
@JsonSerializable()
class SubsonicItemGenre {
  final String name;

  SubsonicItemGenre({required this.name});

  factory SubsonicItemGenre.fromJson(Map<String, dynamic> json) =>
      _$SubsonicItemGenreFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicItemGenreToJson(this);
}

// ─── ReplayGain (OpenSubsonic) ────────────────────────────────────────────────

@JsonSerializable()
class SubsonicReplayGain {
  final double? trackGain; // dB
  final double? albumGain; // dB
  final double? trackPeak; // linear
  final double? albumPeak; // linear
  final double? baseGain; // dB, OpenSubsonic
  final double? fallbackGain; // dB, OpenSubsonic

  SubsonicReplayGain({
    this.trackGain,
    this.albumGain,
    this.trackPeak,
    this.albumPeak,
    this.baseGain,
    this.fallbackGain,
  });

  factory SubsonicReplayGain.fromJson(Map<String, dynamic> json) =>
      _$SubsonicReplayGainFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicReplayGainToJson(this);
}

// ─── Contributor types (OpenSubsonic) ────────────────────────────────────────

/// A minimal artist reference used on albums and songs (OpenSubsonic multi-artist).
@JsonSerializable()
class SubsonicArtistRef {
  final String id;
  final String name;
  final String? artistImageUrl;

  SubsonicArtistRef({required this.id, required this.name, this.artistImageUrl});

  factory SubsonicArtistRef.fromJson(Map<String, dynamic> json) =>
      _$SubsonicArtistRefFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicArtistRefToJson(this);
}

@JsonSerializable(explicitToJson: true)
class SubsonicContributor {
  final String role;
  final String? subRole;
  final SubsonicArtistRef artist;

  SubsonicContributor({required this.role, this.subRole, required this.artist});

  factory SubsonicContributor.fromJson(Map<String, dynamic> json) =>
      _$SubsonicContributorFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicContributorToJson(this);
}

@JsonSerializable()
class SubsonicRecordLabel {
  final String name;

  SubsonicRecordLabel({required this.name});

  factory SubsonicRecordLabel.fromJson(Map<String, dynamic> json) =>
      _$SubsonicRecordLabelFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicRecordLabelToJson(this);
}

@JsonSerializable()
class SubsonicDiscTitle {
  final int disc;
  final String title;

  SubsonicDiscTitle({required this.disc, required this.title});

  factory SubsonicDiscTitle.fromJson(Map<String, dynamic> json) =>
      _$SubsonicDiscTitleFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicDiscTitleToJson(this);
}

// ─── Artist ───────────────────────────────────────────────────────────────────

@JsonSerializable(explicitToJson: true)
class SubsonicArtistID3 {
  final String id;
  final String name;
  final String? coverArt;
  final String? artistImageUrl;
  final int? albumCount;
  final String? starred; // ISO-8601 datetime when starred; absent if not starred
  final String? musicBrainzId;
  final String? sortName; // OpenSubsonic
  final List<SubsonicItemGenre>? genres; // OpenSubsonic
  final List<String>? roles; // OpenSubsonic

  SubsonicArtistID3({
    required this.id,
    required this.name,
    this.coverArt,
    this.artistImageUrl,
    this.albumCount,
    this.starred,
    this.musicBrainzId,
    this.sortName,
    this.genres,
    this.roles,
  });

  bool get isStarred => starred != null;

  factory SubsonicArtistID3.fromJson(Map<String, dynamic> json) =>
      _$SubsonicArtistID3FromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicArtistID3ToJson(this);
}

@JsonSerializable()
class SubsonicIndexID3 {
  final String name; // 'A', 'B', '#', etc.
  final List<SubsonicArtistID3>? artist;

  SubsonicIndexID3({required this.name, this.artist});

  factory SubsonicIndexID3.fromJson(Map<String, dynamic> json) =>
      _$SubsonicIndexID3FromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicIndexID3ToJson(this);
}

@JsonSerializable(explicitToJson: true)
class SubsonicArtistsID3 {
  final String? ignoredArticles; // e.g. "The El La Los Las Le Les"
  final List<SubsonicIndexID3>? index;

  SubsonicArtistsID3({this.ignoredArticles, this.index});

  factory SubsonicArtistsID3.fromJson(Map<String, dynamic> json) =>
      _$SubsonicArtistsID3FromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicArtistsID3ToJson(this);
}

@JsonSerializable(explicitToJson: true)
class SubsonicArtistWithAlbumsID3 extends SubsonicArtistID3 {
  final List<SubsonicAlbumID3>? album;

  SubsonicArtistWithAlbumsID3({
    required super.id,
    required super.name,
    super.coverArt,
    super.artistImageUrl,
    super.albumCount,
    super.starred,
    super.musicBrainzId,
    super.sortName,
    super.genres,
    super.roles,
    this.album,
  });

  factory SubsonicArtistWithAlbumsID3.fromJson(Map<String, dynamic> json) =>
      _$SubsonicArtistWithAlbumsID3FromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicArtistWithAlbumsID3ToJson(this);
}

// ─── Album ────────────────────────────────────────────────────────────────────

@JsonSerializable(explicitToJson: true)
class SubsonicAlbumID3 {
  final String id;
  final String name;
  final String? artist;
  final String? artistId;
  final String? coverArt;
  final int songCount;
  final int duration; // seconds
  final int? playCount;
  final String? created; // ISO-8601
  final String? starred; // ISO-8601; absent if not starred
  final int? year;
  final String? genre;
  final List<SubsonicItemGenre>? genres; // OpenSubsonic
  final String? musicBrainzId;
  final String? sortName; // OpenSubsonic
  final bool? isCompilation; // OpenSubsonic
  final List<SubsonicArtistRef>? artists; // OpenSubsonic multi-artist
  final String? displayArtist; // OpenSubsonic
  final List<SubsonicRecordLabel>? recordLabels; // OpenSubsonic
  final List<SubsonicDiscTitle>? discTitles; // OpenSubsonic
  final List<String>? moods; // OpenSubsonic
  // Navidrome sends these as ItemDate objects ({}), not strings.
  // We don't use them in BaseItemDto mapping, so skip deserialization.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? originalReleaseDate; // OpenSubsonic
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? releaseDate; // OpenSubsonic
  // releaseTypes is a string[] in OpenSubsonic, not a single string.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? releaseTypes; // OpenSubsonic
  final int? bpm; // OpenSubsonic
  final String? comment; // OpenSubsonic
  final String? played; // OpenSubsonic: last played datetime
  final int? userRating; // OpenSubsonic: 1-5

  SubsonicAlbumID3({
    required this.id,
    required this.name,
    this.artist,
    this.artistId,
    this.coverArt,
    required this.songCount,
    required this.duration,
    this.playCount,
    this.created,
    this.starred,
    this.year,
    this.genre,
    this.genres,
    this.musicBrainzId,
    this.sortName,
    this.isCompilation,
    this.artists,
    this.displayArtist,
    this.recordLabels,
    this.discTitles,
    this.moods,
    this.originalReleaseDate,
    this.releaseDate,
    this.releaseTypes,
    this.bpm,
    this.comment,
    this.played,
    this.userRating,
  });

  bool get isStarred => starred != null;

  factory SubsonicAlbumID3.fromJson(Map<String, dynamic> json) =>
      _$SubsonicAlbumID3FromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicAlbumID3ToJson(this);
}

@JsonSerializable(explicitToJson: true)
class SubsonicAlbumWithSongsID3 extends SubsonicAlbumID3 {
  final List<SubsonicChild>? song;

  SubsonicAlbumWithSongsID3({
    required super.id,
    required super.name,
    super.artist,
    super.artistId,
    super.coverArt,
    required super.songCount,
    required super.duration,
    super.playCount,
    super.created,
    super.starred,
    super.year,
    super.genre,
    super.genres,
    super.musicBrainzId,
    super.sortName,
    super.isCompilation,
    super.artists,
    super.displayArtist,
    super.recordLabels,
    super.discTitles,
    super.moods,
    super.originalReleaseDate,
    super.releaseDate,
    super.releaseTypes,
    super.bpm,
    super.comment,
    super.played,
    super.userRating,
    this.song,
  });

  factory SubsonicAlbumWithSongsID3.fromJson(Map<String, dynamic> json) =>
      _$SubsonicAlbumWithSongsID3FromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicAlbumWithSongsID3ToJson(this);
}

@JsonSerializable(explicitToJson: true)
class SubsonicAlbumList2 {
  final List<SubsonicAlbumID3>? album;

  SubsonicAlbumList2({this.album});

  factory SubsonicAlbumList2.fromJson(Map<String, dynamic> json) =>
      _$SubsonicAlbumList2FromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicAlbumList2ToJson(this);
}

// ─── Song (Child) ─────────────────────────────────────────────────────────────

/// A song entry. Called 'Child' in the Subsonic spec.
@JsonSerializable(explicitToJson: true)
class SubsonicChild {
  final String id;
  final String? parent;
  final bool isDir;
  final String title;
  final String? album;
  final String? artist;
  final int? track;
  final int? year;
  final String? genre;
  final String? coverArt;
  final int? size; // bytes
  final String? contentType;
  final String? suffix;
  final int? duration; // seconds
  final int? bitRate; // kbps
  final int? bitDepth; // OpenSubsonic
  final int? samplingRate; // Hz, OpenSubsonic
  final int? channelCount; // OpenSubsonic
  final String? path;
  final int? playCount;
  final int? discNumber;
  final String? created; // ISO-8601
  final String? starred; // ISO-8601; absent if not starred
  final String? albumId;
  final String? artistId;
  final String? type; // 'music' | 'podcast' | 'audiobook' | 'video'
  final bool? isVideo;
  final int? userRating; // 1-5
  final double? averageRating;
  final String? played; // OpenSubsonic: last played datetime
  final SubsonicReplayGain? replayGain; // OpenSubsonic
  final String? musicBrainzId;
  final String? sortName; // OpenSubsonic
  final List<SubsonicItemGenre>? genres; // OpenSubsonic
  final List<SubsonicArtistRef>? artists; // OpenSubsonic multi-artist
  final String? displayArtist; // OpenSubsonic
  final List<SubsonicArtistRef>? albumArtists; // OpenSubsonic
  final String? displayAlbumArtist; // OpenSubsonic
  final List<SubsonicContributor>? contributors; // OpenSubsonic
  final String? displayComposer; // OpenSubsonic
  final List<String>? moods; // OpenSubsonic
  final int? bpm; // OpenSubsonic
  final String? comment; // OpenSubsonic
  final String? mediaType; // OpenSubsonic: 'song' | 'podcast' | 'audiobook' | 'video'

  SubsonicChild({
    required this.id,
    this.parent,
    required this.isDir,
    required this.title,
    this.album,
    this.artist,
    this.track,
    this.year,
    this.genre,
    this.coverArt,
    this.size,
    this.contentType,
    this.suffix,
    this.duration,
    this.bitRate,
    this.bitDepth,
    this.samplingRate,
    this.channelCount,
    this.path,
    this.playCount,
    this.discNumber,
    this.created,
    this.starred,
    this.albumId,
    this.artistId,
    this.type,
    this.isVideo,
    this.userRating,
    this.averageRating,
    this.played,
    this.replayGain,
    this.musicBrainzId,
    this.sortName,
    this.genres,
    this.artists,
    this.displayArtist,
    this.albumArtists,
    this.displayAlbumArtist,
    this.contributors,
    this.displayComposer,
    this.moods,
    this.bpm,
    this.comment,
    this.mediaType,
  });

  bool get isStarred => starred != null;

  factory SubsonicChild.fromJson(Map<String, dynamic> json) =>
      _$SubsonicChildFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicChildToJson(this);
}

/// Song list returned by: getRandomSongs, getSimilarSongs2, getTopSongs, getInstantMix.
/// Note: getSongsByGenre uses [SubsonicSongsByGenre] because it uses 'child' as the key.
@JsonSerializable(explicitToJson: true)
class SubsonicSongList {
  final List<SubsonicChild>? song;

  SubsonicSongList({this.song});

  factory SubsonicSongList.fromJson(Map<String, dynamic> json) =>
      _$SubsonicSongListFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicSongListToJson(this);
}

/// getSongsByGenre uses 'child' instead of 'song' as the array key.
@JsonSerializable(explicitToJson: true)
class SubsonicSongsByGenre {
  final List<SubsonicChild>? child;

  SubsonicSongsByGenre({this.child});

  factory SubsonicSongsByGenre.fromJson(Map<String, dynamic> json) =>
      _$SubsonicSongsByGenreFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicSongsByGenreToJson(this);
}

// ─── Search ───────────────────────────────────────────────────────────────────

@JsonSerializable(explicitToJson: true)
class SubsonicSearchResult3 {
  final List<SubsonicArtistID3>? artist;
  final List<SubsonicAlbumID3>? album;
  final List<SubsonicChild>? song;

  SubsonicSearchResult3({this.artist, this.album, this.song});

  factory SubsonicSearchResult3.fromJson(Map<String, dynamic> json) =>
      _$SubsonicSearchResult3FromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicSearchResult3ToJson(this);
}

// ─── Starred ──────────────────────────────────────────────────────────────────

@JsonSerializable(explicitToJson: true)
class SubsonicStarred2 {
  final List<SubsonicArtistID3>? artist;
  final List<SubsonicAlbumID3>? album;
  final List<SubsonicChild>? song;

  SubsonicStarred2({this.artist, this.album, this.song});

  factory SubsonicStarred2.fromJson(Map<String, dynamic> json) =>
      _$SubsonicStarred2FromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicStarred2ToJson(this);
}

// ─── Playlists ────────────────────────────────────────────────────────────────

@JsonSerializable()
class SubsonicPlaylist {
  final String id;
  final String name;
  final String? comment;
  final String? owner;
  final bool? public;
  final int songCount;
  final int duration; // seconds
  final String? created; // ISO-8601
  final String? changed; // ISO-8601
  final String? coverArt;
  final List<String>? allowedUser;

  SubsonicPlaylist({
    required this.id,
    required this.name,
    this.comment,
    this.owner,
    this.public,
    required this.songCount,
    required this.duration,
    this.created,
    this.changed,
    this.coverArt,
    this.allowedUser,
  });

  factory SubsonicPlaylist.fromJson(Map<String, dynamic> json) =>
      _$SubsonicPlaylistFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicPlaylistToJson(this);
}

@JsonSerializable(explicitToJson: true)
class SubsonicPlaylistWithSongs extends SubsonicPlaylist {
  // Subsonic uses 'entry' for the song list inside a playlist
  final List<SubsonicChild>? entry;

  SubsonicPlaylistWithSongs({
    required super.id,
    required super.name,
    super.comment,
    super.owner,
    super.public,
    required super.songCount,
    required super.duration,
    super.created,
    super.changed,
    super.coverArt,
    super.allowedUser,
    this.entry,
  });

  factory SubsonicPlaylistWithSongs.fromJson(Map<String, dynamic> json) =>
      _$SubsonicPlaylistWithSongsFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$SubsonicPlaylistWithSongsToJson(this);
}

@JsonSerializable(explicitToJson: true)
class SubsonicPlaylists {
  final List<SubsonicPlaylist>? playlist;

  SubsonicPlaylists({this.playlist});

  factory SubsonicPlaylists.fromJson(Map<String, dynamic> json) =>
      _$SubsonicPlaylistsFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicPlaylistsToJson(this);
}

// ─── Lyrics ───────────────────────────────────────────────────────────────────

/// OpenSubsonic structured lyrics (synced or unsynced, multi-language).
@JsonSerializable(explicitToJson: true)
class SubsonicLyricLine {
  final int? start; // milliseconds offset; null for unsynced lyrics
  final String value;

  SubsonicLyricLine({this.start, required this.value});

  factory SubsonicLyricLine.fromJson(Map<String, dynamic> json) =>
      _$SubsonicLyricLineFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicLyricLineToJson(this);
}

@JsonSerializable(explicitToJson: true)
class SubsonicStructuredLyrics {
  final String lang; // BCP 47 language code or 'xxx' for unknown
  final bool synced;
  final String? displayArtist;
  final String? displayTitle;
  final double? offset; // ms adjustment to apply to all line timestamps
  final List<SubsonicLyricLine> line;

  SubsonicStructuredLyrics({
    required this.lang,
    required this.synced,
    this.displayArtist,
    this.displayTitle,
    this.offset,
    required this.line,
  });

  factory SubsonicStructuredLyrics.fromJson(Map<String, dynamic> json) =>
      _$SubsonicStructuredLyricsFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicStructuredLyricsToJson(this);
}

@JsonSerializable(explicitToJson: true)
class SubsonicLyricsList {
  final List<SubsonicStructuredLyrics>? structuredLyrics;

  SubsonicLyricsList({this.structuredLyrics});

  factory SubsonicLyricsList.fromJson(Map<String, dynamic> json) =>
      _$SubsonicLyricsListFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicLyricsListToJson(this);
}

// ─── User ─────────────────────────────────────────────────────────────────────

@JsonSerializable()
class SubsonicUser {
  final String username;
  final String? email;
  final bool scrobblingEnabled;
  final int? maxBitRate;
  final bool adminRole;
  final bool downloadRole;
  final bool uploadRole;
  final bool playlistRole;
  final bool coverArtRole;
  final bool commentRole;
  final bool podcastRole;
  final bool streamRole;
  final bool jukeboxRole;
  final bool shareRole;
  final List<int>? folder; // music folder IDs this user can access

  SubsonicUser({
    required this.username,
    this.email,
    required this.scrobblingEnabled,
    this.maxBitRate,
    required this.adminRole,
    required this.downloadRole,
    required this.uploadRole,
    required this.playlistRole,
    required this.coverArtRole,
    required this.commentRole,
    required this.podcastRole,
    required this.streamRole,
    required this.jukeboxRole,
    required this.shareRole,
    this.folder,
  });

  factory SubsonicUser.fromJson(Map<String, dynamic> json) =>
      _$SubsonicUserFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicUserToJson(this);
}

// ─── Scan status ──────────────────────────────────────────────────────────────

@JsonSerializable()
class SubsonicScanStatus {
  final bool scanning;
  final int? count; // tracks scanned so far
  // Navidrome extensions:
  final String? lastScan; // ISO-8601 datetime of last completed scan
  final int? folderCount; // number of folders scanned

  SubsonicScanStatus({
    required this.scanning,
    this.count,
    this.lastScan,
    this.folderCount,
  });

  factory SubsonicScanStatus.fromJson(Map<String, dynamic> json) =>
      _$SubsonicScanStatusFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicScanStatusToJson(this);
}

// ─── Server info ──────────────────────────────────────────────────────────────

/// The version/capability information available in every Subsonic response envelope.
class SubsonicServerInfo {
  final String apiVersion; // e.g. '1.16.1'
  final String? type; // OpenSubsonic: 'navidrome'
  final String? serverVersion; // e.g. '0.53.3'
  final bool openSubsonic; // true if server supports OpenSubsonic extensions

  SubsonicServerInfo({
    required this.apiVersion,
    this.type,
    this.serverVersion,
    required this.openSubsonic,
  });

  factory SubsonicServerInfo.fromInner(Map<String, dynamic> inner) {
    return SubsonicServerInfo(
      apiVersion: inner['version'] as String? ?? '1.16.1',
      type: inner['type'] as String?,
      serverVersion: inner['serverVersion'] as String?,
      openSubsonic: inner['openSubsonic'] as bool? ?? false,
    );
  }
}
