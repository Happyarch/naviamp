// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off


part of 'subsonic_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubsonicMusicFolder _$SubsonicMusicFolderFromJson(Map<String, dynamic> json) =>
    SubsonicMusicFolder(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String?,
    );

Map<String, dynamic> _$SubsonicMusicFolderToJson(
  SubsonicMusicFolder instance,
) => <String, dynamic>{'id': instance.id, 'name': instance.name};

SubsonicMusicFolders _$SubsonicMusicFoldersFromJson(
  Map<String, dynamic> json,
) => SubsonicMusicFolders(
  musicFolder: (json['musicFolder'] as List<dynamic>?)
      ?.map((e) => SubsonicMusicFolder.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SubsonicMusicFoldersToJson(
  SubsonicMusicFolders instance,
) => <String, dynamic>{
  'musicFolder': instance.musicFolder?.map((e) => e.toJson()).toList(),
};

SubsonicGenre _$SubsonicGenreFromJson(Map<String, dynamic> json) =>
    SubsonicGenre(
      songCount: (json['songCount'] as num).toInt(),
      albumCount: (json['albumCount'] as num).toInt(),
      value: json['value'] as String,
    );

Map<String, dynamic> _$SubsonicGenreToJson(SubsonicGenre instance) =>
    <String, dynamic>{
      'songCount': instance.songCount,
      'albumCount': instance.albumCount,
      'value': instance.value,
    };

SubsonicGenres _$SubsonicGenresFromJson(Map<String, dynamic> json) =>
    SubsonicGenres(
      genre: (json['genre'] as List<dynamic>?)
          ?.map((e) => SubsonicGenre.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SubsonicGenresToJson(SubsonicGenres instance) =>
    <String, dynamic>{'genre': instance.genre?.map((e) => e.toJson()).toList()};

SubsonicItemGenre _$SubsonicItemGenreFromJson(Map<String, dynamic> json) =>
    SubsonicItemGenre(name: json['name'] as String);

Map<String, dynamic> _$SubsonicItemGenreToJson(SubsonicItemGenre instance) =>
    <String, dynamic>{'name': instance.name};

SubsonicReplayGain _$SubsonicReplayGainFromJson(Map<String, dynamic> json) =>
    SubsonicReplayGain(
      trackGain: (json['trackGain'] as num?)?.toDouble(),
      albumGain: (json['albumGain'] as num?)?.toDouble(),
      trackPeak: (json['trackPeak'] as num?)?.toDouble(),
      albumPeak: (json['albumPeak'] as num?)?.toDouble(),
      baseGain: (json['baseGain'] as num?)?.toDouble(),
      fallbackGain: (json['fallbackGain'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$SubsonicReplayGainToJson(SubsonicReplayGain instance) =>
    <String, dynamic>{
      'trackGain': instance.trackGain,
      'albumGain': instance.albumGain,
      'trackPeak': instance.trackPeak,
      'albumPeak': instance.albumPeak,
      'baseGain': instance.baseGain,
      'fallbackGain': instance.fallbackGain,
    };

SubsonicArtistRef _$SubsonicArtistRefFromJson(Map<String, dynamic> json) =>
    SubsonicArtistRef(
      id: json['id'] as String,
      name: json['name'] as String,
      artistImageUrl: json['artistImageUrl'] as String?,
    );

Map<String, dynamic> _$SubsonicArtistRefToJson(SubsonicArtistRef instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'artistImageUrl': instance.artistImageUrl,
    };

SubsonicContributor _$SubsonicContributorFromJson(Map<String, dynamic> json) =>
    SubsonicContributor(
      role: json['role'] as String,
      subRole: json['subRole'] as String?,
      artist: SubsonicArtistRef.fromJson(
        json['artist'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$SubsonicContributorToJson(
  SubsonicContributor instance,
) => <String, dynamic>{
  'role': instance.role,
  'subRole': instance.subRole,
  'artist': instance.artist.toJson(),
};

SubsonicRecordLabel _$SubsonicRecordLabelFromJson(Map<String, dynamic> json) =>
    SubsonicRecordLabel(name: json['name'] as String);

Map<String, dynamic> _$SubsonicRecordLabelToJson(
  SubsonicRecordLabel instance,
) => <String, dynamic>{'name': instance.name};

SubsonicDiscTitle _$SubsonicDiscTitleFromJson(Map<String, dynamic> json) =>
    SubsonicDiscTitle(
      disc: (json['disc'] as num).toInt(),
      title: json['title'] as String,
    );

Map<String, dynamic> _$SubsonicDiscTitleToJson(SubsonicDiscTitle instance) =>
    <String, dynamic>{'disc': instance.disc, 'title': instance.title};

SubsonicArtistID3 _$SubsonicArtistID3FromJson(Map<String, dynamic> json) =>
    SubsonicArtistID3(
      id: json['id'] as String,
      name: json['name'] as String,
      coverArt: json['coverArt'] as String?,
      artistImageUrl: json['artistImageUrl'] as String?,
      albumCount: (json['albumCount'] as num?)?.toInt(),
      starred: json['starred'] as String?,
      musicBrainzId: json['musicBrainzId'] as String?,
      sortName: json['sortName'] as String?,
      genres: (json['genres'] as List<dynamic>?)
          ?.map((e) => SubsonicItemGenre.fromJson(e as Map<String, dynamic>))
          .toList(),
      roles: (json['roles'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$SubsonicArtistID3ToJson(SubsonicArtistID3 instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'coverArt': instance.coverArt,
      'artistImageUrl': instance.artistImageUrl,
      'albumCount': instance.albumCount,
      'starred': instance.starred,
      'musicBrainzId': instance.musicBrainzId,
      'sortName': instance.sortName,
      'genres': instance.genres?.map((e) => e.toJson()).toList(),
      'roles': instance.roles,
    };

SubsonicIndexID3 _$SubsonicIndexID3FromJson(Map<String, dynamic> json) =>
    SubsonicIndexID3(
      name: json['name'] as String,
      artist: (json['artist'] as List<dynamic>?)
          ?.map((e) => SubsonicArtistID3.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SubsonicIndexID3ToJson(SubsonicIndexID3 instance) =>
    <String, dynamic>{'name': instance.name, 'artist': instance.artist};

SubsonicArtistsID3 _$SubsonicArtistsID3FromJson(Map<String, dynamic> json) =>
    SubsonicArtistsID3(
      ignoredArticles: json['ignoredArticles'] as String?,
      index: (json['index'] as List<dynamic>?)
          ?.map((e) => SubsonicIndexID3.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SubsonicArtistsID3ToJson(SubsonicArtistsID3 instance) =>
    <String, dynamic>{
      'ignoredArticles': instance.ignoredArticles,
      'index': instance.index?.map((e) => e.toJson()).toList(),
    };

SubsonicArtistWithAlbumsID3 _$SubsonicArtistWithAlbumsID3FromJson(
  Map<String, dynamic> json,
) => SubsonicArtistWithAlbumsID3(
  id: json['id'] as String,
  name: json['name'] as String,
  coverArt: json['coverArt'] as String?,
  artistImageUrl: json['artistImageUrl'] as String?,
  albumCount: (json['albumCount'] as num?)?.toInt(),
  starred: json['starred'] as String?,
  musicBrainzId: json['musicBrainzId'] as String?,
  sortName: json['sortName'] as String?,
  genres: (json['genres'] as List<dynamic>?)
      ?.map((e) => SubsonicItemGenre.fromJson(e as Map<String, dynamic>))
      .toList(),
  roles: (json['roles'] as List<dynamic>?)?.map((e) => e as String).toList(),
  album: (json['album'] as List<dynamic>?)
      ?.map((e) => SubsonicAlbumID3.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SubsonicArtistWithAlbumsID3ToJson(
  SubsonicArtistWithAlbumsID3 instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'coverArt': instance.coverArt,
  'artistImageUrl': instance.artistImageUrl,
  'albumCount': instance.albumCount,
  'starred': instance.starred,
  'musicBrainzId': instance.musicBrainzId,
  'sortName': instance.sortName,
  'genres': instance.genres?.map((e) => e.toJson()).toList(),
  'roles': instance.roles,
  'album': instance.album?.map((e) => e.toJson()).toList(),
};

SubsonicAlbumID3 _$SubsonicAlbumID3FromJson(Map<String, dynamic> json) =>
    SubsonicAlbumID3(
      id: json['id'] as String,
      name: json['name'] as String,
      artist: json['artist'] as String?,
      artistId: json['artistId'] as String?,
      coverArt: json['coverArt'] as String?,
      songCount: (json['songCount'] as num).toInt(),
      duration: (json['duration'] as num).toInt(),
      playCount: (json['playCount'] as num?)?.toInt(),
      created: json['created'] as String?,
      starred: json['starred'] as String?,
      year: (json['year'] as num?)?.toInt(),
      genre: json['genre'] as String?,
      genres: (json['genres'] as List<dynamic>?)
          ?.map((e) => SubsonicItemGenre.fromJson(e as Map<String, dynamic>))
          .toList(),
      musicBrainzId: json['musicBrainzId'] as String?,
      sortName: json['sortName'] as String?,
      isCompilation: json['isCompilation'] as bool?,
      artists: (json['artists'] as List<dynamic>?)
          ?.map((e) => SubsonicArtistRef.fromJson(e as Map<String, dynamic>))
          .toList(),
      displayArtist: json['displayArtist'] as String?,
      recordLabels: (json['recordLabels'] as List<dynamic>?)
          ?.map((e) => SubsonicRecordLabel.fromJson(e as Map<String, dynamic>))
          .toList(),
      discTitles: (json['discTitles'] as List<dynamic>?)
          ?.map((e) => SubsonicDiscTitle.fromJson(e as Map<String, dynamic>))
          .toList(),
      moods: (json['moods'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      originalReleaseDate: json['originalReleaseDate'] as String?,
      releaseDate: json['releaseDate'] as String?,
      releaseTypes: json['releaseTypes'] as String?,
      bpm: (json['bpm'] as num?)?.toInt(),
      comment: json['comment'] as String?,
      played: json['played'] as String?,
      userRating: (json['userRating'] as num?)?.toInt(),
    );

Map<String, dynamic> _$SubsonicAlbumID3ToJson(SubsonicAlbumID3 instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'artist': instance.artist,
      'artistId': instance.artistId,
      'coverArt': instance.coverArt,
      'songCount': instance.songCount,
      'duration': instance.duration,
      'playCount': instance.playCount,
      'created': instance.created,
      'starred': instance.starred,
      'year': instance.year,
      'genre': instance.genre,
      'genres': instance.genres?.map((e) => e.toJson()).toList(),
      'musicBrainzId': instance.musicBrainzId,
      'sortName': instance.sortName,
      'isCompilation': instance.isCompilation,
      'artists': instance.artists?.map((e) => e.toJson()).toList(),
      'displayArtist': instance.displayArtist,
      'recordLabels': instance.recordLabels?.map((e) => e.toJson()).toList(),
      'discTitles': instance.discTitles?.map((e) => e.toJson()).toList(),
      'moods': instance.moods,
      'originalReleaseDate': instance.originalReleaseDate,
      'releaseDate': instance.releaseDate,
      'releaseTypes': instance.releaseTypes,
      'bpm': instance.bpm,
      'comment': instance.comment,
      'played': instance.played,
      'userRating': instance.userRating,
    };

SubsonicAlbumWithSongsID3 _$SubsonicAlbumWithSongsID3FromJson(
  Map<String, dynamic> json,
) => SubsonicAlbumWithSongsID3(
  id: json['id'] as String,
  name: json['name'] as String,
  artist: json['artist'] as String?,
  artistId: json['artistId'] as String?,
  coverArt: json['coverArt'] as String?,
  songCount: (json['songCount'] as num).toInt(),
  duration: (json['duration'] as num).toInt(),
  playCount: (json['playCount'] as num?)?.toInt(),
  created: json['created'] as String?,
  starred: json['starred'] as String?,
  year: (json['year'] as num?)?.toInt(),
  genre: json['genre'] as String?,
  genres: (json['genres'] as List<dynamic>?)
      ?.map((e) => SubsonicItemGenre.fromJson(e as Map<String, dynamic>))
      .toList(),
  musicBrainzId: json['musicBrainzId'] as String?,
  sortName: json['sortName'] as String?,
  isCompilation: json['isCompilation'] as bool?,
  artists: (json['artists'] as List<dynamic>?)
      ?.map((e) => SubsonicArtistRef.fromJson(e as Map<String, dynamic>))
      .toList(),
  displayArtist: json['displayArtist'] as String?,
  recordLabels: (json['recordLabels'] as List<dynamic>?)
      ?.map((e) => SubsonicRecordLabel.fromJson(e as Map<String, dynamic>))
      .toList(),
  discTitles: (json['discTitles'] as List<dynamic>?)
      ?.map((e) => SubsonicDiscTitle.fromJson(e as Map<String, dynamic>))
      .toList(),
  moods: (json['moods'] as List<dynamic>?)?.map((e) => e as String).toList(),
  originalReleaseDate: json['originalReleaseDate'] as String?,
  releaseDate: json['releaseDate'] as String?,
  releaseTypes: json['releaseTypes'] as String?,
  bpm: (json['bpm'] as num?)?.toInt(),
  comment: json['comment'] as String?,
  played: json['played'] as String?,
  userRating: (json['userRating'] as num?)?.toInt(),
  song: (json['song'] as List<dynamic>?)
      ?.map((e) => SubsonicChild.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SubsonicAlbumWithSongsID3ToJson(
  SubsonicAlbumWithSongsID3 instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'artist': instance.artist,
  'artistId': instance.artistId,
  'coverArt': instance.coverArt,
  'songCount': instance.songCount,
  'duration': instance.duration,
  'playCount': instance.playCount,
  'created': instance.created,
  'starred': instance.starred,
  'year': instance.year,
  'genre': instance.genre,
  'genres': instance.genres?.map((e) => e.toJson()).toList(),
  'musicBrainzId': instance.musicBrainzId,
  'sortName': instance.sortName,
  'isCompilation': instance.isCompilation,
  'artists': instance.artists?.map((e) => e.toJson()).toList(),
  'displayArtist': instance.displayArtist,
  'recordLabels': instance.recordLabels?.map((e) => e.toJson()).toList(),
  'discTitles': instance.discTitles?.map((e) => e.toJson()).toList(),
  'moods': instance.moods,
  'originalReleaseDate': instance.originalReleaseDate,
  'releaseDate': instance.releaseDate,
  'releaseTypes': instance.releaseTypes,
  'bpm': instance.bpm,
  'comment': instance.comment,
  'played': instance.played,
  'userRating': instance.userRating,
  'song': instance.song?.map((e) => e.toJson()).toList(),
};

SubsonicAlbumList2 _$SubsonicAlbumList2FromJson(Map<String, dynamic> json) =>
    SubsonicAlbumList2(
      album: (json['album'] as List<dynamic>?)
          ?.map((e) => SubsonicAlbumID3.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SubsonicAlbumList2ToJson(SubsonicAlbumList2 instance) =>
    <String, dynamic>{'album': instance.album?.map((e) => e.toJson()).toList()};

SubsonicChild _$SubsonicChildFromJson(
  Map<String, dynamic> json,
) => SubsonicChild(
  id: json['id'] as String,
  parent: json['parent'] as String?,
  isDir: json['isDir'] as bool,
  title: json['title'] as String,
  album: json['album'] as String?,
  artist: json['artist'] as String?,
  track: (json['track'] as num?)?.toInt(),
  year: (json['year'] as num?)?.toInt(),
  genre: json['genre'] as String?,
  coverArt: json['coverArt'] as String?,
  size: (json['size'] as num?)?.toInt(),
  contentType: json['contentType'] as String?,
  suffix: json['suffix'] as String?,
  duration: (json['duration'] as num?)?.toInt(),
  bitRate: (json['bitRate'] as num?)?.toInt(),
  bitDepth: (json['bitDepth'] as num?)?.toInt(),
  samplingRate: (json['samplingRate'] as num?)?.toInt(),
  channelCount: (json['channelCount'] as num?)?.toInt(),
  path: json['path'] as String?,
  playCount: (json['playCount'] as num?)?.toInt(),
  discNumber: (json['discNumber'] as num?)?.toInt(),
  created: json['created'] as String?,
  starred: json['starred'] as String?,
  albumId: json['albumId'] as String?,
  artistId: json['artistId'] as String?,
  type: json['type'] as String?,
  isVideo: json['isVideo'] as bool?,
  userRating: (json['userRating'] as num?)?.toInt(),
  averageRating: (json['averageRating'] as num?)?.toDouble(),
  played: json['played'] as String?,
  replayGain: json['replayGain'] == null
      ? null
      : SubsonicReplayGain.fromJson(json['replayGain'] as Map<String, dynamic>),
  musicBrainzId: json['musicBrainzId'] as String?,
  sortName: json['sortName'] as String?,
  genres: (json['genres'] as List<dynamic>?)
      ?.map((e) => SubsonicItemGenre.fromJson(e as Map<String, dynamic>))
      .toList(),
  artists: (json['artists'] as List<dynamic>?)
      ?.map((e) => SubsonicArtistRef.fromJson(e as Map<String, dynamic>))
      .toList(),
  displayArtist: json['displayArtist'] as String?,
  albumArtists: (json['albumArtists'] as List<dynamic>?)
      ?.map((e) => SubsonicArtistRef.fromJson(e as Map<String, dynamic>))
      .toList(),
  displayAlbumArtist: json['displayAlbumArtist'] as String?,
  contributors: (json['contributors'] as List<dynamic>?)
      ?.map((e) => SubsonicContributor.fromJson(e as Map<String, dynamic>))
      .toList(),
  displayComposer: json['displayComposer'] as String?,
  moods: (json['moods'] as List<dynamic>?)?.map((e) => e as String).toList(),
  bpm: (json['bpm'] as num?)?.toInt(),
  comment: json['comment'] as String?,
  mediaType: json['mediaType'] as String?,
);

Map<String, dynamic> _$SubsonicChildToJson(SubsonicChild instance) =>
    <String, dynamic>{
      'id': instance.id,
      'parent': instance.parent,
      'isDir': instance.isDir,
      'title': instance.title,
      'album': instance.album,
      'artist': instance.artist,
      'track': instance.track,
      'year': instance.year,
      'genre': instance.genre,
      'coverArt': instance.coverArt,
      'size': instance.size,
      'contentType': instance.contentType,
      'suffix': instance.suffix,
      'duration': instance.duration,
      'bitRate': instance.bitRate,
      'bitDepth': instance.bitDepth,
      'samplingRate': instance.samplingRate,
      'channelCount': instance.channelCount,
      'path': instance.path,
      'playCount': instance.playCount,
      'discNumber': instance.discNumber,
      'created': instance.created,
      'starred': instance.starred,
      'albumId': instance.albumId,
      'artistId': instance.artistId,
      'type': instance.type,
      'isVideo': instance.isVideo,
      'userRating': instance.userRating,
      'averageRating': instance.averageRating,
      'played': instance.played,
      'replayGain': instance.replayGain?.toJson(),
      'musicBrainzId': instance.musicBrainzId,
      'sortName': instance.sortName,
      'genres': instance.genres?.map((e) => e.toJson()).toList(),
      'artists': instance.artists?.map((e) => e.toJson()).toList(),
      'displayArtist': instance.displayArtist,
      'albumArtists': instance.albumArtists?.map((e) => e.toJson()).toList(),
      'displayAlbumArtist': instance.displayAlbumArtist,
      'contributors': instance.contributors?.map((e) => e.toJson()).toList(),
      'displayComposer': instance.displayComposer,
      'moods': instance.moods,
      'bpm': instance.bpm,
      'comment': instance.comment,
      'mediaType': instance.mediaType,
    };

SubsonicSongList _$SubsonicSongListFromJson(Map<String, dynamic> json) =>
    SubsonicSongList(
      song: (json['song'] as List<dynamic>?)
          ?.map((e) => SubsonicChild.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SubsonicSongListToJson(SubsonicSongList instance) =>
    <String, dynamic>{'song': instance.song?.map((e) => e.toJson()).toList()};

SubsonicSongsByGenre _$SubsonicSongsByGenreFromJson(
  Map<String, dynamic> json,
) => SubsonicSongsByGenre(
  child: (json['child'] as List<dynamic>?)
      ?.map((e) => SubsonicChild.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SubsonicSongsByGenreToJson(
  SubsonicSongsByGenre instance,
) => <String, dynamic>{
  'child': instance.child?.map((e) => e.toJson()).toList(),
};

SubsonicSearchResult3 _$SubsonicSearchResult3FromJson(
  Map<String, dynamic> json,
) => SubsonicSearchResult3(
  artist: (json['artist'] as List<dynamic>?)
      ?.map((e) => SubsonicArtistID3.fromJson(e as Map<String, dynamic>))
      .toList(),
  album: (json['album'] as List<dynamic>?)
      ?.map((e) => SubsonicAlbumID3.fromJson(e as Map<String, dynamic>))
      .toList(),
  song: (json['song'] as List<dynamic>?)
      ?.map((e) => SubsonicChild.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SubsonicSearchResult3ToJson(
  SubsonicSearchResult3 instance,
) => <String, dynamic>{
  'artist': instance.artist?.map((e) => e.toJson()).toList(),
  'album': instance.album?.map((e) => e.toJson()).toList(),
  'song': instance.song?.map((e) => e.toJson()).toList(),
};

SubsonicStarred2 _$SubsonicStarred2FromJson(Map<String, dynamic> json) =>
    SubsonicStarred2(
      artist: (json['artist'] as List<dynamic>?)
          ?.map((e) => SubsonicArtistID3.fromJson(e as Map<String, dynamic>))
          .toList(),
      album: (json['album'] as List<dynamic>?)
          ?.map((e) => SubsonicAlbumID3.fromJson(e as Map<String, dynamic>))
          .toList(),
      song: (json['song'] as List<dynamic>?)
          ?.map((e) => SubsonicChild.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SubsonicStarred2ToJson(SubsonicStarred2 instance) =>
    <String, dynamic>{
      'artist': instance.artist?.map((e) => e.toJson()).toList(),
      'album': instance.album?.map((e) => e.toJson()).toList(),
      'song': instance.song?.map((e) => e.toJson()).toList(),
    };

SubsonicPlaylist _$SubsonicPlaylistFromJson(Map<String, dynamic> json) =>
    SubsonicPlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      comment: json['comment'] as String?,
      owner: json['owner'] as String?,
      public: json['public'] as bool?,
      songCount: (json['songCount'] as num).toInt(),
      duration: (json['duration'] as num).toInt(),
      created: json['created'] as String?,
      changed: json['changed'] as String?,
      coverArt: json['coverArt'] as String?,
      allowedUser: (json['allowedUser'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$SubsonicPlaylistToJson(SubsonicPlaylist instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'comment': instance.comment,
      'owner': instance.owner,
      'public': instance.public,
      'songCount': instance.songCount,
      'duration': instance.duration,
      'created': instance.created,
      'changed': instance.changed,
      'coverArt': instance.coverArt,
      'allowedUser': instance.allowedUser,
    };

SubsonicPlaylistWithSongs _$SubsonicPlaylistWithSongsFromJson(
  Map<String, dynamic> json,
) => SubsonicPlaylistWithSongs(
  id: json['id'] as String,
  name: json['name'] as String,
  comment: json['comment'] as String?,
  owner: json['owner'] as String?,
  public: json['public'] as bool?,
  songCount: (json['songCount'] as num).toInt(),
  duration: (json['duration'] as num).toInt(),
  created: json['created'] as String?,
  changed: json['changed'] as String?,
  coverArt: json['coverArt'] as String?,
  allowedUser: (json['allowedUser'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  entry: (json['entry'] as List<dynamic>?)
      ?.map((e) => SubsonicChild.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SubsonicPlaylistWithSongsToJson(
  SubsonicPlaylistWithSongs instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'comment': instance.comment,
  'owner': instance.owner,
  'public': instance.public,
  'songCount': instance.songCount,
  'duration': instance.duration,
  'created': instance.created,
  'changed': instance.changed,
  'coverArt': instance.coverArt,
  'allowedUser': instance.allowedUser,
  'entry': instance.entry?.map((e) => e.toJson()).toList(),
};

SubsonicPlaylists _$SubsonicPlaylistsFromJson(Map<String, dynamic> json) =>
    SubsonicPlaylists(
      playlist: (json['playlist'] as List<dynamic>?)
          ?.map((e) => SubsonicPlaylist.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SubsonicPlaylistsToJson(SubsonicPlaylists instance) =>
    <String, dynamic>{
      'playlist': instance.playlist?.map((e) => e.toJson()).toList(),
    };

SubsonicLyricLine _$SubsonicLyricLineFromJson(Map<String, dynamic> json) =>
    SubsonicLyricLine(
      start: (json['start'] as num?)?.toInt(),
      value: json['value'] as String,
    );

Map<String, dynamic> _$SubsonicLyricLineToJson(SubsonicLyricLine instance) =>
    <String, dynamic>{'start': instance.start, 'value': instance.value};

SubsonicStructuredLyrics _$SubsonicStructuredLyricsFromJson(
  Map<String, dynamic> json,
) => SubsonicStructuredLyrics(
  lang: json['lang'] as String,
  synced: json['synced'] as bool,
  displayArtist: json['displayArtist'] as String?,
  displayTitle: json['displayTitle'] as String?,
  offset: (json['offset'] as num?)?.toDouble(),
  line: (json['line'] as List<dynamic>)
      .map((e) => SubsonicLyricLine.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SubsonicStructuredLyricsToJson(
  SubsonicStructuredLyrics instance,
) => <String, dynamic>{
  'lang': instance.lang,
  'synced': instance.synced,
  'displayArtist': instance.displayArtist,
  'displayTitle': instance.displayTitle,
  'offset': instance.offset,
  'line': instance.line.map((e) => e.toJson()).toList(),
};

SubsonicLyricsList _$SubsonicLyricsListFromJson(Map<String, dynamic> json) =>
    SubsonicLyricsList(
      structuredLyrics: (json['structuredLyrics'] as List<dynamic>?)
          ?.map(
            (e) => SubsonicStructuredLyrics.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );

Map<String, dynamic> _$SubsonicLyricsListToJson(SubsonicLyricsList instance) =>
    <String, dynamic>{
      'structuredLyrics': instance.structuredLyrics
          ?.map((e) => e.toJson())
          .toList(),
    };

SubsonicUser _$SubsonicUserFromJson(Map<String, dynamic> json) => SubsonicUser(
  username: json['username'] as String,
  email: json['email'] as String?,
  scrobblingEnabled: json['scrobblingEnabled'] as bool,
  maxBitRate: (json['maxBitRate'] as num?)?.toInt(),
  adminRole: json['adminRole'] as bool,
  downloadRole: json['downloadRole'] as bool,
  uploadRole: json['uploadRole'] as bool,
  playlistRole: json['playlistRole'] as bool,
  coverArtRole: json['coverArtRole'] as bool,
  commentRole: json['commentRole'] as bool,
  podcastRole: json['podcastRole'] as bool,
  streamRole: json['streamRole'] as bool,
  jukeboxRole: json['jukeboxRole'] as bool,
  shareRole: json['shareRole'] as bool,
  folder: (json['folder'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
);

Map<String, dynamic> _$SubsonicUserToJson(SubsonicUser instance) =>
    <String, dynamic>{
      'username': instance.username,
      'email': instance.email,
      'scrobblingEnabled': instance.scrobblingEnabled,
      'maxBitRate': instance.maxBitRate,
      'adminRole': instance.adminRole,
      'downloadRole': instance.downloadRole,
      'uploadRole': instance.uploadRole,
      'playlistRole': instance.playlistRole,
      'coverArtRole': instance.coverArtRole,
      'commentRole': instance.commentRole,
      'podcastRole': instance.podcastRole,
      'streamRole': instance.streamRole,
      'jukeboxRole': instance.jukeboxRole,
      'shareRole': instance.shareRole,
      'folder': instance.folder,
    };

SubsonicScanStatus _$SubsonicScanStatusFromJson(Map<String, dynamic> json) =>
    SubsonicScanStatus(
      scanning: json['scanning'] as bool,
      count: (json['count'] as num?)?.toInt(),
      lastScan: json['lastScan'] as String?,
      folderCount: (json['folderCount'] as num?)?.toInt(),
    );

Map<String, dynamic> _$SubsonicScanStatusToJson(SubsonicScanStatus instance) =>
    <String, dynamic>{
      'scanning': instance.scanning,
      'count': instance.count,
      'lastScan': instance.lastScan,
      'folderCount': instance.folderCount,
    };
