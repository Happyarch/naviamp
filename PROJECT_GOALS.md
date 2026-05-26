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

Source `dev-env.sh` in the project root whenever you start a session:
```sh
source dev-env.sh
```
This sets `JAVA_HOME`, `ANDROID_HOME`, and PATH without permanently modifying your shell.

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
- [x] Initialize `.flutter` submodule — Flutter 3.44.0 / Dart 3.12.0 @ `heads/stable`
- [x] Install Android SDK to `~/Android/Sdk` — build-tools 36.0.0, platforms android-35/36, NDK 28.2, CMake 3.22
- [x] Install Rust via `rustup` (required by `flutter_discord_rpc`)
- [x] `./flutterw doctor` — Android toolchain green
- [x] `./flutterw pub get && ./flutterw pub run build_runner build`
- [x] `./flutterw build apk --debug` succeeds

### Phase 1 — Navidrome Models ✅ Complete
`lib/models/subsonic_models.dart` + generated `.g.dart`
- [x] `SubsonicEnvelope.unwrap()` — parses and validates the `subsonic-response` envelope
- [x] `SubsonicException` — error codes including auth, not-found, missing-params
- [x] `SubsonicChild` (song), `SubsonicArtistID3`, `SubsonicAlbumID3` — full OpenSubsonic fields
- [x] `SubsonicPlaylist` / `SubsonicPlaylistWithSongs`, `SubsonicSearchResult3`, `SubsonicStarred2`
- [x] `SubsonicStructuredLyrics` / `SubsonicLyricsList` — OpenSubsonic synced lyrics
- [x] `SubsonicServerInfo` — server version/type from ping envelope

### Phase 2 — Subsonic API Client ✅ Complete
`lib/services/subsonic_api.dart` + generated `.chopper.dart`, `subsonic_user_helper.dart`
- [x] `SubsonicAuth.generateSalt()` / `generateToken()` — MD5 per-request auth
- [x] `SubsonicApi` Chopper service — all OpenSubsonic endpoints (ping, browse, search, playlist, scrobble, lyrics, mix)
- [x] `SubsonicInterceptor` — injects auth query params on every request
- [x] `SubsonicUserHelper` — in-memory session; `serverUrlOverride` for login probing
- [x] Persistence: `setSessionAndSave()` / `loadIfSaved()` backed by `FinampUser.subsonicPassword`

### Phase 3 — Subsonic API Helper ✅ Complete
`lib/services/subsonic_api_helper.dart`
- [x] `probeServer(url)` — credential-free server detection for login UI
- [x] `ping()` → `SubsonicServerInfo` — authenticated ping
- [x] All browse / search / playlist / scrobble / lyrics / mix methods returning `BaseItemDto`
- [x] `getCoverArtUrl()` / `getStreamUrl()` / `getDownloadUrl()` — auth URL builders
- [x] DTO mappers: `_childToDto`, `_artistToDto`, `_albumToDto`, `_playlistToDto`, `_genreToDto`

### Phase 4 — Auth & Login Flow ✅ Complete
- [x] `FinampUser.subsonicPassword` — new HiveField(10); persists Navidrome password alongside server URL + username
- [x] `SubsonicUserHelper.setSessionAndSave()` / `loadIfSaved()` — Isar-backed persistence
- [x] GetIt registration: `SubsonicUserHelper` + `SubsonicApiHelper` registered at startup; session restored from Isar
- [x] Login flow replaced: server URL probe via `probeServer()` → credentials page → `ping()` validates → session saved
- [x] `login_user_selection_page.dart` removed (Jellyfin-specific: QuickConnect, user listing — no Navidrome equivalent)
- [x] `LoginServerSelectionPage` now shows `NavidromeServerWidget` on successful probe
- [x] `LoginAuthenticationPage` authenticates via Subsonic ping; no Jellyfin updateCapabilities

### Phase 5 — Wiring & Cleanup 🚧 In Progress
Wire the new Subsonic services into the live app so playback and browsing actually work:
- [x] **Password security** — `flutter_secure_storage` replaces plaintext `subsonicPassword`; Android Keystore on Android, libsecret/Secret Service on Linux; migration from old plaintext storage on first run
- [x] `album_image_provider.dart` — routed cover art through `SubsonicApiHelper.getCoverArtUrl()`
- [x] `view_selector.dart` — replaced `getViews()` with `SubsonicApiHelper.getMusicFolders()`; logout now calls `SubsonicUserHelper.clearSessionAndSave()`
- [x] `metadata_provider.dart` — synthesizes `PlaybackInfoResponse`/`MediaSourceInfo` from `SubsonicChild` fields stored in `BaseItemDto.mediaSources` by `_childToDto`; fetches lyrics via `getLyricsAsDto()` → `LyricDto`; no server round-trip for basic playback metadata
- [x] `playback_history_service.dart` — replaced Jellyfin session endpoints with `SubsonicApiHelper.scrobble()`; `submission: false` for now-playing, `submission: true` for track completion
- [x] `music_player_background_task.dart` — `_trackUri()` replaced: direct play → `getStreamUrl(item)` (original file); transcode → `getStreamUrl(item, format: subsonicFormat, maxBitRate: kbps)`; `FinampTranscodingStreamingFormat.codec` maps directly to Subsonic format names (vorbis → "ogg")
- [x] `downloads_service_backend.dart` — `IsarTaskQueue` now uses `SubsonicApiHelper.getDownloadUrl()` / `getStreamUrl()` / `getCoverArtUrl()` for all download URL construction; Subsonic auth is in query params so no `Authorization` header is set; `DownloadsSyncService._getCollectionInfo/Children/_getFinampCollectionChildren` fully rewritten to use Subsonic endpoints dispatched by item type; lyrics fetched unconditionally via `getLyricsAsDto()` (no Jellyfin MediaStream check needed)
- [x] `downloads_service.dart` — repair step 4 lyrics fetch replaced with `SubsonicApiHelper.getLyricsAsDto()`; `getSong` endpoint added to `subsonic_api.dart` for per-song metadata fetches; `toJson()` instance methods added to all `@JsonSerializable` Subsonic model classes (required by `explicitToJson: true` on parent classes)
- [x] **Music browsing layer** — `JellyfinApiHelper.getItems()`, `getItemsWithTotalRecordCount()`, `getItemById()`, `addFavorite()`, `removeFavorite()` overridden to dispatch to `SubsonicApiHelper` via `_subsonicFetch()`. All UI provider files left untouched. Working: artists, albums, songs, genres, playlists, search, favorites, artist discography, album track listing.
- [x] **`SubsonicAlbumID3` deserialization** — `originalReleaseDate`, `releaseDate`, `releaseTypes` marked `@JsonKey(includeFromJson: false, includeToJson: false)`; Navidrome sends these as objects/arrays instead of strings
- [x] **Queue persistence** — `FinampStorableQueueInfo.packIds`/`_unpackIds` rewritten with 4-byte length-prefix UTF-8 encoding; old 16-byte hex UUID format crashed for Navidrome's alphanumeric IDs
- [x] **Track sort order** — `_subsonicSort` handles `ParentIndexNumber`/`IndexNumber` (disc→track for album views) and `PremiereDate`/`ProductionYear` (year for artist discography)
- [x] **`PlayOnService` silenced** — returns early in `startListener()` when Subsonic credentials are present; eliminates 405 spam to Navidrome's non-Jellyfin endpoints
- [x] **`getItemById` artist fallback** — tries song → album → artist in sequence; fixes `artistItemProvider` in `artist_chip.dart` which calls `getItemById(artistId)` on render
- [x] **Log level** — `getSongDto`/`getAlbumDto` demote `SubsonicException(70)` from WARNING to FINE; reduces noise from expected fallback misses
- [x] **`trackCount` fix** — replaced `~/ 16` formula with `_countIds()` that walks 4-byte length-prefix format; fixes `_unpackIntList` assertion crash on queue restore
- [x] **Playlist tab null check** — `_playlistToDto` was missing `childCount`; `generateSubtitle` uses `item.childCount!` for playlists; fixed by adding `childCount: playlist.songCount`
- [x] **Offline album screen null check** — `_albumToDto` was missing `childCount`; `item_info.dart` uses `item.childCount!` in offline mode; fixed by adding `childCount: album.songCount`
- [x] **`serverMissingBlurhash` warning suppressed** — `downloads_service.dart` now checks Subsonic credentials before setting the flag; Navidrome never provides blurhashes so the "Jellyfin server misconfigured" warning was always appearing falsely
- [x] **ThemeProvider image error level** — `_fetchImage` onError demoted from SEVERE to WARNING; empty cached image files (e.g. disc-level cover art not found) are handled gracefully and don't warrant SEVERE
- [x] **Subsonic transcode validation** — on track download completion, checks `event.mimeType` against expected MIME for the requested codec (`_isExpectedAudioMime`); warns user via snackbar and WARNING log if Navidrome served a different format (e.g. fell back to original because no matching FFmpeg profile exists). Also estimates actual bitrate from file size ÷ duration; if >20% below requested (server capped it), updates `fileTranscodingProfile.stereoBitrate` to the actual value so the downloads UI shows the real bitrate.
- [x] **Auto-offline detection fixed** — `pingActiveServer()` and `pingLocalServer()` now route through `SubsonicApiHelper.ping()` when Subsonic credentials are present; previously called Jellyfin `/pingServer` which always failed for Navidrome, causing the app to falsely enter offline mode.
- [x] **Mix / radio fixed for Navidrome** — `getInstantMix`, `getArtistMix`, `getAlbumMix` now call `SubsonicApiHelper.getInstantMix(id)`; `getGenreMix` calls `getSongsByGenre()` + shuffle; `getSimilarAlbums` returns `null` for Navidrome (callers fall back to artist-based selection). Previously all four called Jellyfin endpoints, producing 404/500 errors.
- [x] **Playlist edit permission fixed** — `canEditPlaylistProvider` now short-circuits to `true` for Navidrome users; previously called `getPlaylistUser` (Jellyfin-only) which always threw, causing `catchError → false` and hiding the edit button even for the playlist owner.
- [x] **Offline artist list missing downloaded artists** — `_getCollectionInfo` in `downloads_service_backend.dart` defaulted to `BaseItemDtoType.album` when an ID was not yet in Isar. `getAlbumDto` swallows not-found exceptions and returns `null`, so the existing `SubsonicException` fallback to `getArtist` never fired. Added a `null`-result fallback: if `getAlbumDto` returns `null` and the subtype was guessed (not from Isar), try `getArtist`. Affects both album-to-artist and track-to-artist info links. Existing downloads need a resync to populate the missing links.
- [x] **Playlist create/edit/delete** — all playlist mutation operations now routed through Subsonic: `createNewPlaylist` uses `createPlaylistGetId`; `updatePlaylist` dispatches to `replacePlaylistTracks` (track-list overwrite via `createPlaylist(playlistId)`) or `updatePlaylist` (name/public metadata); `addItemstoPlaylist` expands non-song IDs (albums, artists, playlists, genres) to song IDs before calling Subsonic `updatePlaylist(songIdToAdd)`; `removeItemsFromPlaylist` parses 0-based index strings (stored as `playlistItemId` by `getPlaylist`) and calls Subsonic `updatePlaylist(songIndexToRemove)`. `getPlaylist` now sets `playlistItemId = index.toString()` on every returned song so the remove flow has the index it needs.
- [ ] **`network_settings_screen.dart`** — still pings Jellyfin server URL (non-functional)

### Phase 6 — Branding
- [ ] App name: `finamp` → `naviamp` in `pubspec.yaml`
- [ ] Package ID: `com.unicornsonlsd.finamp` → `com.naviamp.naviamp`
- [ ] Replace icons and splash screen assets
- [ ] Strip Jellyfin-specific images (`jellyfin-icon-transparent.png`, etc.)

---

## Upstream Sync Strategy

To pull UI improvements from upstream Finamp:
1. The UI widget files in `lib/components/` and `lib/screens/` should be **identical or near-identical** to upstream
2. Data model types that the UI references (`BaseItemDto`, etc.) must stay structurally compatible
3. When pulling upstream changes, conflicts will mostly appear in the service layer — that is expected and intentional
4. Any UI change that upstream makes to a Jellyfin-specific screen (login, server discovery) will need manual review; everything else should apply cleanly

## Known Limitations / TODOs

- **`jellyfin_api.dart` and `jellyfin_api_helper.dart`** still exist and are still registered. `JellyfinApiHelper` is retained as a thin Subsonic proxy (`getItems`, `getItemById`, `addFavorite`, `removeFavorite`) and for its `runInIsolate()` utility used by `downloads_service.dart`. Both files should be pruned / replaced in Phase 6.
- **`FinampUser` Jellyfin fields** (`accessToken`, `serverId`, `views`) are still in the model. For Subsonic logins they are set to empty strings / empty maps. They will be cleaned up in Phase 6.
- **`FinampUser.subsonicPassword`** field still exists in the model for migration reading (detects and migrates plaintext passwords from old installs to secure storage on first run). It is no longer written by new code. Can be removed in Phase 6 after migration window.
- **`network_settings_screen.dart`** — still pings Jellyfin server URL (non-functional, harmless). The only remaining Phase 5 item.
- **`probeServer` bypasses Chopper** (`subsonic_api_helper.dart:probeServer`) — uses a raw `http.get()` call instead of going through the `SubsonicApi` Chopper client. The root cause is that Chopper's `JsonConverter.responseFactory` pipeline doesn't correctly return the parsed `Map` body when called without credentials (the response is received and logged, but `bodyOrThrow` produces a value that fails the `as Map` cast). All other authenticated API calls go through `_unwrap()` correctly. The probe should eventually be moved back to using Chopper once the converter issue is diagnosed and fixed.
- **Resync performance — two potential improvements to investigate:**
  - *Playlist skip-if-unchanged*: `_needsMetadataUpdate()` in `downloads_service_backend.dart` unconditionally returns `true` for playlists, so every sync re-fetches every playlist from the server even if nothing changed. Could compare stored `childCount` + `name` from Isar before fetching; only mark needs-update if either differs. High value for libraries with many playlists.
  - *Cross-sync artist/genre cache*: `_metadataCache` and `_childCache` are cleared at the start of every `executeSyncs()` call. Artists and genres are fetched fresh on every sync run even if the previous run just fetched them. A short-lived TTL map (5–10 min) keyed on `BaseItemId` on `IsarTaskQueue` would collapse the artist/genre fetches of back-to-back syncs (e.g., editing two playlists in a row) to zero. Albums and tracks should stay per-run. OpenSubsonic has no delta/changelog API so re-fetch-and-compare is unavoidable, but caching info items across runs is safe.
- **Chopper empty-body WARNING** — `[Chopper/WARNING] FormatException: Unexpected character (at character 1)` observed once during session testing (13:07:24). Chopper's `JsonConverter` logs this when it receives a non-JSON body (empty string or plain text) from an endpoint that has `@FactoryConverter(response: JsonConverter.responseFactory)`. The call is otherwise handled gracefully (no snackbar, no SEVERE). Likely from a Subsonic mutation endpoint (`updatePlaylist`, `createPlaylist`, or similar) that Navidrome returns with an empty body for certain success responses. TODO: add logging around mutation calls to identify the exact endpoint, then either remove the `@FactoryConverter` annotation from that endpoint or handle the empty-body case in `SubsonicEnvelope.unwrap`.
