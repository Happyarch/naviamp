# Naviamp Project Goals

Naviamp is a fork of [Finamp](https://github.com/jmshrv/finamp) that replaces the Jellyfin backend with Navidrome (OpenSubsonic API). The UI is kept as close to upstream Finamp as possible so that front-end changes can be pulled from upstream with minimal conflict. The backends are completely different; the frontends are nearly identical.

**Active branch:** `redesign` (most up-to-date Finamp code — do not use `main` for development)

---

## Core Philosophy

| Layer | Strategy |
|---|---|
| **UI / widgets** | Leave untouched except branding. Copy upstream changes freely. |
| **Data models (UI-facing)** | Keep the same types the UI uses (`BaseItemDto`, etc.) so upstream UI PRs apply cleanly. |
| **Service layer** | Full replacement — Jellyfin API → Navidrome/OpenSubsonic API. |
| **App settings / downloads** | `finamp_models.dart` largely intact; strip Jellyfin-specific fields over time. |

---

## Dev Environment Setup

Source `dev-env.sh` in the project root at the start of each session:
```sh
source dev-env.sh
```
Sets `JAVA_HOME`, `ANDROID_HOME`, and PATH without permanently modifying the shell.

### One-time setup

1. **Flutter submodule** — already initialized via `git submodule update --init .flutter`. Use `./flutterw` for all Flutter commands.

2. **JDK 17** — already installed. The `dev-env.sh` script points `JAVA_HOME` at it.

3. **Android SDK** — install to `~/Android/Sdk` (see Android SDK Setup section below).

4. **Rust** — required by `flutter_discord_rpc`:
   ```sh
   sudo pacman -S rustup && rustup default stable
   ```

5. **Get dependencies and generate code:**
   ```sh
   source dev-env.sh
   ./flutterw pub get
   ./flutterw pub run build_runner build --delete-conflicting-outputs
   ```

6. **Verify:**
   ```sh
   ./flutterw doctor
   ```
   Android toolchain should be green. iOS/Xcode and Chrome will be red — that is fine.

### Android SDK Setup

Install Google's commandline tools to `~/Android/Sdk`. The directory must look exactly like this when done:

```
~/Android/Sdk/
├── cmdline-tools/
│   └── latest/              ← must be named "latest"
│       ├── bin/
│       │   ├── sdkmanager
│       │   └── avdmanager
│       └── lib/
├── platform-tools/          ← created by sdkmanager
│   └── adb
├── build-tools/             ← created by sdkmanager
│   └── 36.0.0/
└── platforms/               ← created by sdkmanager
    ├── android-35/
    └── android-36/
```

Steps:
```sh
mkdir -p ~/Android/Sdk/cmdline-tools

# Download commandline-tools-linux-*.zip from https://developer.android.com/studio#command-line-tools-only
# The zip contains a folder called cmdline-tools/ — rename it to "latest":
unzip ~/Downloads/commandlinetools-linux-*.zip -d /tmp/android-tools
mkdir -p ~/Android/Sdk/cmdline-tools/latest
mv /tmp/android-tools/cmdline-tools/* ~/Android/Sdk/cmdline-tools/latest/

# Install SDK components
source dev-env.sh
sdkmanager --licenses
sdkmanager "platform-tools" "build-tools;36.0.0" "platforms;android-35" "platforms;android-36"
```

---

## Codebase Overview

| Layer | Files | Status |
|---|---|---|
| Subsonic models | `lib/models/subsonic_models.dart` + `.g.dart` | ✅ Done |
| Subsonic API client | `lib/services/subsonic_api.dart` + `.chopper.dart` | ✅ Done |
| Subsonic user/session | `lib/services/subsonic_user_helper.dart` | ✅ Done |
| Subsonic API helper | `lib/services/subsonic_api_helper.dart` | ✅ Done |
| Login flow | `lib/components/LoginScreen/` | ✅ Done (Phase 4) |
| Jellyfin API client | `lib/services/jellyfin_api.dart` + `jellyfin_api_helper.dart` | To replace (Phase 5) |
| User/auth model | `lib/models/finamp_models.dart` (`FinampUser`) | Partially done — `subsonicPassword` added |
| Metadata provider | `lib/services/metadata_provider.dart` | Phase 5 |
| Playback | `lib/services/music_player_background_task.dart` | Phase 5 |
| Downloads | `lib/services/downloads_service.dart` | Phase 5 |
| UI | `lib/components/`, `lib/screens/` | Leave alone |

State management: **Riverpod**. DI: **get_it**. DB: **Isar**. HTTP: **Chopper**.

---

## Jellyfin → Navidrome API Mapping

### Authentication

| Jellyfin | Navidrome |
|---|---|
| `POST /Users/AuthenticateByName` | Query params on every request: `u`, `t=md5(password+salt)`, `s=salt` |
| `MediaBrowser ...` auth header | No header — credentials in every request's query string |
| Access token stored in `FinampUser.accessToken` | Password stored in `FinampUser.subsonicPassword`; token computed per-request |
| QuickConnect | **Not available** — removed from UI |

### Browse

| Jellyfin | Navidrome | Notes |
|---|---|---|
| `GET /Artists/AlbumArtists` | `getArtists` | Navidrome returns index-grouped list |
| `GET /Users/{id}/Items` (albums) | `getArtist(id)` or `getAlbumList2` | Different filter model |
| `GET /Users/{id}/Items` (songs) | `getAlbum(id)` → songs field | Songs live inside album response |
| `GET /Users/{id}/Items?SearchTerm=` | `search3(query)` | Returns artists+albums+songs together |
| `GET /Users/{id}/Items/Latest` | `getAlbumList2(type=newest)` | — |
| `GET /Genres` | `getGenres` | — |
| `GET /Users/{id}/Views` | `getMusicFolders` | Navidrome concept of libraries |

### Streaming & Playback

| Jellyfin | Navidrome | Notes |
|---|---|---|
| `POST /Items/{id}/PlaybackInfo` | **None** | No negotiation step; codec info in song metadata |
| `/Audio/{id}/Universal?audioCodec=...&audioBitRate=...` | `/rest/stream.view?id=...&maxBitRate=...&format=...` | Simpler — client requests bitrate/format directly |
| `/Items/{id}/File` | `/rest/download.view?id=...` | Direct file download |

`PlaybackInfoResponse` / `MediaSourceInfo` / `MediaStream` — these Jellyfin types are used in `MetadataProvider` and the player. We will synthesize them from Navidrome song metadata so that the player code stays unchanged.

### Playback Reporting

| Jellyfin | Navidrome |
|---|---|
| `POST /Sessions/Playing` (start) | `scrobble?id=...&submission=false` (now playing) |
| `POST /Sessions/Playing/Progress` | (same scrobble call, periodic) |
| `POST /Sessions/Playing/Stopped` | `scrobble?id=...&submission=true&time=...` |

### Artwork

| Jellyfin | Navidrome |
|---|---|
| `/Items/{id}/Images/Primary` | `/rest/getCoverArt.view?id=...&size=...` |

Cover art IDs are stored in `BaseItemDto.imageTags['Primary']` for Subsonic items.

### Lyrics

| Jellyfin | Navidrome |
|---|---|
| `GET /Audio/{itemId}/Lyrics` | `getLyricsBySongId?id=...` (OpenSubsonic structured) |

Navidrome supports the OpenSubsonic `getLyricsBySongId` extension which returns synced/multi-language lyrics by song ID.

### Favorites

| Jellyfin | Navidrome |
|---|---|
| `POST /Users/{userId}/FavoriteItems/{itemId}` | `star?id=...` |
| `DELETE /Users/{userId}/FavoriteItems/{itemId}` | `unstar?id=...` |
| `getItems(isFavorite=true)` | `getStarred2` |

### Playlists

Functionally equivalent: `getPlaylists`, `getPlaylist(id)`, `createPlaylist`, `updatePlaylist`, `deletePlaylist`.

### Similar / Radio

| Jellyfin | Navidrome | Notes |
|---|---|---|
| `GET /Items/{id}/InstantMix` | `getInstantMix(id)` | OpenSubsonic "Sonic Similarity" extension |
| `GET /Albums/{id}/Similar` | `getSimilarSongs2(id)` | Song-level only in Subsonic |

---

## Implementation Phases

### Phase 0 — Dev Environment ✅ Complete

| Task | Status |
|---|---|
| Initialize `.flutter` submodule — Flutter 3.44.0 / Dart 3.12.0 | ✅ |
| Install Android SDK (build-tools 36.0.0, android-35/36, NDK 28.2, CMake 3.22) | ✅ |
| Install Rust via `rustup` (required by `flutter_discord_rpc`) | ✅ |
| `./flutterw doctor` — Android toolchain green | ✅ |
| `pub get` + `build_runner build` succeed | ✅ |
| `./flutterw build apk --debug` succeeds | ✅ |

### Phase 1 — Navidrome Models ✅ Complete

`lib/models/subsonic_models.dart` + generated `.g.dart`

| Task | Status |
|---|---|
| `SubsonicEnvelope.unwrap()` — parses and validates `subsonic-response` envelope | ✅ |
| `SubsonicException` — error codes (auth, not-found, missing-params) | ✅ |
| `SubsonicChild`, `SubsonicArtistID3`, `SubsonicAlbumID3` — full OpenSubsonic fields | ✅ |
| `SubsonicPlaylist` / `SubsonicPlaylistWithSongs`, `SubsonicSearchResult3`, `SubsonicStarred2` | ✅ |
| `SubsonicStructuredLyrics` / `SubsonicLyricsList` — OpenSubsonic synced lyrics | ✅ |
| `SubsonicServerInfo` — server version/type from ping envelope | ✅ |

### Phase 2 — Subsonic API Client ✅ Complete

`lib/services/subsonic_api.dart` + generated `.chopper.dart`, `subsonic_user_helper.dart`

| Task | Status |
|---|---|
| `SubsonicAuth.generateSalt()` / `generateToken()` — MD5 per-request auth | ✅ |
| `SubsonicApi` Chopper service — all OpenSubsonic endpoints | ✅ |
| `SubsonicInterceptor` — injects auth query params on every request | ✅ |
| `SubsonicUserHelper` — in-memory session with `serverUrlOverride` for login probing | ✅ |
| Session persistence via `setSessionAndSave()` / `loadIfSaved()` | ✅ |

### Phase 3 — Subsonic API Helper ✅ Complete

`lib/services/subsonic_api_helper.dart`

| Task | Status |
|---|---|
| `probeServer(url)` — credential-free server detection for login UI | ✅ |
| `ping()` → `SubsonicServerInfo` — authenticated ping | ✅ |
| Browse / search / playlist / scrobble / lyrics / mix methods returning `BaseItemDto` | ✅ |
| `getCoverArtUrl()` / `getStreamUrl()` / `getDownloadUrl()` — auth URL builders | ✅ |
| DTO mappers: `_childToDto`, `_artistToDto`, `_albumToDto`, `_playlistToDto`, `_genreToDto` | ✅ |

### Phase 4 — Auth & Login Flow ✅ Complete

| Task | Status |
|---|---|
| `FinampUser.subsonicPassword` — `HiveField(10)`; persists Navidrome password | ✅ |
| `SubsonicUserHelper` session persistence (Isar-backed) | ✅ |
| GetIt registration of `SubsonicUserHelper` + `SubsonicApiHelper` at startup | ✅ |
| Login flow: probe → credentials → `ping()` validates → session saved | ✅ |
| `login_user_selection_page.dart` removed (QuickConnect / Jellyfin user listing) | ✅ |
| `LoginServerSelectionPage` shows `NavidromeServerWidget` on successful probe | ✅ |
| `LoginAuthenticationPage` authenticates via Subsonic ping | ✅ |

### Phase 5 — Wiring & Cleanup 🚧 In Progress

| Task | Status | Notes |
|---|---|---|
| Password security | ✅ | `flutter_secure_storage`; Android Keystore / libsecret; migration from plaintext on first run |
| `album_image_provider.dart` | ✅ | Cover art routed through `getCoverArtUrl()` |
| `view_selector.dart` | ✅ | `getViews()` → `getMusicFolders()`; logout clears `SubsonicUserHelper` |
| `metadata_provider.dart` | ✅ | Synthesizes `PlaybackInfoResponse` from `SubsonicChild` fields; lyrics via `getLyricsAsDto()` |
| `playback_history_service.dart` | ✅ | Jellyfin session endpoints → `SubsonicApiHelper.scrobble()` |
| `music_player_background_task.dart` | ✅ | `_trackUri()` uses `getStreamUrl()`; codec names map directly to Subsonic format strings |
| `downloads_service_backend.dart` | ✅ | All URL construction + sync logic rewritten for Subsonic; auth in query params |
| `downloads_service.dart` | ✅ | Lyrics fetch + repair step; `toJson()` added to all Subsonic models |
| Music browsing layer | ✅ | `getItems`, `getItemsWithTotalRecordCount`, `getItemById`, favorites dispatch via `_subsonicFetch()` |
| `SubsonicAlbumID3` deserialization | ✅ | Bad-typed OpenSubsonic fields ignored via `@JsonKey(includeFromJson: false)` |
| Queue persistence | ✅ | 4-byte length-prefix UTF-8 encoding; old 16-byte hex format crashed on Navidrome IDs |
| Track sort order | ✅ | `_subsonicSort` handles disc/track (`ParentIndexNumber`) and year (`PremiereDate`) keys |
| `PlayOnService` silenced | ✅ | Returns early when Subsonic credentials present; stops 405 spam |
| `getItemById` artist fallback | ✅ | Tries song → album → artist; fixes `artistItemProvider` in `artist_chip.dart` |
| Log level for `SubsonicException(70)` | ✅ | `getSongDto`/`getAlbumDto` demote not-found from WARNING to FINE |
| `trackCount` fix | ✅ | `_countIds()` replaces `~/ 16`; fixes `_unpackIntList` assertion crash on queue restore |
| Playlist `childCount` null check | ✅ | `_playlistToDto` sets `childCount`; `generateSubtitle` uses `item.childCount!` |
| Album `childCount` null check | ✅ | `_albumToDto` sets `childCount`; `item_info.dart` uses `item.childCount!` offline |
| `serverMissingBlurhash` suppressed | ✅ | Guards Subsonic credentials; Navidrome never provides blurhashes |
| `ThemeProvider` image error level | ✅ | `_fetchImage` onError demoted SEVERE → WARNING |
| Subsonic transcode validation | ✅ | MIME check + bitrate correction on download completion; snackbar on codec mismatch |
| Auto-offline detection | ✅ | `pingLocalServer()` routes through `SubsonicApiHelper.ping()` |
| Mix / radio | ✅ | `getInstantMix`, `getArtistMix`, `getAlbumMix`, `getGenreMix` via Subsonic |
| Playlist edit permission | ✅ | `canEditPlaylistProvider` short-circuits to `true` for Navidrome users |
| Offline artist list | ✅ | `_getCollectionInfo` falls back to `getArtist` on null album lookup; existing downloads need resync |
| Playlist create / edit / delete | ✅ | All mutations via Subsonic; index-based removal bridged via `playlistItemId` string |
| `network_settings_screen.dart` | ✅ | `pingPublicServer()` now routes through `pingActiveServer()` (Subsonic ping) when Subsonic credentials are present, matching the existing fix on `pingLocalServer()`. Previously hit Jellyfin's `/System/Endpoint` endpoint, which returns false for Navidrome but silently succeeded if Jellyfin was co-located at the same address. |

### Phase 6 — Branding

**Code renames:**

| Task | Status | Notes |
|---|---|---|
| Android `applicationId` / `namespace` | ✅ | `com.naviamp.naviamp` |
| Android `app_name` strings | ✅ | Naviamp / Naviamp Profile / Naviamp Debug |
| Android deep-link scheme | ✅ | `naviamp://` |
| Kotlin sources moved + package declarations updated | ✅ | `com/naviamp/naviamp/` |
| iOS bundle ID / display name / URL scheme | ✅ | All 3 plists + `project.pbxproj` → `com.naviamp.naviamp` |
| iOS permission strings | ✅ | `NSAppleMusicUsageDescription` updated |
| Dart MethodChannel names | ✅ | `com.naviamp.naviamp/...` aligned with Kotlin |
| Linux DBus names | ✅ | `com.naviamp.Naviamp` / `com.naviamp.NaviampSettings` |
| Linux `.desktop` + `msix_config` | ✅ | |
| Linux icon files renamed | ✅ | `finamp.png` → `naviamp.png` (9 sizes under `assets/icon/linux/`) |
| `generate_icons.sh` output filename | ✅ | |
| Dart package name (`name: finamp` in `pubspec.yaml`) | ⬜ | Intentionally deferred — renaming touches 1254 `package:finamp/` imports across upstream UI files, destroying cherry-pick compatibility. Internal to Dart toolchain; never user-visible. |
| `settings_screen.dart` repo/release links | ✅ | Needs naviamp GitHub URL |
| `assets/com.unicornsonlsd.finamp.metainfo.xml` | ⬜ | Linux AppStream metainfo; rename + rewrite (only relevant for Flatpak packaging) |

**Assets which must be created before branding is complete:**

The project uses `flutter_launcher_icons` (v0.14.1) and `flutter_native_splash` to generate derived assets from source files. Only the source files below need to be created or replaced — running `./flutterw pub run flutter_launcher_icons` and `./flutterw pub run flutter_native_splash:create` afterwards regenerates everything else.

| Source file | Size | Format | Purpose |
|---|---|---|---|
| `assets/icon/icon_combined.png` | 4320×4320 | PNG, RGBA | Primary icon source for Android/iOS (full icon with background). `flutter_launcher_icons: image_path`. Background color must be square and opaque. |
| `assets/icon/icon_combined_macos.png` | 1024×1024 | PNG, RGBA | macOS app icon source. `flutter_launcher_icons: macos.image_path`. |
| `assets/icon/icon_foreground.png` | 4320×4320 | PNG, RGBA | Android adaptive icon foreground layer (logo only, transparent background). `flutter_launcher_icons: adaptive_icon_foreground`. Adaptive background color is `#000B25` in `pubspec.yaml`. |
| `assets/icon/icon_foreground.svg` | vector | SVG | SVG source for the foreground; used by `generate_icons.sh` via `inkscape` for Linux icon sizes. |
| `assets/icon/icon_foreground_noborder.svg` | vector | SVG | Variant without border padding; also used by `generate_icons.sh`. |
| `assets/icon/icon_white_noborder.png` | 4320×4320 | PNG, white-on-transparent | Android 13+ monochrome / themed icon. Must be white-on-transparent only. |
| `assets/icon/icon_white_noborder.svg` | vector | SVG | SVG source for the monochrome variant. |
| `assets/splash_ios_light.png` | — | PNG | iOS splash center logo (light mode). |

After replacing SVG sources, regenerate Linux icons with:
```sh
cd assets/icon && bash generate_icons.sh   # requires inkscape + imagemagick
```

**Android derived assets — auto-generated by `flutter_launcher_icons`, do not edit manually:**

| Directory | File | Pixel size |
|---|---|---|
| `mipmap-mdpi` | `ic_launcher.png` | 48×48 |
| `mipmap-hdpi` | `ic_launcher.png` | 72×72 |
| `mipmap-xhdpi` | `ic_launcher.png` | 96×96 |
| `mipmap-xxhdpi` | `ic_launcher.png` | 144×144 |
| `mipmap-xxxhdpi` | `ic_launcher.png` | 192×192 |
| `mipmap-*/white.png` | launcher white variant | same 5 sizes |
| `drawable-mdpi` | `ic_launcher_monochrome.png` | 108×108 |
| `drawable-hdpi` | `ic_launcher_monochrome.png` | 162×162 |
| `drawable-xhdpi` | `ic_launcher_monochrome.png` | 216×216 |
| `drawable-xxhdpi` | `ic_launcher_monochrome.png` | 324×324 |
| `drawable-xxxhdpi` | `ic_launcher_monochrome.png` | 432×432 |
| `drawable-v24` | `ic_launcher_foreground.xml` | Adaptive icon vector — currently contains Finamp logo paths; replace manually or regenerate |

**Android splash — auto-generated by `flutter_native_splash`, do not edit manually:**

| Directory | File | Pixel size | Notes |
|---|---|---|---|
| `drawable-*/splash.png` | splash logo | mdpi:1080, hdpi:1620, xhdpi:2160, xxhdpi:3240, xxxhdpi:4320 (square) | Source = `icon_combined.png` |
| `drawable-*/android12splash.png` | Android 12+ splash | same 5 sizes + 5 `-night-*` variants | |
| `drawable[-night]/background.png` | 1×1 background color | — | Color-only, not artwork |

**iOS derived assets — auto-generated, do not edit manually:**
All sizes in `ios/Runner/Assets.xcassets/AppIcon.appiconset/` are generated from `icon_combined.png`. Largest required: **1024×1024** (App Store). Sizes needed: 20, 29, 40, 50, 57, 60, 72, 76, 83.5, 1024 pt at 1–3× scale.

iOS launch images in `ios/Runner/Assets.xcassets/LaunchImage.imageset/`: 128×128 (@1x), 256×256 (@2x), 384×384 (@3x).

**Jellyfin-specific images to replace:**

| File | Size | Current use | Action |
|---|---|---|---|
| `images/jellyfin-icon-transparent.png` | 512×512 | Discord RPC server icon fallback (`finamp_models.dart:3639`) | Replace with Navidrome logo PNG (512×512) or generic Naviamp icon |
| `images/finamp.png` | 432×432 | Discord RPC fallback icon + `assets.gen.dart` reference | Replace; rename to `images/naviamp.png`; update `pubspec.yaml` asset list and `lib/gen/assets.gen.dart` |
| `images/finamp_cropped.png` | 512×512 | Discord RPC fallback icon setting preview | Replace; rename to `images/naviamp_cropped.png` |
| `images/finamp_cropped.svg` | vector | `finamp_icon.dart` (app header icon) and `main.dart` hero logo | **Most visible in-app asset.** Replace SVG artwork; rename to `images/naviamp_cropped.svg`; update `lib/components/finamp_icon.dart:15` and `lib/main.dart:825` |

After renaming `images/` files, update `pubspec.yaml` asset paths (lines 207–215) and regenerate `lib/gen/assets.gen.dart` with `build_runner`.

---

## Upstream Sync Strategy

To pull UI improvements from upstream Finamp:
1. The UI widget files in `lib/components/` and `lib/screens/` should be **identical or near-identical** to upstream
2. Data model types that the UI references (`BaseItemDto`, etc.) must stay structurally compatible
3. When pulling upstream changes, conflicts will mostly appear in the service layer — that is expected and intentional
4. Any UI change that upstream makes to a Jellyfin-specific screen (login, server discovery) will need manual review; everything else should apply cleanly

## Known Limitations / TODOs

### Phase 6 — Deferred Cleanup

- **`jellyfin_api.dart` and `jellyfin_api_helper.dart`** still exist and are still registered. `JellyfinApiHelper` is retained as a thin Subsonic proxy (`getItems`, `getItemById`, `addFavorite`, `removeFavorite`) and for its `runInIsolate()` utility used by `downloads_service.dart`. Both files should be pruned / replaced in Phase 6.
- **`FinampUser` Jellyfin fields** (`accessToken`, `serverId`, `views`) are still in the model. For Subsonic logins they are set to empty strings / empty maps. Will be cleaned up in Phase 6.
- **`FinampUser.subsonicPassword`** field still exists for migration reading (detects and migrates plaintext passwords from old installs to secure storage on first run). No longer written by new code. Can be removed in Phase 6 after migration window.
- **Dart package name** (`name: finamp` in `pubspec.yaml`) intentionally left as `finamp` — renaming it would touch 1254 `package:finamp/` imports across upstream UI files and permanently break cherry-pick compatibility. Internal to the Dart toolchain; never user-visible.

### Client-side TODOs

- **Offline play-count sync** — When offline, completed plays are logged to `Hive.box<OfflineListen>("OfflineListens")`. There is no code that drains this box and re-submits the scrobbles when the client comes back online. Implementation: listen for the `isOffline` setting transitioning `true → false` (Riverpod or FinampSettingsHelper stream), then iterate the box and call `SubsonicApiHelper.scrobble(id: listen.itemId, submission: true, time: listen.timestamp * 1000)` for each entry, removing successful submissions. The JSON file export (`listens.json`) can serve as an audit trail but is not a substitute for active sync. See `lib/services/offline_listen_helper.dart`.
- **OpenSubsonic bookmark / play-queue persistence** — No call to `savePlayQueue` or `getPlayQueue` is implemented. These OpenSubsonic endpoints persist the current track, position (ms), and queue across sessions and devices — equivalent to Jellyfin's resume-from-position. Implementation: call `savePlayQueue` from `reportPlaybackStopped()` in `playback_history_service.dart`; restore position via `getPlayQueue` in the queue-restore flow. See `lib/services/subsonic_api.dart` for the stub TODO.
- **`probeServer` bypasses Chopper** (`subsonic_api_helper.dart:probeServer`) — uses a raw `http.get()` call instead of the `SubsonicApi` Chopper client. Chopper's `JsonConverter.responseFactory` pipeline fails for unauthenticated pings (response is received and logged, but `bodyOrThrow` fails the `as Map` cast). All authenticated calls use `_unwrap()` correctly. Should be moved back to Chopper once the converter issue is diagnosed.
- **Chopper empty-body WARNING** — `[Chopper/WARNING] FormatException: Unexpected character (at character 1)` observed during testing. `JsonConverter` logs this when receiving a non-JSON body from an endpoint with `@FactoryConverter(response: JsonConverter.responseFactory)`. Handled gracefully (no snackbar, no SEVERE). Likely a Subsonic mutation endpoint (`updatePlaylist`, `createPlaylist`, or similar) that Navidrome returns with an empty body on success. TODO: identify the exact endpoint via logging, then either remove the `@FactoryConverter` annotation or handle the empty-body case in `SubsonicEnvelope.unwrap`.
- **Resync performance — two potential improvements to investigate:**
  - *Playlist skip-if-unchanged*: `_needsMetadataUpdate()` in `downloads_service_backend.dart` unconditionally returns `true` for playlists, so every sync re-fetches every playlist even if nothing changed. Could compare stored `childCount` + `name` from Isar first; only mark needs-update if either differs. High value for libraries with many playlists.
  - *Cross-sync artist/genre cache*: `_metadataCache` and `_childCache` are cleared at the start of every `executeSyncs()`. A short-lived TTL map (5–10 min) keyed on `BaseItemId` would collapse artist/genre fetches of back-to-back syncs to zero. Albums and tracks should stay per-run.

### Server-side / Navidrome Plugin Research

These gaps cannot be closed from the client alone — they require either a Navidrome plugin, a companion sidecar, or a new OpenSubsonic protocol extension.

- **Delta sync** — OpenSubsonic has no "give me everything modified since timestamp X" endpoint, so the client must re-fetch and compare on every sync. A plugin exposing `/rest/getChanges.view?ifModifiedSince=<unix-ms>` could collapse a full library resync to a handful of calls. Key questions: (1) does Navidrome's planned plugin API expose DB-level change hooks, (2) what change granularity is needed (song-level, album-level, or dirty flag), (3) whether the OpenSubsonic working group would accept a `getChanges` extension proposal so other servers and clients could benefit.
- **Performing artist browse** — OpenSubsonic's `getArtists` returns only album artists (artists credited as album artist on at least one album). There is no endpoint equivalent to Jellyfin's `artistIds` filter — no way to query "all albums/tracks where this person appears as a track-level performing credit." Practically: if Tom Petty & the Heartbreakers perform on a Stevie Nicks album track, that track does not appear on their artist page when the "Artists" (performing) filter is selected, only on the Stevie Nicks album. The data exists in Navidrome's database; it is simply not exposed via the Subsonic protocol. A plugin endpoint such as `/rest/getTracksByArtistId.view?id=...` would close this gap. In the meantime, both the "Album Artists" and "Artists" tabs in the browse UI show identical data (album artists only).
