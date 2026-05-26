# Naviamp — Claude Instructions

## What this project is

Naviamp is a fork of [Finamp](https://github.com/jmshrv/finamp) that replaces the Jellyfin music server backend with [Navidrome](https://www.navidrome.org/) (OpenSubsonic API). The UI is kept identical to upstream Finamp so front-end improvements can be cherry-picked with minimal conflicts.

**Active development branch:** `redesign` (not `main` — always work here)

See `PROJECT_GOALS.md` for the full phase-by-phase implementation plan and API mapping tables.

---

## Dev environment

Source this script at the start of every session before running any Flutter or Android commands:

```sh
source dev-env.sh
```

This sets `JAVA_HOME`, `ANDROID_HOME`, and `PATH` without permanently changing the shell.

Use `./flutterw` (not `flutter`) for all Flutter commands — it targets the pinned `.flutter` submodule:

```sh
./flutterw pub get
./flutterw pub run build_runner build --delete-conflicting-outputs
./flutterw build apk --debug
```

After editing any file with `@JsonSerializable` or `@ChopperApi` annotations, regenerate code:

```sh
./flutterw pub run build_runner build --delete-conflicting-outputs
```

---

## Architecture

### Layer rules

| Layer | Rule |
|---|---|
| `lib/components/` and `lib/screens/` | **Do not modify** (upstream UI parity). Exception: login screens that are Jellyfin-specific have already been replaced. |
| `lib/models/jellyfin_models.dart` | **Keep intact** — the UI uses these types (`BaseItemDto`, etc.). |
| `lib/services/subsonic_*.dart` | Navidrome backend — primary development target. |
| `lib/services/jellyfin_api_helper.dart` | Acts as a Subsonic proxy — `getItems`, `getItemById`, `addFavorite`, `removeFavorite` all dispatch to `SubsonicApiHelper`. `runInIsolate()` still used by downloads. |

### State management / DI

- **Riverpod** — UI state. `providerDidFail` in `main.dart` surfaces any provider exception as a `GlobalSnackbar.error`, so provider failures are always user-visible. Avoid throwing from providers for expected missing-item cases.
- **get_it** — service locator (singletons injected at startup in `lib/main.dart`)
- **Isar** — local database
- **Chopper 8.5.1** — generated HTTP client

### Subsonic service layer

Three files implement the Navidrome backend:

| File | Purpose |
|---|---|
| `lib/services/subsonic_api.dart` | Chopper `@ChopperApi` definitions + `SubsonicAuth` + `SubsonicInterceptor` |
| `lib/services/subsonic_user_helper.dart` | In-memory session (server URL + credentials); reads/writes Isar |
| `lib/services/subsonic_api_helper.dart` | High-level helper — all business logic; returns `BaseItemDto` to callers |

---

## Critical Chopper pattern — read this before touching API code

Chopper 8.5.1 generates methods that call `return $response.bodyOrThrow`. This means every `_api.someMethod()` call returns **the parsed body** (`Map<String, dynamic>`) — NOT a `Response<dynamic>` wrapper object.

**Never cast a Chopper API return value to `Response`. It will always throw a `TypeError`.**

The correct pattern used throughout `subsonic_api_helper.dart`:

```dart
// All _api.* calls return the body Map directly.
Map<String, dynamic> _unwrap(dynamic body) {
  return SubsonicEnvelope.unwrap(body as Map<String, dynamic>);
}

// Usage:
final inner = _unwrap(await _api.getArtists());
```

`bodyOrThrow` already throws `ChopperHttpException` for non-2xx HTTP responses, so there is no need for an `isSuccessful` check before `_unwrap`.

### probeServer exception

`subsonic_api_helper.dart:probeServer()` deliberately bypasses Chopper and uses `package:http` directly. This is because Chopper's `JsonConverter.responseFactory` pipeline fails for unauthenticated pings (exact cause unknown). This is documented as a TODO in `PROJECT_GOALS.md`. Do not attempt to move `probeServer` back to Chopper without first diagnosing this.

---

## Key patterns in jellyfin_api_helper.dart

### `_subsonicFetch` — central Subsonic dispatch

`getItems()` and `getItemsWithTotalRecordCount()` both delegate to `_subsonicFetch()`. It dispatches on 8 cases in order:

1. **itemIds batch** — resolves a list of IDs via `getSongDto` (used by queue restore)
2. **searchTerm** — calls `search3()`; filters result by `includeItemTypes`
3. **Playlist parent** — calls `getPlaylist()`
4. **MusicArtist parent** — calls `getArtist()`; returns albums or expands to tracks
5. **MusicAlbum parent** — calls `getAlbum()` for track list
6. **genreFilter** — calls `getAlbumList2(byGenre)` or `getSongsByGenre()`
7. **isFavorite** — calls `getStarred()`
8. **Top-level by type** — MusicArtist→`getArtists`, MusicAlbum→`getAlbumList2`, Audio→`getRandomSongs`, MusicGenre→`getGenres`, Playlist→`getPlaylists`

### `_subsonicSort` — client-side sort

Called after fetching lists that Subsonic can't sort server-side (artists, genres, playlists, artist album children). Takes the **first comma-separated key** from the Jellyfin sort string and maps it:

| First key | Sort behaviour |
|---|---|
| `Random` | shuffle |
| `ParentIndexNumber` or `IndexNumber` | disc → track → name (for album tracks) |
| `PremiereDate` or `ProductionYear` | `productionYear` → name (for artist discography order) |
| anything else | `sortName` → `name` (alphabetical) |

### `getItemById` fallback chain

Tries in order: `getSongDto` → `getAlbumDto` → `getArtist`. All three are wrapped in null/catch so the method only throws when all three fail. `SubsonicException(70)` (not found) is demoted to FINE-level logging in `getSongDto` and `getAlbumDto` because it is expected when the ID is an artist.

---

## Known gaps (as of latest commit)

### Remaining Jellyfin remnants

- `lib/screens/playlist_edit_screen.dart` — playlist editing still via Jellyfin
- `lib/components/AddToPlaylistScreen/` — playlist creation/listing still via Jellyfin
- `lib/screens/network_settings_screen.dart` — pings Jellyfin server URL (non-functional / harmless)
- `lib/services/PlayOnService` — silenced for Navidrome (returns early when Subsonic credentials are present), but the Jellyfin WebSocket code is still there

### Phase 6 branding (not started)

- App name `finamp` → `naviamp`
- Package ID `com.unicornsonlsd.finamp` → `com.naviamp.naviamp`
- Icons and splash screen

---

## Model classes

`lib/models/subsonic_models.dart` — all `@JsonSerializable` classes must have **both** a `fromJson` factory AND a `toJson()` instance method:

```dart
@JsonSerializable()
class SubsonicFoo {
  factory SubsonicFoo.fromJson(Map<String, dynamic> json) => _$SubsonicFooFromJson(json);
  Map<String, dynamic> toJson() => _$SubsonicFooToJson(this);
}
```

Parent classes that override: use `@override`. This is required because parent classes use `explicitToJson: true`.

### OpenSubsonic field type mismatches

Navidrome sends some OpenSubsonic extension fields with unexpected JSON types. Use `@JsonKey(includeFromJson: false, includeToJson: false)` to ignore fields where the Navidrome type doesn't match the Dart type and the field isn't used in `BaseItemDto` mapping. Current examples in `SubsonicAlbumID3`: `originalReleaseDate`, `releaseDate`, `releaseTypes`.

### Queue persistence

`FinampStorableQueueInfo.packIds` / `_unpackIds` use a **4-byte length-prefix + UTF-8** format (not the old 16-byte hex UUID format). Any Navidrome alphanumeric ID is stored correctly. Old hex-format queues saved before this change decode as empty lists.

---

## Android testing

```sh
source dev-env.sh
./flutterw build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# Launch (debug package gets a .debug suffix):
adb shell monkey -p com.unicornsonlsd.finamp.debug -c android.intent.category.LAUNCHER 1

# Stream logs (warnings/errors only):
adb logcat --pid=$(adb shell pidof -s com.unicornsonlsd.finamp.debug) | grep -E "WARNING|SEVERE|ERROR"
```

The device runs the app over Tailscale to a local Navidrome instance (HTTP, not HTTPS). Cleartext HTTP is already enabled in `android/app/src/main/AndroidManifest.xml` and `network_security_config.xml`.

---

## What to do and not do

- **Do** route all Navidrome data through `SubsonicApiHelper` — it returns `BaseItemDto` which is what the UI expects.
- **Do not** add Jellyfin API calls for new features — even if a Jellyfin API method exists, use Subsonic.
- **Do not** modify UI widget files in `lib/components/` or `lib/screens/` unless absolutely required — keep them upstream-compatible.
- **Do not** use `Response<dynamic>` anywhere in Subsonic code — Chopper returns the body, not the wrapper.
- **Do** run `build_runner` after any annotation change before building.
- **Do not** throw from Riverpod providers for expected missing-item cases — use null returns or fallbacks. Unhandled provider exceptions surface as snackbar errors via `providerDidFail` in `main.dart`.
