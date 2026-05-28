import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient;
import 'dart:math';

import 'package:chopper/chopper.dart';
import 'package:crypto/crypto.dart';
import 'package:finamp/services/http_aggregate_logging_interceptor.dart';
import 'package:get_it/get_it.dart';
import 'package:http/io_client.dart' as http;

import 'subsonic_user_helper.dart';

part 'subsonic_api.chopper.dart';

const String _apiVersion = '1.16.1';
const String _clientName = 'naviamp';

// ─── Auth token generation ────────────────────────────────────────────────────

class SubsonicAuth {
  static final _rng = Random.secure();
  static const _saltChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

  /// Generates a random salt string (10 chars).
  static String generateSalt([int length = 10]) {
    return List.generate(
      length,
      (_) => _saltChars[_rng.nextInt(_saltChars.length)],
    ).join();
  }

  /// Computes the Subsonic auth token: md5(password + salt).
  static String generateToken(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    return md5.convert(bytes).toString();
  }
}

// ─── Chopper service ──────────────────────────────────────────────────────────

@ChopperApi()
abstract class SubsonicApi extends ChopperService {
  // ── Server ────────────────────────────────────────────────────────────────

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/ping.view')
  Future<dynamic> ping();

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/getUser.view')
  Future<dynamic> getUser({@Query('username') required String username});

  // ── Music folders / libraries ─────────────────────────────────────────────

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/getMusicFolders.view')
  Future<dynamic> getMusicFolders();

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/getScanStatus.view')
  Future<dynamic> getScanStatus();

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/startScan.view')
  Future<dynamic> startScan({
    @Query('fullScan') bool? fullScan,
  });

  // ── Browsing ──────────────────────────────────────────────────────────────

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/getArtists.view')
  Future<dynamic> getArtists({
    @Query('musicFolderId') int? musicFolderId,
  });

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/getArtist.view')
  Future<dynamic> getArtist({
    @Query('id') required String id,
  });

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/getAlbum.view')
  Future<dynamic> getAlbum({
    @Query('id') required String id,
  });

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/getSong.view')
  Future<dynamic> getSong({
    @Query('id') required String id,
  });

  /// [type] options: 'random' | 'newest' | 'highest' | 'frequent' | 'recent' |
  /// 'alphabeticalByName' | 'alphabeticalByArtist' | 'starred' |
  /// 'byYear' | 'byGenre'
  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/getAlbumList2.view')
  Future<dynamic> getAlbumList2({
    @Query('type') required String type,
    @Query('size') int? size,
    @Query('offset') int? offset,
    @Query('fromYear') int? fromYear,
    @Query('toYear') int? toYear,
    @Query('genre') String? genre,
    @Query('musicFolderId') int? musicFolderId,
  });

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/getGenres.view')
  Future<dynamic> getGenres();

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/getSongsByGenre.view')
  Future<dynamic> getSongsByGenre({
    @Query('genre') required String genre,
    @Query('count') int? count,
    @Query('offset') int? offset,
    @Query('musicFolderId') int? musicFolderId,
  });

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/getRandomSongs.view')
  Future<dynamic> getRandomSongs({
    @Query('size') int? size,
    @Query('genre') String? genre,
    @Query('fromYear') int? fromYear,
    @Query('toYear') int? toYear,
    @Query('musicFolderId') int? musicFolderId,
  });

  // ── Search ────────────────────────────────────────────────────────────────

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/search3.view')
  Future<dynamic> search3({
    @Query('query') required String query,
    @Query('artistCount') int? artistCount,
    @Query('artistOffset') int? artistOffset,
    @Query('albumCount') int? albumCount,
    @Query('albumOffset') int? albumOffset,
    @Query('songCount') int? songCount,
    @Query('songOffset') int? songOffset,
    @Query('musicFolderId') int? musicFolderId,
  });

  // ── Starred ───────────────────────────────────────────────────────────────

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/getStarred2.view')
  Future<dynamic> getStarred2({
    @Query('musicFolderId') int? musicFolderId,
  });

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/star.view')
  Future<dynamic> star({
    @Query('id') String? id,
    @Query('albumId') String? albumId,
    @Query('artistId') String? artistId,
  });

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/unstar.view')
  Future<dynamic> unstar({
    @Query('id') String? id,
    @Query('albumId') String? albumId,
    @Query('artistId') String? artistId,
  });

  // ── Playlists ─────────────────────────────────────────────────────────────

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/getPlaylists.view')
  Future<dynamic> getPlaylists({
    @Query('username') String? username,
  });

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/getPlaylist.view')
  Future<dynamic> getPlaylist({
    @Query('id') required String id,
  });

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/createPlaylist.view')
  Future<dynamic> createPlaylist({
    @Query('playlistId') String? playlistId,
    @Query('name') String? name,
    @Query('songId') List<String>? songId,
  });

  /// To add songs: pass [songIdToAdd]. To remove: pass [songIndexToRemove]
  /// (0-based indexes into the playlist).
  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/updatePlaylist.view')
  Future<dynamic> updatePlaylist({
    @Query('playlistId') required String playlistId,
    @Query('name') String? name,
    @Query('comment') String? comment,
    @Query('public') bool? public,
    @Query('songIdToAdd') List<String>? songIdToAdd,
    @Query('songIndexToRemove') List<int>? songIndexToRemove,
  });

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/deletePlaylist.view')
  Future<dynamic> deletePlaylist({
    @Query('id') required String id,
  });

  // ── Playback reporting (scrobbling) ───────────────────────────────────────

  /// [submission] true = completed play (scrobble); false = now playing notification.
  /// [time] = unix timestamp in milliseconds when the song was played.
  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/scrobble.view')
  Future<dynamic> scrobble({
    @Query('id') required String id,
    @Query('time') int? time,
    @Query('submission') bool? submission,
  });

  // ── Bookmarks / play position ─────────────────────────────────────────────
  // TODO(bookmark): Implement OpenSubsonic savePlayQueue / getBookmarks to
  // persist and restore playback position across sessions and devices.
  // Endpoints: POST /rest/savePlayQueue.view (id, current, position ms),
  //            GET  /rest/getPlayQueue.view (returns saved queue + position).
  // Wire save into playback_history_service.dart reportPlaybackStopped() and
  // restore into the queue-restore flow.

  // ── Lyrics ────────────────────────────────────────────────────────────────

  /// Legacy lyrics lookup by artist name and track title.
  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/getLyrics.view')
  Future<dynamic> getLyrics({
    @Query('artist') String? artist,
    @Query('title') String? title,
  });

  /// OpenSubsonic structured lyrics (synced/multi-language) by song ID.
  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/getLyricsBySongId.view')
  Future<dynamic> getLyricsBySongId({
    @Query('id') required String id,
  });

  // ── Similar / mix ─────────────────────────────────────────────────────────

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/getSimilarSongs2.view')
  Future<dynamic> getSimilarSongs2({
    @Query('id') required String id,
    @Query('count') int? count,
  });

  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/getTopSongs.view')
  Future<dynamic> getTopSongs({
    @Query('artist') required String artist,
    @Query('count') int? count,
  });

  /// OpenSubsonic: generate an instant mix from any media item (song/album/artist).
  @FactoryConverter(response: JsonConverter.responseFactory)
  @GET(path: '/rest/getInstantMix.view')
  Future<dynamic> getInstantMix({
    @Query('id') required String id,
    @Query('count') int? count,
    @Query('offset') int? offset,
  });

  // ── Factory ───────────────────────────────────────────────────────────────

  static SubsonicApi create() {
    final client = ChopperClient(
      client: http.IOClient(
        HttpClient()..connectionTimeout = const Duration(seconds: 10),
      ),
      services: [_$SubsonicApi()],
      interceptors: [
        SubsonicInterceptor(),
        HttpAggregateLoggingInterceptor(level: Level.body),
      ],
    );
    return _$SubsonicApi(client);
  }
}

// ─── Interceptor ─────────────────────────────────────────────────────────────

/// Injects the Subsonic auth query parameters and base URL into every request.
///
/// Every Subsonic request must carry: u (username), t (md5 token), s (salt),
/// v (API version), c (client name), f=json. A fresh salt and token are
/// generated per request as required by the spec.
class SubsonicInterceptor implements Interceptor {
  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(Chain<BodyType> chain) async {
    return chain.proceed(_buildRequest(chain.request));
  }

  Request _buildRequest(Request request) {
    final helper = GetIt.instance<SubsonicUserHelper>();

    final serverUrl = helper.serverUrlOverride ?? helper.serverUrl;
    if (serverUrl == null) {
      // Credentials not yet set; pass through unmodified so ping-for-login works
      return request;
    }

    Uri baseUri = Uri.parse(serverUrl);
    baseUri = baseUri.replace(
      pathSegments: baseUri.pathSegments.followedBy(request.uri.pathSegments),
    );

    // Merge caller-supplied query params with auth params.
    // Auth params go last so they can't be accidentally overridden.
    final Map<String, dynamic> queryParams = Map.of(request.parameters);

    final creds = helper.credentials;
    if (creds != null) {
      final salt = SubsonicAuth.generateSalt();
      final token = SubsonicAuth.generateToken(creds.password, salt);
      queryParams.addAll({
        'u': creds.username,
        't': token,
        's': salt,
        'v': _apiVersion,
        'c': _clientName,
        'f': 'json',
      });
    } else {
      // No credentials yet (server probing during login) — still add format/version
      queryParams.addAll({'v': _apiVersion, 'c': _clientName, 'f': 'json'});
    }

    return request.copyWith(uri: baseUri, parameters: queryParams);
  }
}
