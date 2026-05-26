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
| `lib/services/jellyfin_api_helper.dart` | Legacy Jellyfin layer. Retained for `runInIsolate()` only. Many browsing methods still call it (known gap — see below). |

### State management / DI

- **Riverpod** — UI state
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

## Known gaps (as of latest commit)

### Music browsing layer — Jellyfin still used

`lib/components/MusicScreen/music_screen_tab_view.dart` and these provider files still call `JellyfinApiHelper.getItems()` against the server:

- `lib/services/album_screen_provider.dart`
- `lib/services/artist_content_provider.dart`
- `lib/services/genre_screen_provider.dart`
- `lib/services/item_amount_provider.dart`
- `lib/services/favorite_provider.dart`

These will fail against a Navidrome server. The app can log in, view music folders, play (if a queue is loaded), and download — but browsing the library (artists / albums / songs / genres tabs) is non-functional.

**The fix:** replace the `JellyfinApiHelper.getItems()` calls in each provider with the appropriate `SubsonicApiHelper` methods (`getArtists`, `getAlbumList2`, `getGenres`, `search3`, `getStarred`, etc.).

### Other Jellyfin remnants

- `lib/screens/playlist_edit_screen.dart` — uses `JellyfinApiHelper` for playlist edits
- `lib/components/AddToPlaylistScreen/` — playlist creation/listing via Jellyfin
- `lib/components/PlayerScreen/artist_chip.dart`, `album_chip.dart`, `genre_chip.dart` — item lookups via Jellyfin
- `lib/services/favorite_provider.dart` — star/unstar via Jellyfin
- `lib/screens/network_settings_screen.dart` — pings Jellyfin server

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

---

## Android testing

```sh
source dev-env.sh
./flutterw build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# Launch (debug package gets a .debug suffix):
adb shell monkey -p com.unicornsonlsd.finamp.debug -c android.intent.category.LAUNCHER 1

# Stream logs:
adb logcat --pid=$(adb shell pidof -s com.unicornsonlsd.finamp.debug)
```

The device runs the app over Tailscale. Navidrome is at `http://100.121.132.84:4533` (HTTP, not HTTPS). Cleartext HTTP is already enabled in `android/app/src/main/AndroidManifest.xml` and `network_security_config.xml`.

---

## What to do and not do

- **Do** route all Navidrome data through `SubsonicApiHelper` — it returns `BaseItemDto` which is what the UI expects.
- **Do not** add Jellyfin API calls for new features — even if a Jellyfin API method exists, use Subsonic.
- **Do not** modify UI widget files in `lib/components/` or `lib/screens/` unless absolutely required — keep them upstream-compatible.
- **Do not** use `Response<dynamic>` anywhere in Subsonic code — Chopper returns the body, not the wrapper.
- **Do** run `build_runner` after any annotation change before building.
