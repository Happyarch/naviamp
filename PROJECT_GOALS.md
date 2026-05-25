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
| **App settings / downloads** | `finamp_models.dart` largely intact; strip Jellyfin-specific fields. |

---

## Dev Environment Setup

Source `dev-env.sh` in the project root whenever you start a session:
```sh
source dev-env.sh
```
This sets `JAVA_HOME`, `ANDROID_HOME`, and PATH without permanently modifying your shell.

### One-time setup

1. **Flutter submodule** — already initialized via `git submodule update --init .flutter`. Use `./flutterw` for all Flutter commands.

2. **JDK 17** — already installed. The `dev-env.sh` script points `JAVA_HOME` at it.

3. **Android SDK** — install to `~/Android/Sdk` (see Android SDK Setup section below).

4. **Get dependencies and generate code:**
   ```sh
   source dev-env.sh
   ./flutterw pub get
   ./flutterw pub run build_runner build --delete-conflicting-outputs
   ```

5. **Verify:**
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
    └── android-35/
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
sdkmanager "platform-tools" "build-tools;36.0.0" "platforms;android-35"
```

---

## Codebase Overview

| Layer | Files | Role |
|---|---|---|
| API client | `lib/services/jellyfin_api.dart` + `.chopper.dart` | **REPLACE** — Chopper HTTP client for Jellyfin |
| API helper | `lib/services/jellyfin_api_helper.dart` | **REPLACE** — high-level operations, URL building (~1230 lines) |
| User/auth | `lib/services/finamp_user_helper.dart` | **MODIFY** — swap Jellyfin auth header for Subsonic token params |
| Server models | `lib/models/jellyfin_models.dart` | **REPLACE** — Jellyfin-specific JSON models |
| App models | `lib/models/finamp_models.dart` | **KEEP / TRIM** — settings, FinampUser, download models |
| Metadata | `lib/services/metadata_provider.dart` | **MODIFY** — remove PlaybackInfoResponse dependency |
| Playback | `lib/services/music_player_background_task.dart` | **MODIFY lightly** — stream URL construction |
| Downloads | `lib/services/downloads_service.dart` + `_backend.dart` | **MODIFY** — swap download URL construction |
| UI | `lib/components/`, `lib/screens/` | **LEAVE ALONE** except branding |

State management: **Riverpod**. DI: **get_it**. DB: **Isar**. HTTP: **Chopper**.

---

## Jellyfin → Navidrome API Mapping

### Authentication

| Jellyfin | Navidrome |
|---|---|
| `POST /Users/AuthenticateByName` | Query params on every request: `u`, `t=md5(password+salt)`, `s=salt` |
| `MediaBrowser ...` auth header | No header — credentials in every request's query string |
| Access token stored in `FinampUser.accessToken` | Salt stored; password hashed on the fly |
| QuickConnect | **Not available** — remove from UI |

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

Works for songs, albums, and artists — same `id` field.

### Lyrics

| Jellyfin | Navidrome |
|---|---|
| `GET /Audio/{itemId}/Lyrics` | `getLyrics?artist=...&title=...` |

**Difference:** Navidrome looks up lyrics by artist name + track title, not item ID. Must pass those fields from the track metadata.

### Favorites

| Jellyfin | Navidrome |
|---|---|
| `POST /Users/{userId}/FavoriteItems/{itemId}` | `star?id=...` |
| `DELETE /Users/{userId}/FavoriteItems/{itemId}` | `unstar?id=...` |
| `getItems(isFavorite=true)` | `getStarred2` |

### Playlists

Functionally equivalent: `getPlaylists`, `getPlaylist(id)`, `createPlaylist`, `updatePlaylist`, `deletePlaylist`.

### Similar / Radio

| Jellyfin | Navidrome |
|---|---|
| `GET /Items/{id}/InstantMix` | `getSimilarSongs2(id)` |
| `GET /Albums/{id}/Similar` | `getSimilarSongs2` (song-level only) |

---

## Implementation Phases

### Phase 0 — Dev Environment ✓
- [x] Initialize `.flutter` submodule — Flutter 3.44.0 / Dart 3.12.0 @ `heads/stable`
- [x] Install Android SDK to `~/Android/Sdk` — build-tools 36.0.0, platforms android-35/36, NDK 28.2, CMake 3.22
- [x] `./flutterw doctor` — Android toolchain green
- [x] `./flutterw pub get && ./flutterw pub run build_runner build`
- [x] `./flutterw build apk --debug` succeeds

### Phase 1 — Navidrome Models
Create `lib/models/subsonic_models.dart` with JSON-serializable Dart classes for OpenSubsonic responses:
- `SubsonicResponse<T>` wrapper
- `ArtistID3`, `AlbumID3`, `Child` (song), `Genre`, `Playlist`, `PlaylistWithSongs`
- `StarredResult`, `SearchResult3`, `LyricsList`
- Auth helpers (token generation)

These are **internal** — the service layer maps them to existing `BaseItemDto` types before the UI ever sees them.

### Phase 2 — Subsonic API Client
Replace `jellyfin_api.dart` + `jellyfin_api.chopper.dart`:
- New file: `lib/services/subsonic_api.dart` — Chopper client for OpenSubsonic endpoints
- Auth interceptor: injects `u`, `t`, `s`, `v`, `c`, `f=json` query params on every request
- Mirrors the Chopper pattern used by `jellyfin_api.dart`

### Phase 3 — Subsonic API Helper
Replace `jellyfin_api_helper.dart` with `subsonic_api_helper.dart`:
- Maps Subsonic responses → `BaseItemDto` / `PlaybackInfoResponse` (synthesized)
- Builds stream URLs (`/rest/stream.view?...`)
- Builds artwork URLs (`/rest/getCoverArt.view?...`)
- Implements scrobble-based playback reporting

### Phase 4 — Auth & User Model
- Strip Jellyfin-specific fields from `FinampUser` (access token → store hashed credentials for Subsonic)
- Update `finamp_user_helper.dart` — remove `getAuthHeader()` / `MediaBrowser` header logic
- Update login screen to use Navidrome's username+password+token-auth flow
- Remove QuickConnect UI

### Phase 5 — Wiring & Cleanup
- Update `metadata_provider.dart` to use synthesized `PlaybackInfoResponse`
- Update `downloads_service` to use Subsonic download URLs
- Update `playback_history_service.dart` to call `scrobble` instead of session endpoints
- Rename app: `finamp` → `naviamp` in `pubspec.yaml`, app ID, display name

### Phase 6 — Branding
- App name, package ID, icon
- Strip Jellyfin-specific assets/images

---

## Upstream Sync Strategy

To pull UI improvements from upstream Finamp:
1. The UI widget files in `lib/components/` and `lib/screens/` should be **identical or near-identical** to upstream
2. Data model types that the UI references (`BaseItemDto`, etc.) must stay structurally compatible
3. When pulling upstream changes, conflicts will mostly appear in the service layer — that is expected and intentional
4. Any UI change that upstream makes to a Jellyfin-specific screen (login, server discovery) will need manual review; everything else should apply cleanly
