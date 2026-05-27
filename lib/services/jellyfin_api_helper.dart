import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:chopper/chopper.dart';
import 'package:collection/collection.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/services/http_aggregate_logging_interceptor.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_user_certificates_android/flutter_user_certificates_android.dart';
import 'package:get_it/get_it.dart';
import 'package:http/io_client.dart' as http;
import 'package:isar/isar.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import '../models/finamp_models.dart';
import '../models/jellyfin_models.dart';
import 'downloads_service.dart';
import 'downloads_service_backend.dart';
import 'finamp_settings_helper.dart';
import 'finamp_user_helper.dart';
import 'jellyfin_api.dart' as jellyfin_api;
import 'subsonic_api_helper.dart';
import 'subsonic_user_helper.dart';

class JellyfinApiHelper {
  final jellyfinApi = jellyfin_api.JellyfinApi.create(true);
  final _jellyfinApiHelperLogger = Logger("JellyfinApiHelper");

  // Stores the ids of the artists that the user selected to mix
  List<BaseItemDto> selectedMixArtists = [];

  // Stores the ids of albums that the user selected to mix
  List<BaseItemDto> selectedMixAlbums = [];

  // Stores the ids of genres that the user selected to mix
  List<BaseItemDto> selectedMixGenres = [];

  Uri? baseUrlTemp;

  final String defaultFields = jellyfin_api.defaultFields;

  final _finampUserHelper = GetIt.instance<FinampUserHelper>();

  JellyfinApiHelper() {
    ReceivePort startupPort = ReceivePort();
    var rootToken = RootIsolateToken.instance!;
    Isolate.spawn(_processRequestsBackground, (startupPort.sendPort, rootToken));
    Future.sync(() async {
      _workerIsolatePort = await startupPort.first as SendPort?;
    });
  }

  SendPort? _workerIsolatePort;

  /// This should only be run in a worker isolate
  /// Sets up singletons and listens for work.
  static Future<void> _processRequestsBackground((SendPort, RootIsolateToken) input) async {
    BackgroundIsolateBinaryMessenger.ensureInitialized(input.$2);
    ReceivePort requestPort = ReceivePort();

    // Extend the default security context to trust Android user certificates.
    // This is a workaround for <https://github.com/dart-lang/sdk/issues/50435>.
    await FlutterUserCertificatesAndroid().trustAndroidUserCertificates(SecurityContext.defaultContext);

    input.$1.send(requestPort.sendPort);
    final dir = (Platform.isAndroid || Platform.isIOS)
        ? await getApplicationDocumentsDirectory()
        : await getApplicationSupportDirectory();
    final isar = await Isar.open(
      [DownloadItemSchema, IsarTaskDataSchema, FinampUserSchema],
      directory: dir.path,
      name: isarDatabaseName,
      compactOnLaunch: CompactCondition(minBytes: 5 * 1024 * 1024),
      relaxedDurability: true,
    );
    GetIt.instance.registerSingleton(isar);
    GetIt.instance.registerSingleton(FinampUserHelper());
    // TODO get logging working in background isolate
    await GetIt.instance<FinampUserHelper>().setAuthHeader();
    jellyfin_api.JellyfinApi backgroundApi = jellyfin_api.JellyfinApi.create(false);
    await for (var request in requestPort) {
      var (func, outputPort) = request as (Future<dynamic> Function(jellyfin_api.JellyfinApi), SendPort);
      try {
        var output = await func(backgroundApi);
        outputPort.send(output);
      } catch (e) {
        outputPort.send(e);
      }
    }
  }

  /// Runs the given function in a background isolate, supplying a valid API instance.
  Future<T> runInIsolate<T>(Future<T> Function(jellyfin_api.JellyfinApi) func) async {
    if (_workerIsolatePort == null) {
      return func(jellyfinApi);
    }
    ReceivePort port = ReceivePort();
    try {
      _workerIsolatePort!.send((func, port.sendPort));
    } catch (e) {
      GlobalSnackbar.error(e);
    }
    dynamic output = await port.first;
    if (output is T) {
      return output;
    }
    _jellyfinApiHelperLogger.severe("Error in background isolate: $output", output);
    throw output as Object;
  }

  Future<List<BaseItemDto>?> getItems({
    BaseItemDto? parentItem,
    BaseItemDto? libraryFilter,
    String? includeItemTypes,
    String? sortBy,
    String? sortOrder,
    String? searchTerm,
    List<BaseItemId>? itemIds,
    List<BaseItemId>? albumIds,
    String? filters,
    String? fields,
    bool? recursive,
    ArtistType? artistType,
    BaseItemDto? genreFilter,
    bool? isFavorite,

    /// The record index to start at. All items with a lower index will be
    /// dropped from the results.
    int? startIndex,

    /// The maximum number of records to return.
    int? limit,
  }) async {
    final result = await _subsonicFetch(
      parentItem: parentItem,
      libraryFilter: libraryFilter,
      includeItemTypes: includeItemTypes,
      sortBy: sortBy,
      sortOrder: sortOrder,
      searchTerm: searchTerm,
      itemIds: itemIds,
      filters: filters,
      artistType: artistType,
      genreFilter: genreFilter,
      isFavorite: isFavorite,
      startIndex: startIndex,
      limit: limit,
    );
    return result.items;
  }

  Future<QueryResult_BaseItemDto> getItemsWithTotalRecordCount({
    BaseItemDto? parentItem,
    BaseItemDto? libraryFilter,
    String? includeItemTypes,
    String? sortBy,
    String? sortOrder,
    String? searchTerm,
    List<BaseItemId>? itemIds,
    List<BaseItemId>? albumIds,
    String? filters,
    String? fields,
    bool? recursive,
    ArtistType? artistType,
    BaseItemDto? genreFilter,
    bool? isFavorite,
    int? startIndex,
    int? limit,
  }) async {
    return _subsonicFetch(
      parentItem: parentItem,
      libraryFilter: libraryFilter,
      includeItemTypes: includeItemTypes,
      sortBy: sortBy,
      sortOrder: sortOrder,
      searchTerm: searchTerm,
      itemIds: itemIds,
      filters: filters,
      artistType: artistType,
      genreFilter: genreFilter,
      isFavorite: isFavorite,
      startIndex: startIndex,
      limit: limit,
    );
  }

  // ── Subsonic dispatch ─────────────────────────────────────────────────────

  // Extract the Navidrome music folder ID from a CollectionFolder item.
  int? _subsonicMusicFolderId(BaseItemDto? item) {
    if (item?.type != 'CollectionFolder') return null;
    return int.tryParse(item!.id.raw);
  }

  // Map a Jellyfin sortBy string to a Subsonic getAlbumList2 type.
  String _subsonicAlbumListType(String? sortBy) {
    if (sortBy == null) return 'alphabeticalByName';
    final first = sortBy.split(',').first.trim();
    return switch (first) {
      'Random' => 'random',
      'DateCreated' => 'newest',
      'PlayCount' => 'frequent',
      'DatePlayed' => 'recent',
      'AlbumArtist' => 'alphabeticalByArtist',
      _ => 'alphabeticalByName',
    };
  }

  // Client-side sort of a BaseItemDto list.
  List<BaseItemDto> _subsonicSort(List<BaseItemDto> items, String? sortBy, String? sortOrder) {
    if (sortBy == null || sortBy.trim().isEmpty) return items;
    final first = sortBy.split(',').first.trim();
    if (first == 'Random') {
      return List<BaseItemDto>.from(items)..shuffle();
    }
    final desc = sortOrder?.toLowerCase() == 'descending';
    final sorted = List<BaseItemDto>.from(items);
    switch (first) {
      case 'ParentIndexNumber' || 'IndexNumber':
        sorted.sort((a, b) {
          final disc = (a.parentIndexNumber ?? 0).compareTo(b.parentIndexNumber ?? 0);
          if (disc != 0) return desc ? -disc : disc;
          final track = (a.indexNumber ?? 0).compareTo(b.indexNumber ?? 0);
          if (track != 0) return desc ? -track : track;
          final av = a.sortName ?? a.name ?? '';
          final bv = b.sortName ?? b.name ?? '';
          return desc ? bv.compareTo(av) : av.compareTo(bv);
        });
      case 'PremiereDate' || 'ProductionYear':
        sorted.sort((a, b) {
          final ay = a.productionYear ?? 0;
          final by_ = b.productionYear ?? 0;
          final cmp = ay.compareTo(by_);
          if (cmp != 0) return desc ? -cmp : cmp;
          final av = a.sortName ?? a.name ?? '';
          final bv = b.sortName ?? b.name ?? '';
          return desc ? bv.compareTo(av) : av.compareTo(bv);
        });
      default:
        sorted.sort((a, b) {
          final av = a.sortName ?? a.name ?? '';
          final bv = b.sortName ?? b.name ?? '';
          return desc ? bv.compareTo(av) : av.compareTo(bv);
        });
    }
    return sorted;
  }

  // Extract a page from a list.
  List<T> _subsonicPaginate<T>(List<T> items, int? startIndex, int? limit) {
    final start = (startIndex ?? 0).clamp(0, items.length);
    final end = limit != null ? (start + limit).clamp(start, items.length) : items.length;
    return items.sublist(start, end);
  }

  // Central Subsonic dispatch used by getItems / getItemsWithTotalRecordCount.
  Future<QueryResult_BaseItemDto> _subsonicFetch({
    BaseItemDto? parentItem,
    BaseItemDto? libraryFilter,
    String? includeItemTypes,
    String? sortBy,
    String? sortOrder,
    String? searchTerm,
    List<BaseItemId>? itemIds,
    String? filters,
    ArtistType? artistType,
    BaseItemDto? genreFilter,
    bool? isFavorite,
    int? startIndex,
    int? limit,
  }) async {
    final sub = GetIt.instance<SubsonicApiHelper>();
    final musicFolderId =
        _subsonicMusicFolderId(libraryFilter) ?? _subsonicMusicFolderId(parentItem);
    final isFav = isFavorite == true || filters == 'IsFavorite';

    // 1. Batch item-ID fetch (used by getItemByIdBatched for queue restore).
    if (itemIds != null) {
      if (itemIds.isEmpty) {
        return QueryResult_BaseItemDto(items: [], totalRecordCount: 0, startIndex: 0);
      }
      final results = await Future.wait(itemIds.map((id) => sub.getSongDto(id.raw)));
      final items = results.nonNulls.toList();
      return QueryResult_BaseItemDto(items: items, totalRecordCount: items.length, startIndex: 0);
    }

    // 2. Full-text search.
    final trimmed = searchTerm?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      final r = await sub.search3(trimmed);
      final items = switch (includeItemTypes) {
        'MusicArtist' => r.artists,
        'MusicAlbum' => r.albums,
        'Audio' => r.songs,
        _ => [...r.artists, ...r.albums, ...r.songs],
      };
      return QueryResult_BaseItemDto(items: items, totalRecordCount: items.length, startIndex: 0);
    }

    // 3. Playlist children.
    if (parentItem?.type == 'Playlist') {
      final (_, songs) = await sub.getPlaylist(parentItem!.id.raw);
      return QueryResult_BaseItemDto(items: songs, totalRecordCount: songs.length, startIndex: 0);
    }

    // 4. Artist children (albums or tracks).
    if (parentItem?.type == 'MusicArtist') {
      final (_, albums) = await sub.getArtist(parentItem!.id.raw);
      if (includeItemTypes == 'MusicAlbum') {
        var filtered = genreFilter != null
            ? albums.where((a) => a.genres?.contains(genreFilter.name) ?? false).toList()
            : albums;
        if (isFav) filtered = filtered.where((a) => a.userData?.isFavorite == true).toList();
        final sorted = _subsonicSort(filtered, sortBy, sortOrder);
        return QueryResult_BaseItemDto(items: sorted, totalRecordCount: sorted.length, startIndex: 0);
      } else if (includeItemTypes == 'Audio') {
        // Expand each album to get its tracks.
        final trackLists = await Future.wait(albums.map((a) => sub.getAlbum(a.id.raw).then((r) => r.$2)));
        var songs = trackLists.expand((l) => l).toList();
        if (genreFilter != null) {
          songs = songs.where((s) => s.genres?.contains(genreFilter.name) ?? false).toList();
        }
        if (isFav) songs = songs.where((s) => s.userData?.isFavorite == true).toList();
        final sorted = _subsonicSort(songs, sortBy, sortOrder);
        final page = _subsonicPaginate(sorted, startIndex, limit);
        return QueryResult_BaseItemDto(items: page, totalRecordCount: sorted.length, startIndex: startIndex ?? 0);
      }
    }

    // 5. Album children (tracks).
    if (parentItem?.type == 'MusicAlbum') {
      final (_, songs) = await sub.getAlbum(parentItem!.id.raw);
      final sorted = _subsonicSort(songs, sortBy, sortOrder);
      return QueryResult_BaseItemDto(items: sorted, totalRecordCount: sorted.length, startIndex: 0);
    }

    // 6. Genre-filtered browse.
    if (genreFilter != null) {
      switch (includeItemTypes) {
        case 'MusicAlbum':
          final albums = await sub.getAlbumList2(
            type: 'byGenre',
            size: limit ?? 5,
            offset: startIndex,
            genre: genreFilter.name,
            musicFolderId: musicFolderId,
          );
          final filtered = isFav ? albums.where((a) => a.userData?.isFavorite == true).toList() : albums;
          return QueryResult_BaseItemDto(
            items: filtered,
            totalRecordCount: genreFilter.albumCount ?? filtered.length,
            startIndex: startIndex ?? 0,
          );
        case 'Audio':
          final songs = await sub.getSongsByGenre(
            genreFilter.name!,
            count: limit,
            offset: startIndex,
            musicFolderId: musicFolderId,
          );
          final filtered = isFav ? songs.where((s) => s.userData?.isFavorite == true).toList() : songs;
          return QueryResult_BaseItemDto(
            items: filtered,
            totalRecordCount: genreFilter.songCount ?? filtered.length,
            startIndex: startIndex ?? 0,
          );
        default:
          return QueryResult_BaseItemDto(items: [], totalRecordCount: 0, startIndex: 0);
      }
    }

    // 7. Favorites.
    if (isFav) {
      final starred = await sub.getStarred(musicFolderId: musicFolderId);
      final items = switch (includeItemTypes) {
        'MusicArtist' => starred.artists,
        'MusicAlbum' => starred.albums,
        'Audio' => starred.songs,
        _ => [...starred.artists, ...starred.albums, ...starred.songs],
      };
      final sorted = _subsonicSort(items, sortBy, sortOrder);
      final page = _subsonicPaginate(sorted, startIndex, limit);
      return QueryResult_BaseItemDto(items: page, totalRecordCount: sorted.length, startIndex: startIndex ?? 0);
    }

    // 8. Top-level browse by item type.
    switch (includeItemTypes) {
      case 'MusicArtist':
        final all = await sub.getArtists(musicFolderId: musicFolderId);
        final sorted = _subsonicSort(all, sortBy, sortOrder);
        final page = _subsonicPaginate(sorted, startIndex, limit);
        return QueryResult_BaseItemDto(items: page, totalRecordCount: sorted.length, startIndex: startIndex ?? 0);

      case 'MusicAlbum':
        final type = _subsonicAlbumListType(sortBy);
        // Random album lists can't be meaningfully paginated; always use offset 0.
        final albums = await sub.getAlbumList2(
          type: type,
          size: limit ?? 100,
          offset: type == 'random' ? 0 : startIndex,
          musicFolderId: musicFolderId,
        );
        return QueryResult_BaseItemDto(items: albums, totalRecordCount: albums.length, startIndex: startIndex ?? 0);

      case 'Audio':
        final songs = await sub.getRandomSongs(size: limit ?? 100, musicFolderId: musicFolderId);
        return QueryResult_BaseItemDto(items: songs, totalRecordCount: songs.length, startIndex: 0);

      case 'MusicGenre':
        final all = await sub.getGenres();
        final sorted = _subsonicSort(all, sortBy, sortOrder);
        final page = _subsonicPaginate(sorted, startIndex, limit);
        return QueryResult_BaseItemDto(items: page, totalRecordCount: sorted.length, startIndex: startIndex ?? 0);

      case 'Playlist':
        final all = await sub.getPlaylists();
        return QueryResult_BaseItemDto(items: all, totalRecordCount: all.length, startIndex: 0);

      default:
        _jellyfinApiHelperLogger.warning('_subsonicFetch: unhandled includeItemTypes=$includeItemTypes');
        return QueryResult_BaseItemDto(items: [], totalRecordCount: 0, startIndex: 0);
    }
  }

  Future<QueryResult_BaseItemDto> _fetchGetItemsResponse({
    BaseItemDto? parentItem,
    BaseItemDto? libraryFilter,
    String? includeItemTypes,
    String? sortBy,
    String? sortOrder,
    String? searchTerm,
    List<BaseItemId>? itemIds,
    List<BaseItemId>? albumIds,
    String? filters,
    String? fields,
    bool? recursive,
    ArtistType? artistType,
    BaseItemDto? genreFilter,
    bool? isFavorite,
    int? startIndex,
    int? limit,
  }) async {
    final currentUserId = _finampUserHelper.currentUser!.id;
    assert(_verifyCallable());
    assert(itemIds == null || parentItem == null);
    fields ??=
        defaultFields; // explicitly set the default fields, if we pass `null` to [JellyfinAPI.getItems] it will **not** apply the default fields, since the argument *is* provided.
    recursive ??= true;

    if (parentItem != null) {
      _jellyfinApiHelperLogger.fine("Getting children of ${parentItem.name}");
    } else if (itemIds != null) {
      _jellyfinApiHelperLogger.fine("Getting items with ids $itemIds");
      if (itemIds.isEmpty) {
        // An empty itemIds list will not apply a filter to the results, but
        // it should actually return no results
        return QueryResult_BaseItemDto(totalRecordCount: 0, startIndex: 0, items: []);
      }
    } else {
      _jellyfinApiHelperLogger.fine("Getting items.");
    }

    return runInIsolate((api) async {
      dynamic response;

      // We send a different request for playlists so that we get them back in the
      // right order. Doing this in the same function makes sense since they both
      // return the same thing. It also means we can easily share album widgets
      // with playlists.
      if (parentItem?.type == "Playlist") {
        response = await api.getPlaylistItems(
          playlistId: parentItem!.id,
          userId: currentUserId,
          parentId: parentItem.id,
          includeItemTypes: includeItemTypes,
          recursive: recursive,
          fields: fields,
        );
      } else if (includeItemTypes == "MusicArtist") {
        // For artists, we need to use different endpoints
        if (artistType == ArtistType.albumArtist) {
          // Album Artists
          response = await api.getAlbumArtists(
            parentId: parentItem?.id,
            recursive: recursive,
            sortBy: sortBy,
            sortOrder: sortOrder,
            searchTerm: searchTerm,
            filters: filters,
            genreIds: genreFilter?.id.raw,
            startIndex: startIndex,
            limit: limit,
            userId: currentUserId,
            fields: fields,
            isFavorite: isFavorite,
          );
        } else {
          //artistType == ArtistType.artist
          // Performing Artists
          response = await api.getArtists(
            parentId: parentItem?.id,
            sortBy: sortBy,
            sortOrder: sortOrder,
            searchTerm: searchTerm,
            filters: filters,
            genreIds: genreFilter?.id.raw,
            startIndex: startIndex,
            limit: limit,
            fields: fields,
            isFavorite: isFavorite,
          );
        }
      } else if (parentItem?.type == "MusicArtist") {
        // For getting the children of artists, we need to use
        // artistIDs or albumArtistIds instead of parentId
        // also, in order to only get the items from within one library
        // we have to use a separated libraryFilter,
        if (artistType == ArtistType.albumArtist || artistType == null) {
          // Albums of Album Artists
          response = await api.getItems(
            userId: currentUserId,
            parentId: libraryFilter?.id,
            albumArtistIds: parentItem?.id.raw,
            includeItemTypes: includeItemTypes,
            recursive: recursive,
            sortBy: sortBy,
            sortOrder: sortOrder,
            searchTerm: searchTerm,
            filters: filters,
            albumIds: albumIds?.join(","),
            genreIds: genreFilter?.id.raw,
            startIndex: startIndex,
            limit: limit,
            fields: fields,
            isFavorite: isFavorite,
          );
        } else {
          //artistType == ArtistType.artist
          // Performing Artists
          response = await api.getItems(
            userId: currentUserId,
            parentId: libraryFilter?.id,
            artistIds: parentItem?.id.raw,
            includeItemTypes: includeItemTypes,
            recursive: recursive,
            sortBy: sortBy,
            sortOrder: sortOrder,
            searchTerm: searchTerm,
            filters: filters,
            albumIds: albumIds?.join(","),
            genreIds: genreFilter?.id.raw,
            startIndex: startIndex,
            limit: limit,
            fields: fields,
            isFavorite: isFavorite,
          );
        }
      } else if (includeItemTypes == "MusicGenre") {
        response = await api.getGenres(
          parentId: parentItem?.id,
          // includeItemTypes: includeItemTypes,
          sortBy: sortBy,
          sortOrder: sortOrder,
          isFavorite: isFavorite,
          searchTerm: searchTerm,
          startIndex: startIndex,
          limit: limit,
          fields: fields,
        );
      } else if (parentItem?.type == "MusicGenre") {
        response = await api.getItems(
          parentId: libraryFilter?.id,
          userId: currentUserId,
          albumIds: albumIds?.join(","),
          genreIds: parentItem?.id.raw,
          includeItemTypes: includeItemTypes,
          recursive: recursive,
          sortBy: sortBy,
          sortOrder: sortOrder,
          searchTerm: searchTerm,
          filters: filters,
          startIndex: startIndex,
          limit: limit,
          fields: fields,
          isFavorite: isFavorite,
        );
      } else {
        // This will be run when getting albums, tracks in albums, and stuff like
        // that.
        response = await api.getItems(
          userId: currentUserId,
          parentId: parentItem?.id,
          includeItemTypes: includeItemTypes,
          recursive: recursive,
          sortBy: sortBy,
          sortOrder: sortOrder,
          searchTerm: searchTerm,
          filters: filters,
          albumIds: albumIds?.join(","),
          genreIds: genreFilter?.id.raw,
          startIndex: startIndex,
          limit: limit,
          ids: itemIds?.join(","),
          fields: fields,
          isFavorite: isFavorite,
        );
      }
      return QueryResult_BaseItemDto.fromJson(response as Map<String, dynamic>);
    });
  }

  Future<List<BaseItemDto>?> getArtists({
    BaseItemDto? parentItem,
    String? sortBy,
    String? sortOrder,
    String? searchTerm,
    String? filters,
    String? fields,

    /// The record index to start at. All items with a lower index will be
    /// dropped from the results.
    int? startIndex,

    /// The maximum number of records to return.
    int? limit,
  }) async {
    final currentUserId = _finampUserHelper.currentUser?.id;
    if (currentUserId == null) {
      // When logging out, this request causes errors since currentUser is
      // required sometimes. We just return an empty list since this error
      // usually happens because the listeners on MusicScreenTabView update
      // milliseconds before the page is popped. This shouldn't happen in normal
      // use.
      return [];
    }
    assert(_verifyCallable());
    fields ??=
        defaultFields; // explicitly set the default fields, if we pass `null` to [JellyfinAPI.getItems] it will **not** apply the default fields, since the argument *is* provided.

    if (parentItem != null) {
      _jellyfinApiHelperLogger.fine("Getting artists which are children of ${parentItem.name}");
    } else {
      _jellyfinApiHelperLogger.fine("Getting artists.");
    }

    return runInIsolate((api) async {
      dynamic response;

      response = await api.getArtists(
        parentId: parentItem?.id,
        searchTerm: searchTerm,
        fields: fields,
        sortBy: sortBy,
        sortOrder: sortOrder,
        filters: filters,
        startIndex: startIndex,
        limit: limit,
      );

      return QueryResult_BaseItemDto.fromJson(response as Map<String, dynamic>).items;
    });
  }

  Future<dynamic> deleteItem(BaseItemId itemId) async {
    assert(_verifyCallable());
    return await jellyfinApi.deleteItem(itemId);
  }

  Future<List<BaseItemDto>?> getLatestItems({
    BaseItemDto? parentItem,
    String? includeItemTypes,
    int? limit,
    String? fields,
  }) async {
    assert(_verifyCallable());

    fields ??= defaultFields;

    var response = await jellyfinApi.getLatestItems(
      userId: _finampUserHelper.currentUser!.id,
      parentId: parentItem?.id,
      includeItemTypes: includeItemTypes,
      limit: limit,
      fields: fields,
    );

    return (response as List<dynamic>).map((e) => BaseItemDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Fetch the public server info from the server.
  /// Can be used to check if the server is online / the URL is correct.
  Future<PublicSystemInfoResult?> loadServerPublicInfo({Duration? timeout}) async {
    // Some users won't have a password.
    if (_finampUserHelper.currentUser?.baseURL == null && baseUrlTemp == null) {
      return null;
    }

    var request = jellyfinApi.getPublicServerInfo();
    if (timeout != null) {
      request = request.timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException("Failed to fetch server info within the timeout period.");
        },
      );
    }
    var response = await request;

    PublicSystemInfoResult publicSystemInfoResult = PublicSystemInfoResult.fromJson(response as Map<String, dynamic>);

    return publicSystemInfoResult;
  }

  /// Fetch the public server info from a given URL.
  /// Can be used to check if the server is online / the URL is correct.
  /// Since we're potentially looking multiple servers, while the user is entering another base URL, we use a custom http client for this request.
  Future<PublicSystemInfoResult?> loadCustomServerPublicInfo(Uri customServerUrl) async {
    final requestUrl = customServerUrl.replace(
      pathSegments: customServerUrl.pathSegments.followedBy(["System", "Info", "Public"]),
    );
    final httpClient = ChopperClient().httpClient; // http? where we're going, we don't need http
    final response = await httpClient.get(requestUrl);
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      PublicSystemInfoResult publicSystemInfoResult = PublicSystemInfoResult.fromJson(responseJson);

      return publicSystemInfoResult;
    } else {
      return Future.error(response);
    }
  }

  /// Fetch all public users from the server.
  Future<PublicUsersResponse> loadPublicUsers() async {
    // Some users won't have a password.
    if (_finampUserHelper.currentUser?.baseURL == null && baseUrlTemp == null) {
      return PublicUsersResponse(users: []);
    }

    var response = await jellyfinApi.getPublicUsers();

    PublicUsersResponse publicUsersResult = PublicUsersResponse(
      users: (response as List<dynamic>).map((userJson) => UserDto.fromJson(userJson as Map<String, dynamic>)).toList(),
    );

    return publicUsersResult;
  }

  /// Check if server has Quick Connect enabled.
  Future<bool> checkQuickConnect() async {
    var response = await jellyfinApi.getQuickConnectState();
    return response as bool;
  }

  /// Initiate a Quick Connect request.
  Future<QuickConnectState> initiateQuickConnect() async {
    var response = await jellyfinApi.initiateQuickConnect();

    QuickConnectState quickConnectState = QuickConnectState.fromJson(response as Map<String, dynamic>);

    return quickConnectState;
  }

  /// Update the Quick Connect state.
  Future<QuickConnectState?> updateQuickConnect(QuickConnectState quickConnectState) async {
    var response = await jellyfinApi.updateQuickConnect(secret: quickConnectState.secret ?? "");

    QuickConnectState newQuickConnectState = QuickConnectState.fromJson(response as Map<String, dynamic>);

    return newQuickConnectState;
  }

  /// Authorize a pending Quick Connect request of another client
  Future<bool> authorizeQuickConnect({required String code, String? userId}) async {
    Response<dynamic> response = await jellyfinApi.authorizeQuickConnect(code: code, userId: userId);

    return response.isSuccessful;
  }

  /// Authenticates a user using Quick Connect and saves the login details
  Future<void> authenticateWithQuickConnect(QuickConnectState quickConnectState) async {
    var response = await jellyfinApi.authenticateWithQuickConnect({"Secret": quickConnectState.secret ?? ""});

    AuthenticationResult newUserAuthenticationResult = AuthenticationResult.fromJson(response as Map<String, dynamic>);

    FinampUser newUser = FinampUser(
      id: newUserAuthenticationResult.user!.id,
      publicAddress: baseUrlTemp!.toString(),
      localAddress: DefaultSettings.localNetworkAddress,
      isLocal: false,
      preferLocalNetwork: DefaultSettings.preferLocalNetwork,
      accessToken: newUserAuthenticationResult.accessToken!,
      serverId: newUserAuthenticationResult.serverId!,
      views: {},
    );

    await _finampUserHelper.saveUser(newUser);
    baseUrlTemp =
        null; // Clear the temporary base URL after authentication, since this has priority over the regular URL
  }

  /// Authenticates a user and saves the login details
  Future<void> authenticateViaName({required String username, String? password}) async {
    dynamic response;

    // Some users won't have a password.
    if (password == null) {
      response = await jellyfinApi.authenticateViaName({"Username": username});
    } else {
      response = await jellyfinApi.authenticateViaName({"Username": username, "Pw": password});
    }

    AuthenticationResult newUserAuthenticationResult = AuthenticationResult.fromJson(response as Map<String, dynamic>);

    FinampUser newUser = FinampUser(
      id: newUserAuthenticationResult.user!.id,
      publicAddress: baseUrlTemp!.toString(),
      localAddress: DefaultSettings.localNetworkAddress,
      isLocal: false,
      preferLocalNetwork: DefaultSettings.preferLocalNetwork,
      accessToken: newUserAuthenticationResult.accessToken!,
      serverId: newUserAuthenticationResult.serverId!,
      views: {},
    );

    await _finampUserHelper.saveUser(newUser);
    baseUrlTemp =
        null; // Clear the temporary base URL after authentication, since this has priority over the regular URL
  }

  /// Gets the current user.
  Future<UserDto> getUser() async {
    var response = await jellyfinApi.getUser();
    return UserDto.fromJson(response as Map<String, dynamic>);
  }

  /// Gets all the user's views.
  Future<List<BaseItemDto>> getViews() async {
    var response = await jellyfinApi.getViews(_finampUserHelper.currentUser!.id);

    return QueryResult_BaseItemDto.fromJson(response as Map<String, dynamic>).items!;
  }

  /// Gets the playback info for an item, such as format and bitrate. Usually, I'd require a BaseItemDto as an argument
  /// but since this will be run inside of [MusicPlayerBackgroundTask], I've just set the raw id as an argument.
  Future<PlaybackInfoResponse> getPlaybackInfo(BaseItemId itemId) async {
    assert(_verifyCallable());
    var response = await jellyfinApi.getPlaybackInfo(id: itemId, userId: _finampUserHelper.currentUser!.id);

    return PlaybackInfoResponse.fromJson(response as Map<String, dynamic>);
  }

  /// Sends a request for playback info to the server, letting it know which codecs the client will support (to enable automatic transcoding).
  Future<PlaybackInfoResponse> submitPlaybackInfo({
    required BaseItemId itemId,
    required PlaybackInfoRequest playbackInfoRequest,
  }) async {
    assert(_verifyCallable());
    var response = await jellyfinApi.submitPlaybackInfo(id: itemId, playbackInfoRequest: playbackInfoRequest);
    return PlaybackInfoResponse.fromJson(response as Map<String, dynamic>);
  }

  /// Starts an instant mix using the data from the item provided.
  Future<List<BaseItemDto>?> getInstantMix(BaseItemDto parentItem, {int? limit}) async {
    assert(_verifyCallable());
    if (GetIt.instance<SubsonicUserHelper>().hasCredentials) {
      return GetIt.instance<SubsonicApiHelper>().getInstantMix(
        parentItem.id.raw,
        count: limit ?? FinampSettingsHelper.finampSettings.trackShuffleItemCount,
      );
    }
    var response = await jellyfinApi.getInstantMix(
      id: parentItem.id,
      userId: _finampUserHelper.currentUser!.id,
      limit: limit ?? FinampSettingsHelper.finampSettings.trackShuffleItemCount,
    );

    return (QueryResult_BaseItemDto.fromJson(response as Map<String, dynamic>).items);
  }

  /// Get's similar albums based off a source album.
  Future<List<BaseItemDto>?> getSimilarAlbums(BaseItemId parentId, {int? limit}) async {
    assert(_verifyCallable());
    if (GetIt.instance<SubsonicUserHelper>().hasCredentials) {
      // Subsonic has no similar-albums API; return null so callers fall back to their own logic.
      return null;
    }
    var response = await jellyfinApi.getSimilarAlbums(
      id: parentId,
      userId: _finampUserHelper.currentUser!.id,
      limit: limit ?? FinampSettingsHelper.finampSettings.trackShuffleItemCount,
    );

    return (QueryResult_BaseItemDto.fromJson(response as Map<String, dynamic>).items);
  }

  /// Updates capabilities for this client.
  Future<void> updateCapabilities(ClientCapabilities capabilities) async {
    assert(_verifyCallable());
    await jellyfinApi.updateCapabilities(
      playableMediaTypes: capabilities.playableMediaTypes?.join(",") ?? "",
      supportedCommands: capabilities.supportedCommands?.join(",") ?? "",
      supportsMediaControl: capabilities.supportsMediaControl ?? false,
      supportsPersistentIdentifier: capabilities.supportsPersistentIdentifier ?? false,
    );
  }

  /// Updates capabilities for this client.
  Future<void> updateCapabilitiesFull(ClientCapabilities capabilities) async {
    assert(_verifyCallable());
    await jellyfinApi.updateCapabilitiesFull(capabilities);
  }

  /// Tells the Jellyfin server that playback has started
  Future<void> reportPlaybackStart(PlaybackProgressInfo playbackProgressInfo) async {
    assert(_verifyCallable());
    final response = await jellyfinApi.startPlayback(playbackProgressInfo);
    if (response.toString().isNotEmpty) {
      throw response as Object;
    }
  }

  /// Updates player progress so that Jellyfin can track what we're listening to
  Future<void> updatePlaybackProgress(PlaybackProgressInfo playbackProgressInfo) async {
    assert(_verifyCallable());
    final response = await jellyfinApi.playbackStatusUpdate(playbackProgressInfo);
    if (response.toString().isNotEmpty) {
      throw response as Object;
    }
  }

  /// Tells Jellyfin that we've stopped listening to music (called when the audio service is stopped)
  Future<void> stopPlaybackProgress(PlaybackProgressInfo playbackProgressInfo) async {
    assert(_verifyCallable());
    final response = await jellyfinApi.playbackStatusStopped(playbackProgressInfo);
    if (response.toString().isNotEmpty) {
      throw response as Object;
    }
  }

  /// Gets an item from a user's library.
  Future<BaseItemDto> getItemById(BaseItemId itemId) async {
    final sub = GetIt.instance<SubsonicApiHelper>();
    final song = await sub.getSongDto(itemId.raw);
    if (song != null) return song;
    final album = await sub.getAlbumDto(itemId);
    if (album != null) return album;
    try {
      final (artist, _) = await sub.getArtist(itemId.raw);
      return artist;
    } catch (_) {}
    try {
      final (playlist, _) = await sub.getPlaylist(itemId.raw);
      return playlist;
    } catch (_) {}
    throw Exception('Item not found in Subsonic: ${itemId.raw}');
  }

  /// Gets the user's permission for a specific playlist.
  Future<PlaylistUser> getPlaylistUser(BaseItemId playlistId) async {
    assert(_verifyCallable());
    final response = await jellyfinApi.getPlaylistUser(
      userId: _finampUserHelper.currentUser!.id,
      playlistId: playlistId,
    );

    return (PlaylistUser.fromJson(response as Map<String, dynamic>));
  }

  /// Gets all playlist users and their permissions for a specific playlist.
  /// !!! Can only be called by an admin user
  Future<PlaylistUsers> getPlaylistUsers(BaseItemId playlistId) async {
    assert(_verifyCallable());
    final response = await jellyfinApi.getPlaylistUsers(
      userId: _finampUserHelper.currentUser!.id,
      playlistId: playlistId,
    );

    return (PlaylistUsers.fromJson(response as Map<String, dynamic>));
  }

  Future<Map<BaseItemId, BaseItemDto>>? _getItemByIdBatchedFuture;
  final Set<BaseItemId> _getItemByIdBatchedRequests = {};

  /// Gets an item from a user's library, batching with other request coming in around the same time.
  Future<BaseItemDto?> getItemByIdBatched(BaseItemId itemId, [String? fields]) async {
    assert(_verifyCallable());
    fields ??=
        defaultFields; // explicitly set the default fields, if we pass `null` to [JellyfinAPI.getItems] it will **not** apply the default fields, since the argument *is* provided.
    _getItemByIdBatchedRequests.add(itemId);
    _getItemByIdBatchedFuture ??= Future.delayed(const Duration(milliseconds: 250), () async {
      _getItemByIdBatchedFuture = null;
      var ids = _getItemByIdBatchedRequests.toList();
      _getItemByIdBatchedRequests.clear();
      var items = await getItems(itemIds: ids, fields: fields) ?? [];
      return Map.fromIterable(items, key: (e) => (e as BaseItemDto).id);
    });
    return _getItemByIdBatchedFuture!.then((value) => value[itemId]);
  }

  /// Gets a Playlist
  Future<PlaylistInfo> getPlaylist(BaseItemId playlistId) async {
    assert(_verifyCallable());
    if (GetIt.instance<SubsonicUserHelper>().hasCredentials) {
      final public = await GetIt.instance<SubsonicApiHelper>().getPlaylistPublic(playlistId.raw);
      return PlaylistInfo(openAccess: public);
    }
    final response = await jellyfinApi.getPlaylist(playlistId: playlistId);
    return PlaylistInfo.fromJson(response as Map<String, dynamic>);
  }

  /// Creates a new playlist.
  Future<NewPlaylistResponse> createNewPlaylist(NewPlaylist newPlaylist) async {
    assert(_verifyCallable());
    if (GetIt.instance<SubsonicUserHelper>().hasCredentials) {
      final sub = GetIt.instance<SubsonicApiHelper>();
      final songIds = newPlaylist.ids?.map((id) => id.raw).toList() ?? [];
      final newId = await sub.createPlaylistGetId(name: newPlaylist.name, songIds: songIds);
      return NewPlaylistResponse(id: BaseItemId(newId));
    }
    final response = await jellyfinApi.createNewPlaylist(newPlaylist: newPlaylist);
    return NewPlaylistResponse.fromJson(response as Map<String, dynamic>);
  }

  /// Adds items to a playlist, expanding non-track IDs to their constituent songs.
  Future<void> addItemstoPlaylist({
    /// The playlist id.
    required BaseItemId playlistId,

    /// Item ids to add.
    List<BaseItemId>? ids,
  }) async {
    assert(_verifyCallable());
    if (GetIt.instance<SubsonicUserHelper>().hasCredentials && ids != null) {
      final sub = GetIt.instance<SubsonicApiHelper>();
      final songIds = <String>[];
      for (final id in ids) {
        final song = await sub.getSongDto(id.raw);
        if (song != null) { songIds.add(id.raw); continue; }
        bool handled = false;
        try {
          final (_, songs) = await sub.getAlbum(id.raw);
          songIds.addAll(songs.map((s) => s.id.raw));
          handled = true;
        } catch (_) {}
        if (handled) continue;
        try {
          final (_, albums) = await sub.getArtist(id.raw);
          for (final album in albums) {
            final (_, songs) = await sub.getAlbum(album.id.raw);
            songIds.addAll(songs.map((s) => s.id.raw));
          }
          handled = true;
        } catch (_) {}
        if (handled) continue;
        try {
          final (_, songs) = await sub.getPlaylist(id.raw);
          songIds.addAll(songs.map((s) => s.id.raw));
          handled = true;
        } catch (_) {}
        if (handled) continue;
        // Treat as genre (Subsonic genres use name as ID)
        try {
          final songs = await sub.getSongsByGenre(id.raw);
          songIds.addAll(songs.map((s) => s.id.raw));
        } catch (_) {}
      }
      if (songIds.isNotEmpty) {
        await sub.updatePlaylist(id: playlistId.raw, songIdsToAdd: songIds);
      }
      return;
    }
    await jellyfinApi.addItemsToPlaylist(playlistId: playlistId, ids: ids?.join(","));
  }

  /// Remove items from a playlist.
  /// For Navidrome: [entryIds] are 0-based index strings set on items by getPlaylist().
  Future<void> removeItemsFromPlaylist({
    /// The playlist id.
    required BaseItemId playlistId,

    /// Item ids to add.
    List<String>? entryIds,
  }) async {
    assert(_verifyCallable());
    if (GetIt.instance<SubsonicUserHelper>().hasCredentials && entryIds != null) {
      final indices = entryIds.map((e) => int.tryParse(e)).whereType<int>().toList();
      if (indices.isNotEmpty) {
        await GetIt.instance<SubsonicApiHelper>().updatePlaylist(
          id: playlistId.raw,
          songIndexesToRemove: indices,
        );
      }
      return;
    }
    final response = await jellyfinApi.removeItemsFromPlaylist(playlistId: playlistId, entryIds: entryIds?.join(","));
    if (response.statusCode == 403) {
      _jellyfinApiHelperLogger.warning(
        "Failed to remove items from playlist due to insufficient permissions. Status code: ${response.statusCode}",
      );
      throw "You do not have permission to remove items from this playlist. Status code: ${response.statusCode}";
    } else if (response.error != null) {
      if (response.error == "") {
        throw "An unknown error occurred while removing items from the playlist. Status code: ${response.statusCode}";
      }
      throw "${response.error}. Status code: ${response.statusCode}";
    }
  }

  /// Updates an item. (Not for Playlists: use updatePlaylist for that)
  /// You should give a BaseItemDto with only
  /// changed values.
  Future<void> updateItem({
    /// The item id.
    required BaseItemId itemId,

    /// the new Item.
    required BaseItemDto newItem,
  }) async {
    assert(_verifyCallable());
    final response = await jellyfinApi.updateItem(itemId: itemId, newItem: newItem);
    if (response.toString().isNotEmpty) {
      throw response as Object;
    }
  }

  /// Updates playlist.
  Future<void> updatePlaylist({
    /// The item id.
    required BaseItemId itemId,

    /// The new Item.
    required NewPlaylist newPlaylist,
  }) async {
    assert(_verifyCallable());
    if (GetIt.instance<SubsonicUserHelper>().hasCredentials) {
      final sub = GetIt.instance<SubsonicApiHelper>();
      if (newPlaylist.ids != null) {
        // Track-list replacement: use createPlaylist to overwrite the song list.
        await sub.replacePlaylistTracks(
          itemId.raw,
          newPlaylist.ids!.map((id) => id.raw).toList(),
        );
      } else {
        // Metadata-only update: name and/or public visibility.
        await sub.updatePlaylist(
          id: itemId.raw,
          name: newPlaylist.name,
          public: newPlaylist.isPublic,
        );
      }
      return;
    }
    final response = await jellyfinApi.updatePlaylist(playlistId: itemId, playlist: newPlaylist);
    if (response.toString().isNotEmpty) {
      throw response as Object;
    }
  }

  /// Marks an item as a favorite via Subsonic star.
  Future<UserItemDataDto> addFavorite(BaseItemId itemId) async {
    final sub = GetIt.instance<SubsonicApiHelper>();
    await sub.star(id: itemId.raw);
    final downloadsService = GetIt.instance<DownloadsService>();
    unawaited(
      downloadsService.resync(
        DownloadStub.fromFinampCollection(FinampCollection(type: FinampCollectionType.favorites)),
        null,
        keepSlow: true,
      ),
    );
    return UserItemDataDto(isFavorite: true, played: false, playCount: 0, playbackPositionTicks: 0);
  }

  /// Unmarks item as a favorite via Subsonic unstar.
  Future<UserItemDataDto> removeFavorite(BaseItemId itemId) async {
    final sub = GetIt.instance<SubsonicApiHelper>();
    await sub.unstar(id: itemId.raw);
    final downloadsService = GetIt.instance<DownloadsService>();
    unawaited(
      downloadsService.resync(
        DownloadStub.fromFinampCollection(FinampCollection(type: FinampCollectionType.favorites)),
        null,
        keepSlow: true,
      ),
    );
    return UserItemDataDto(isFavorite: false, played: false, playCount: 0, playbackPositionTicks: 0);
  }

  void addArtistToMixBuilderList(BaseItemDto item) {
    selectedMixArtists.add(item);
  }

  void removeArtistFromMixBuilderList(BaseItemDto item) {
    selectedMixArtists.remove(item);
  }

  void clearArtistMixBuilderList() {
    selectedMixArtists.clear();
  }

  void addAlbumToMixBuilderList(BaseItemDto item) {
    selectedMixAlbums.add(item);
  }

  void removeAlbumFromMixBuilderList(BaseItemDto item) {
    selectedMixAlbums.remove(item);
  }

  void clearAlbumMixBuilderList() {
    selectedMixAlbums.clear();
  }

  void addGenreToMixBuilderList(BaseItemDto item) {
    selectedMixGenres.add(item);
  }

  void removeGenreFromMixBuilderList(BaseItemDto item) {
    selectedMixGenres.remove(item);
  }

  void clearGenreMixBuilderList() {
    selectedMixGenres.clear();
  }

  Future<List<BaseItemDto>?> getArtistMix(List<BaseItemId> artistIds) async {
    assert(_verifyCallable());
    if (GetIt.instance<SubsonicUserHelper>().hasCredentials) {
      if (artistIds.isEmpty) return [];
      return GetIt.instance<SubsonicApiHelper>().getInstantMix(artistIds.first.raw);
    }
    final response = await jellyfinApi.getItems(
      userId: _finampUserHelper.currentUser!.id,
      parentId: _finampUserHelper.currentUser!.currentView?.id,
      artistIds: artistIds.join(","),
      filters: "IsNotFolder",
      recursive: true,
      sortBy: "Random",
      limit: 300,
      fields: "Chapters",
    );

    return (QueryResult_BaseItemDto.fromJson(response as Map<String, dynamic>).items);
  }

  Future<List<BaseItemDto>?> getAlbumMix(List<BaseItemId> albumIds) async {
    assert(_verifyCallable());
    if (GetIt.instance<SubsonicUserHelper>().hasCredentials) {
      if (albumIds.isEmpty) return [];
      return GetIt.instance<SubsonicApiHelper>().getInstantMix(albumIds.first.raw);
    }
    final response = await jellyfinApi.getItems(
      userId: _finampUserHelper.currentUser!.id,
      albumIds: albumIds.join(","),
      filters: "IsNotFolder",
      recursive: true,
      sortBy: "Random",
      limit: 300,
      fields: "Chapters",
    );

    return (QueryResult_BaseItemDto.fromJson(response as Map<String, dynamic>).items);
  }

  Future<List<BaseItemDto>?> getGenreMix(List<BaseItemId> genreIds) async {
    assert(_verifyCallable());
    if (GetIt.instance<SubsonicUserHelper>().hasCredentials) {
      if (genreIds.isEmpty) return [];
      final songs = await GetIt.instance<SubsonicApiHelper>().getSongsByGenre(genreIds.first.raw, count: 300);
      songs.shuffle();
      return songs;
    }
    final response = await jellyfinApi.getItems(
      userId: _finampUserHelper.currentUser!.id,
      parentId: _finampUserHelper.currentUser!.currentView?.id,
      genreIds: genreIds.join(","),
      filters: "IsNotFolder",
      recursive: true,
      sortBy: "Random",
      limit: 300,
      fields: "Chapters",
    );

    return (QueryResult_BaseItemDto.fromJson(response as Map<String, dynamic>).items);
  }

  /// Gets the lyrics for an item.
  Future<LyricDto> getLyrics({required BaseItemId itemId}) async {
    assert(_verifyCallable());
    final response = await jellyfinApi.getLyrics(itemId: itemId);

    return LyricDto.fromJson(response as Map<String, dynamic>);
  }

  /// Removes the current user from the DB and revokes the token on Jellyfin
  Future<void> logoutCurrentUser() async {
    Response<dynamic>? response;

    // We put this in a try-catch loop that basically ignores errors so that the
    // user can still log out during scenarios like wrong IP, no internet etc.

    try {
      response = await jellyfinApi
          .logout()
          // This is required for logout ontimeout method to be correct type
          .then((e) => e as Response<dynamic>?)
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              _jellyfinApiHelperLogger.warning(
                "Logout request timed out. Logging out anyway, but be aware that Jellyfin may have not got the signal.",
              );
              return null;
            },
          );
    } catch (e) {
      _jellyfinApiHelperLogger.warning(
        "Jellyfin logout failed with error $e. Logging out anyway, but be aware that Jellyfin may have not got the signal.",
        e,
      );
    } finally {
      // If the logout response wasn't successful, warn the user in the logs.
      // We continue anyway since this will mostly be for when the client becomes
      // unauthorised, which will return 401.
      if (response?.isSuccessful == false) {
        _jellyfinApiHelperLogger.warning(
          "Jellyfin logout returned ${response!.statusCode}. Logging out anyway, but be aware that Jellyfin may still consider this device logged in.",
        );
      }

      // If we're unauthorised, the logout command will fail but we're already
      // basically logged out so we shouldn't fail.
      _finampUserHelper.removeUser(_finampUserHelper.currentUser!.id);
      _jellyfinApiHelperLogger.warning("User has completed logout.");
    }
  }

  Future<bool> _pingSpecificServer(String url) async {
    final client = ChopperClient(
      baseUrl: Uri.tryParse(url),
      client: http.IOClient(HttpClient()..connectionTimeout = const Duration(seconds: 3)),
      interceptors: [jellyfin_api.JellyfinSpecificInterceptor(url), HttpAggregateLoggingInterceptor()],
      converter: JsonConverter(),
    );

    final Request $request = Request('GET', Uri.parse("/System/Endpoint"), client.baseUrl);

    try {
      Response<dynamic> response = await client.send<dynamic, dynamic>($request);
      if (response.statusCode != 200) return false;
      final body = response.bodyOrThrow as Map<String, dynamic>;
      // If IsInNetwork doesn't exist -> return false
      // because then its not a jellyfin server
      return body.containsKey("IsInNetwork");
    } catch (e) {
      Logger("Ayoo").severe(e);
      return false;
    }
  }

  Future<bool> pingLocalServer() async {
    if (GetIt.instance<SubsonicUserHelper>().hasCredentials) {
      // For Navidrome, re-use pingActiveServer which already pings the Subsonic endpoint.
      return pingActiveServer();
    }
    FinampUser? user = GetIt.instance<FinampUserHelper>().currentUser;
    if (user == null) return false;
    return await _pingSpecificServer(user.localAddress);
  }

  Future<bool> pingPublicServer() async {
    if (GetIt.instance<SubsonicUserHelper>().hasCredentials) {
      return pingActiveServer();
    }
    FinampUser? user = GetIt.instance<FinampUserHelper>().currentUser;
    if (user == null) return false;
    return await _pingSpecificServer(user.publicAddress);
  }

  Future<bool> pingActiveServer() async {
    if (GetIt.instance<SubsonicUserHelper>().hasCredentials) {
      try {
        await GetIt.instance<SubsonicApiHelper>().ping().timeout(const Duration(seconds: 3));
        return true;
      } catch (e) {
        _jellyfinApiHelperLogger.fine('pingActiveServer (Subsonic): $e');
        return false;
      }
    }
    try {
      Response<dynamic>? response = await jellyfinApi
          .pingServer()
          .then((e) => e as Response<dynamic>?)
          .timeout(Duration(seconds: 3));
      return response?.statusCode == 200;
    } catch (e) {
      _jellyfinApiHelperLogger.severe(e);
      return false;
    }
  }

  /// Returns the correct image URL for the given item, or null if there is no
  /// image. Uses [getImageId] to get the actual id. [maxWidth] and [maxHeight]
  /// can be specified to return a smaller image. [quality] can be modified to
  /// get a higher/lower quality image.
  Uri? getImageUrl({
    required BaseItemDto item,
    int? maxWidth,
    int? maxHeight,
    int? quality = 90,
    String? format = "jpg",
    bool forcePublicAddress = false,
  }) {
    if (item.imageId == null) {
      return null;
    }

    final parsedBaseUrl = forcePublicAddress
        ? Uri.parse(_finampUserHelper.currentUser!.publicAddress)
        : Uri.parse(_finampUserHelper.currentUser!.baseURL);

    List<String> builtPath = List<String>.from(parsedBaseUrl.pathSegments);
    builtPath.addAll(["Items", item.imageId!, "Images", "Primary"]);
    final Map<String, dynamic> queryParams = {
      if (format != null) "format": format,
      if (quality != null) "quality": quality.toString(),
      if (maxWidth != null) "MaxWidth": maxWidth.toString(),
      if (maxHeight != null) "MaxHeight": maxHeight.toString(),
    };
    return Uri(
      host: parsedBaseUrl.host,
      port: parsedBaseUrl.port,
      scheme: parsedBaseUrl.scheme,
      userInfo: parsedBaseUrl.userInfo,
      pathSegments: builtPath,
      // don't pass an empty map, otherwise .toString() will append just the `?` at the end, which is unusual
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
  }

  Uri? getUserImageUrl({
    required Uri baseUrl,
    required UserDto user,
    int? maxWidth,
    int? maxHeight,
    int? quality = 90,
    String? format = "jpg",
  }) {
    if (user.primaryImageTag == null) {
      return null;
    }

    List<String> builtPath = List<String>.from(baseUrl.pathSegments);
    builtPath.addAll(["Users", user.id, "Images", "Primary"]);
    return Uri(
      host: baseUrl.host,
      port: baseUrl.port,
      scheme: baseUrl.scheme,
      userInfo: baseUrl.userInfo,
      pathSegments: builtPath,
      queryParameters: {
        if (format != null) "format": format,
        if (quality != null) "quality": quality.toString(),
        if (maxWidth != null) "MaxWidth": maxWidth.toString(),
        if (maxHeight != null) "MaxHeight": maxHeight.toString(),
      },
    );
  }

  /// Returns the correct URL for the given item.
  Uri getTrackDownloadUrl({required BaseItemDto item, required DownloadProfile? transcodingProfile}) {
    Uri uri = Uri.parse(_finampUserHelper.currentUser!.baseURL);

    if (transcodingProfile != null && transcodingProfile.codec != FinampTranscodingCodec.original) {
      // uri.queryParameters is unmodifiable, so we copy the contents into a new
      // map
      final queryParameters = Map.of(uri.queryParameters);

      // iOS/macOS doesn't support OPUS (except in CAF, which doesn't work from
      // Jellyfin). Once https://github.com/jellyfin/jellyfin/pull/9192 lands,
      // we could use M4A/AAC.

      assert(
        transcodingProfile.codec.container != null,
        "Missing container for codec while trying to download transcoded track!",
      );

      queryParameters.addAll({
        "transcodingContainer": transcodingProfile.codec.container!,
        "audioCodec": transcodingProfile.codec.name,
        "audioBitRate": transcodingProfile.stereoBitrate.toString(),
      });

      if (FinampSettingsHelper.finampSettings.multichannelHandlingSetting ==
              MultichannelHandlingSetting.stereoDownmixAll ||
          (FinampSettingsHelper.finampSettings.multichannelHandlingSetting ==
                  MultichannelHandlingSetting.stereoDownmixLossy &&
              FinampSettingsHelper.finampSettings.transcodingStreamingFormat.codec != "flac")) {
        queryParameters.addAll({"maxAudioChannels": "2"});
      }

      uri = uri.replace(
        pathSegments: uri.pathSegments.followedBy(["Audio", item.id.raw, "Universal"]),
        queryParameters: queryParameters,
      );
    } else {
      uri = uri.replace(pathSegments: uri.pathSegments.followedBy(["Items", item.id.raw, "File"]));
    }

    return uri;
  }

  /// Sets a new primary image for an item.
  /// !!! since images are considered metadata, this can only be done by administrators.
  Future<void> setItemPrimaryImage({required BaseItemId itemId, required File imageFile}) async {
    assert(_verifyCallable());
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    // Infer mime type from extension (fallback jpeg)
    final lower = imageFile.path.toLowerCase();
    ContentType contentType;
    if (lower.endsWith('.png')) {
      contentType = ContentType('image', 'png');
    } else if (lower.endsWith('.webp')) {
      contentType = ContentType('image', 'webp');
    } else if (lower.endsWith('.gif')) {
      contentType = ContentType('image', 'gif');
    } else if (lower.endsWith('.bmp')) {
      contentType = ContentType('image', 'bmp');
    } else if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      contentType = ContentType('image', 'heic');
    } else {
      contentType = ContentType('image', 'jpeg');
    }
    final response = await jellyfinApi.setItemPrimaryImage(
      itemId: itemId,
      base64Image: base64Image,
      contentType: contentType.mimeType,
    );
    if (!response.isSuccessful) {
      throw response as Object;
    }
  }

  /// Verify that we are in an appropriate location to make API calls.
  /// This should only be called inside assert() to prevent running in release mode.
  bool _verifyCallable() {
    if (FinampSettingsHelper.finampSettings.isOffline) {
      return false;
    }
    // Verify that all calls to jellyfin occur either in background async calls,
    // initState methods, or providers.
    if ([
      SchedulerPhase.idle,
      SchedulerPhase.postFrameCallbacks,
      SchedulerPhase.midFrameMicrotasks,
    ].contains(SchedulerBinding.instance.schedulerPhase)) {
      return true;
    }
    var stack = StackTrace.current.toString();
    if (stack.contains('ProviderElementBase.buildState') ||
        stack.contains('initState ') ||
        stack.contains('didUpdateWidget') ||
        stack.contains('new QueueService') ||
        stack.contains('PagingController.notifyPageRequestListeners')) {
      return true;
    }
    _jellyfinApiHelperLogger.warning("_verifyCallable failed in phase ${SchedulerBinding.instance.schedulerPhase}");
    return false;
  }
}
