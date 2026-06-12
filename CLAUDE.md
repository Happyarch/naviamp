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

After editing any file with `@JsonSerializable`, `@ChopperApi`, or `@riverpod` annotations, regenerate code:

```sh
./flutterw pub run build_runner build --delete-conflicting-outputs
```

---

## Architecture

### Layer rules

| Layer | Rule |
|---|---|
| `lib/components/` and `lib/screens/` | **Do not modify** (upstream UI parity). Exceptions already made: login screens replaced; Jellyfin-only tiles removed from `settings_screen.dart`; Jellyfin-only widgets hidden in `playback_reporting_settings_screen.dart`; `artist_type_selection_row.dart` converted to `ConsumerWidget` to gate on plugin state. |
| `lib/models/jellyfin_models.dart` | **Keep intact** — the UI uses these types (`BaseItemDto`, etc.). |
| `lib/services/subsonic_*.dart` | Navidrome backend — primary development target. |
| `lib/services/jellyfin_api_helper.dart` | Acts as a Subsonic proxy — `getItems`, `getItemById`, `addFavorite`, `removeFavorite` all dispatch to `SubsonicApiHelper`. `runInIsolate()` still used by downloads. |

### State management / DI

- **Riverpod** — UI state. `providerDidFail` in `main.dart` surfaces any provider exception as a `GlobalSnackbar.error`, so provider failures are always user-visible. Avoid throwing from providers for expected missing-item cases.
- **get_it** — service locator (singletons injected at startup in `lib/main.dart`)
- **Isar** — local database
- **Chopper 8.5.1** — generated HTTP client

### Subsonic service layer

| File | Purpose |
|---|---|
| `lib/services/subsonic_api.dart` | Chopper `@ChopperApi` definitions + `SubsonicAuth` + `SubsonicInterceptor` |
| `lib/services/subsonic_user_helper.dart` | In-memory session (server URL + credentials); reads/writes Isar |
| `lib/services/subsonic_api_helper.dart` | High-level helper — all business logic; returns `BaseItemDto` to callers |
| `lib/services/naviamp_plugin_state.dart` | `NaviampPluginState` sealed class + Riverpod `keepAlive` provider |
| `lib/services/naviamp_plugin_helper.dart` | `NaviampPluginHelper.probe()` (HTTP/HTTPS capability probe) + `runNaviampPluginProbe()` |

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

- `lib/services/PlayOnService` — silenced for Navidrome (returns early when Subsonic credentials are present), but the Jellyfin WebSocket code is still there

### Phase 6 branding (code renames done — some assets pending)

- Package ID renamed: `com.unicornsonlsd.finamp` → `com.naviamp.naviamp` (build.gradle, plist, xcodeproj, Kotlin sources)
- App label renamed: `Finamp` → `Naviamp` (Android `app_name`, iOS `CFBundleDisplayName`)
- Dart package name `name: finamp` left as-is (1254 upstream imports; see PROJECT_GOALS.md)
- English UI strings (`lib/l10n/app_en.arb`) fully rebranded — Finamp→Naviamp, Jellyfin→Navidrome throughout
- Quick Connect and Share Server buttons removed from `settings_screen.dart` (no Navidrome equivalents)
- Android adaptive icon foreground updated: `drawable-v24/ic_launcher_foreground.xml` (Finamp vector) deleted; `drawable/ic_launcher_foreground.png` manually created from `assets/icon/icon_foreground.png`
- Splash screen, in-app SVG/PNG logos (`images/finamp_cropped.svg`, Discord RPC images) still use Finamp artwork — see PROJECT_GOALS.md Phase 6 asset table

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

### `childCount` must mirror `songCount` in DTO mappers

Several UI components (e.g. `generate_subtitle.dart` for playlists, `item_info.dart` for offline album track counts) use `item.childCount!` and will crash if it is null. Always set `childCount: <songCount>` alongside `songCount` in `_albumToDto` and `_playlistToDto`.

### Queue persistence

`FinampStorableQueueInfo.packIds` / `_unpackIds` use a **4-byte length-prefix + UTF-8** format (not the old 16-byte hex UUID format). Any Navidrome alphanumeric ID is stored correctly. Old hex-format queues saved before this change decode as empty lists.

`FinampStorableQueueInfo.trackCount` uses `_countIds()` (a length-prefix walker) — never `~/ 16` (old hex assumption). `_unpackIntList` uses `trackCount` to size its bit-buffer read; a wrong count causes an assertion crash.

### Subsonic transcode validation on download

`downloads_service.dart` validates audio downloads on completion:

1. **Format check** (`_isExpectedAudioMime`): compares `event.mimeType` from the HTTP response against the expected MIME type for the requested codec (`opus`→`audio/ogg`/`audio/opus`/`audio/x-ogg`, `vorbis`→`audio/ogg`, `aac`→`audio/aac`/`audio/mp4`, `mp3`→`audio/mpeg`). Note: `opus` sends `format=opus` to Navidrome (`.opus` file); `vorbis` sends `format=ogg` (`.ogg` file). If Navidrome has no FFmpeg profile for the requested format, it falls back to serving the original file — wrong extension, wrong codec, possibly unplayable. Mismatch triggers a WARNING log and a snackbar.

2. **Bitrate correction**: estimates actual bitrate as `(fileSizeBytes * 8) / durationSecs`. If >20% below the requested `stereoBitrate` (server capped it silently), updates `fileTranscodingProfile.stereoBitrate` so the downloads UI shows the real bitrate rather than the requested one.

### Playlist mutation via Subsonic

Subsonic playlist mutation is index-based (remove by 0-based position) rather than entry-ID-based (Jellyfin). The bridge:

- `SubsonicApiHelper.getPlaylist()` stores each song's 0-based position as `playlistItemId` (e.g., `"0"`, `"1"`, `"2"`). The UI reads this field when it needs to remove a specific song.
- `JellyfinApiHelper.removeItemsFromPlaylist()` parses those strings back to `int` and calls `SubsonicApiHelper.updatePlaylist(songIndexesToRemove: [...])`.
- `JellyfinApiHelper.updatePlaylist()` with `newPlaylist.ids != null` calls `SubsonicApiHelper.replacePlaylistTracks()`, which uses `createPlaylist(playlistId: id, songId: [...])` to atomically replace the track list; empty list falls back to index-based removal of all songs.
- `JellyfinApiHelper.addItemstoPlaylist()` expands non-song IDs (album, artist, playlist, genre) to song IDs before calling `updatePlaylist(songIdToAdd)`.

### `serverMissingBlurhash` is suppressed for Navidrome

`downloads_service.dart` now guards the `serverMissingBlurhash = true` assignment with a check for Subsonic credentials. Without this guard the downloads tab always shows "Jellyfin server misconfigured" because Navidrome never provides blurhashes.

---

## Naviamp plugin infrastructure

The app supports an optional Go sidecar ("Naviamp plugin") that adds capabilities not in the standard OpenSubsonic API. All plugin-dependent code paths are gated by reading a Riverpod state provider — no network I/O happens per request.

### Deployment topology

The sidecar runs on a separate port (default `:8090`) but is exposed to clients at the **same base URL as Navidrome** via a reverse proxy. The expected Caddy config routes `/naviamp*` to the sidecar and everything else to Navidrome:

```
:4533 {
    handle /naviamp* {
        reverse_proxy naviamp-sidecar:8090
    }
    handle /* {
        reverse_proxy navidrome:4533
    }
}
```

The client probes `<serverUrl>/naviamp/capabilities` — this hits the reverse proxy port (4533), which routes it to the sidecar. **No separate sidecar URL is stored.** If the probe fails (no reverse proxy, sidecar not running), the app silently falls back to standard Subsonic behaviour.

### State machine

`lib/services/naviamp_plugin_state.dart` defines a sealed class:

```
NaviampPluginDisabled  — user disabled extended features in settings
NaviampPluginUnknown   — probe not yet run (startup, or setting just re-enabled)
NaviampPluginAbsent    — probe ran, plugin not found on server
NaviampPluginPresent   — probe ran, plugin confirmed; holds version + Set<String> features
```

The state is held in a Riverpod `@Riverpod(keepAlive: true)` provider (`naviampPluginProvider`). **Call sites always read this provider synchronously — never make a network call to check plugin presence.**

### Probe lifecycle

`runNaviampPluginProbe()` in `lib/services/naviamp_plugin_helper.dart`:
- Fires at startup (after `loadIfSaved()` in `main.dart`) and after login
- Pre-seeds provider from cached `FinampUser.naviampPluginLastDetected/Version` fields so the last-known state is available immediately
- Makes `GET <serverUrl>/naviamp/capabilities` with Subsonic auth params; 5-second timeout; supports both HTTP and HTTPS
- Sets provider → `Present` or `Absent`; persists result to Isar cache
- Manual re-probe available from `NaviampServerSettingsScreen` ("Re-check" button)

### Call site pattern

```dart
final pluginState = ref.read(naviampPluginProvider);
if (pluginState is NaviampPluginPresent && pluginState.supports("performing-artists")) {
  // plugin path
} else {
  // standard Subsonic fallback
}
```

Feature strings currently defined: `"delta-sync"`, `"performing-artists"`.

### Settings model fields

`FinampUser` HiveFields 0–5, 7–12 used (field 6 is intentionally skipped — do not reuse it):
- Field 11: `bool naviampPluginLastDetected` (cached probe result)
- Field 12: `String? naviampPluginLastVersion` (cached version string)

`FinampSettings` HiveField 148: `bool enableNaviampPlugin` (global client toggle; default `true`).

---

## Android testing

```sh
source dev-env.sh
./flutterw build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# Launch (debug package gets a .debug suffix):
adb shell monkey -p com.naviamp.naviamp.debug -c android.intent.category.LAUNCHER 1

# Stream logs (warnings/errors only):
adb logcat --pid=$(adb shell pidof -s com.naviamp.naviamp.debug) | grep -E "WARNING|SEVERE|ERROR"
```

Cleartext HTTP is intentionally enabled in `android/app/src/main/AndroidManifest.xml` and `network_security_config.xml`. Many users run Navidrome on a local network or tunnel through a trusted VPN (Tailscale, ZeroTier) where transport encryption is handled at the network layer. HTTPS is recommended for open WAN deployments but is the user's responsibility — the app accepts whatever URL the user types and does not enforce a scheme.

---

## What to do and not do

- **Do** route all Navidrome data through `SubsonicApiHelper` — it returns `BaseItemDto` which is what the UI expects.
- **Do not** add Jellyfin API calls for new features — even if a Jellyfin API method exists, use Subsonic.
- **Do not** modify UI widget files in `lib/components/` or `lib/screens/` unless absolutely required — keep them upstream-compatible.
- **Do not** use `Response<dynamic>` anywhere in Subsonic code — Chopper returns the body, not the wrapper.
- **Do** run `build_runner` after any annotation change before building.
- **Do not** throw from Riverpod providers for expected missing-item cases — use null returns or fallbacks. Unhandled provider exceptions surface as snackbar errors via `providerDidFail` in `main.dart`.
