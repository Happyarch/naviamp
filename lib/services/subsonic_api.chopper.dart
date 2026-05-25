// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subsonic_api.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$SubsonicApi extends SubsonicApi {
  _$SubsonicApi([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = SubsonicApi;

  @override
  Future<dynamic> ping() async {
    final Uri $url = Uri.parse('/rest/ping.view');
    final Request $request = Request('GET', $url, client.baseUrl);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getUser({required String username}) async {
    final Uri $url = Uri.parse('/rest/getUser.view');
    final Map<String, dynamic> $params = <String, dynamic>{
      'username': username,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getMusicFolders() async {
    final Uri $url = Uri.parse('/rest/getMusicFolders.view');
    final Request $request = Request('GET', $url, client.baseUrl);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getScanStatus() async {
    final Uri $url = Uri.parse('/rest/getScanStatus.view');
    final Request $request = Request('GET', $url, client.baseUrl);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> startScan({bool? fullScan}) async {
    final Uri $url = Uri.parse('/rest/startScan.view');
    final Map<String, dynamic> $params = <String, dynamic>{
      'fullScan': fullScan,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getArtists({int? musicFolderId}) async {
    final Uri $url = Uri.parse('/rest/getArtists.view');
    final Map<String, dynamic> $params = <String, dynamic>{
      'musicFolderId': musicFolderId,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getArtist({required String id}) async {
    final Uri $url = Uri.parse('/rest/getArtist.view');
    final Map<String, dynamic> $params = <String, dynamic>{'id': id};
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getAlbum({required String id}) async {
    final Uri $url = Uri.parse('/rest/getAlbum.view');
    final Map<String, dynamic> $params = <String, dynamic>{'id': id};
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getAlbumList2({
    required String type,
    int? size,
    int? offset,
    int? fromYear,
    int? toYear,
    String? genre,
    int? musicFolderId,
  }) async {
    final Uri $url = Uri.parse('/rest/getAlbumList2.view');
    final Map<String, dynamic> $params = <String, dynamic>{
      'type': type,
      'size': size,
      'offset': offset,
      'fromYear': fromYear,
      'toYear': toYear,
      'genre': genre,
      'musicFolderId': musicFolderId,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getGenres() async {
    final Uri $url = Uri.parse('/rest/getGenres.view');
    final Request $request = Request('GET', $url, client.baseUrl);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getSongsByGenre({
    required String genre,
    int? count,
    int? offset,
    int? musicFolderId,
  }) async {
    final Uri $url = Uri.parse('/rest/getSongsByGenre.view');
    final Map<String, dynamic> $params = <String, dynamic>{
      'genre': genre,
      'count': count,
      'offset': offset,
      'musicFolderId': musicFolderId,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getRandomSongs({
    int? size,
    String? genre,
    int? fromYear,
    int? toYear,
    int? musicFolderId,
  }) async {
    final Uri $url = Uri.parse('/rest/getRandomSongs.view');
    final Map<String, dynamic> $params = <String, dynamic>{
      'size': size,
      'genre': genre,
      'fromYear': fromYear,
      'toYear': toYear,
      'musicFolderId': musicFolderId,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> search3({
    required String query,
    int? artistCount,
    int? artistOffset,
    int? albumCount,
    int? albumOffset,
    int? songCount,
    int? songOffset,
    int? musicFolderId,
  }) async {
    final Uri $url = Uri.parse('/rest/search3.view');
    final Map<String, dynamic> $params = <String, dynamic>{
      'query': query,
      'artistCount': artistCount,
      'artistOffset': artistOffset,
      'albumCount': albumCount,
      'albumOffset': albumOffset,
      'songCount': songCount,
      'songOffset': songOffset,
      'musicFolderId': musicFolderId,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getStarred2({int? musicFolderId}) async {
    final Uri $url = Uri.parse('/rest/getStarred2.view');
    final Map<String, dynamic> $params = <String, dynamic>{
      'musicFolderId': musicFolderId,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> star({String? id, String? albumId, String? artistId}) async {
    final Uri $url = Uri.parse('/rest/star.view');
    final Map<String, dynamic> $params = <String, dynamic>{
      'id': id,
      'albumId': albumId,
      'artistId': artistId,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> unstar({
    String? id,
    String? albumId,
    String? artistId,
  }) async {
    final Uri $url = Uri.parse('/rest/unstar.view');
    final Map<String, dynamic> $params = <String, dynamic>{
      'id': id,
      'albumId': albumId,
      'artistId': artistId,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getPlaylists({String? username}) async {
    final Uri $url = Uri.parse('/rest/getPlaylists.view');
    final Map<String, dynamic> $params = <String, dynamic>{
      'username': username,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getPlaylist({required String id}) async {
    final Uri $url = Uri.parse('/rest/getPlaylist.view');
    final Map<String, dynamic> $params = <String, dynamic>{'id': id};
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> createPlaylist({
    String? playlistId,
    String? name,
    List<String>? songId,
  }) async {
    final Uri $url = Uri.parse('/rest/createPlaylist.view');
    final Map<String, dynamic> $params = <String, dynamic>{
      'playlistId': playlistId,
      'name': name,
      'songId': songId,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> updatePlaylist({
    required String playlistId,
    String? name,
    String? comment,
    bool? public,
    List<String>? songIdToAdd,
    List<int>? songIndexToRemove,
  }) async {
    final Uri $url = Uri.parse('/rest/updatePlaylist.view');
    final Map<String, dynamic> $params = <String, dynamic>{
      'playlistId': playlistId,
      'name': name,
      'comment': comment,
      'public': public,
      'songIdToAdd': songIdToAdd,
      'songIndexToRemove': songIndexToRemove,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> deletePlaylist({required String id}) async {
    final Uri $url = Uri.parse('/rest/deletePlaylist.view');
    final Map<String, dynamic> $params = <String, dynamic>{'id': id};
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> scrobble({
    required String id,
    int? time,
    bool? submission,
  }) async {
    final Uri $url = Uri.parse('/rest/scrobble.view');
    final Map<String, dynamic> $params = <String, dynamic>{
      'id': id,
      'time': time,
      'submission': submission,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getLyrics({String? artist, String? title}) async {
    final Uri $url = Uri.parse('/rest/getLyrics.view');
    final Map<String, dynamic> $params = <String, dynamic>{
      'artist': artist,
      'title': title,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getLyricsBySongId({required String id}) async {
    final Uri $url = Uri.parse('/rest/getLyricsBySongId.view');
    final Map<String, dynamic> $params = <String, dynamic>{'id': id};
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getSimilarSongs2({required String id, int? count}) async {
    final Uri $url = Uri.parse('/rest/getSimilarSongs2.view');
    final Map<String, dynamic> $params = <String, dynamic>{
      'id': id,
      'count': count,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getTopSongs({required String artist, int? count}) async {
    final Uri $url = Uri.parse('/rest/getTopSongs.view');
    final Map<String, dynamic> $params = <String, dynamic>{
      'artist': artist,
      'count': count,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getInstantMix({
    required String id,
    int? count,
    int? offset,
  }) async {
    final Uri $url = Uri.parse('/rest/getInstantMix.view');
    final Map<String, dynamic> $params = <String, dynamic>{
      'id': id,
      'count': count,
      'offset': offset,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }
}
