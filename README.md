# Naviamp

**Naviamp** is a [Navidrome](https://www.navidrome.org/) music player for Android, iOS, and Linux. It is a fork of [Finamp](https://github.com/jmshrv/finamp) with the Jellyfin backend replaced by the [OpenSubsonic](https://opensubsonic.netlify.app/) API that Navidrome exposes. The UI is kept as close to upstream Finamp as possible so that front-end improvements can be pulled from upstream with minimal conflict.

> **Status: early beta.** Core playback, browsing, downloading, and transcoding are working. Some features are still in progress — see [Known Gaps](#known-gaps) below.

---

## Features

- Stream or download music from your Navidrome server
- Transcoded streaming and downloads (MP3, AAC, Opus, Ogg Vorbis, FLAC)
- Offline playback with downloaded tracks
- Full album/artist/genre/playlist browsing
- Search
- Favorites (star/unstar)
- Synced and unsynced lyrics via OpenSubsonic
- Scrobbling / play count reporting
- Instant mix / radio (OpenSubsonic `getInstantMix`)
- Gapless playback
- Dynamic color theming
- Android, iOS, and Linux desktop support

---

## Getting Naviamp

Naviamp is not yet on any app store. Build from source or grab a debug APK from the [releases page](https://github.com/Happyarch/naviamp/releases) when available.

### Building from source

Requirements: Flutter (via the pinned `.flutter` submodule), JDK 17, Android SDK. See [`PROJECT_GOALS.md`](PROJECT_GOALS.md) for the full dev environment setup.

```sh
git clone https://github.com/Happyarch/naviamp.git
cd naviamp
git submodule update --init .flutter
source dev-env.sh

./flutterw pub get
./flutterw pub run build_runner build --delete-conflicting-outputs

# Android
./flutterw build apk --debug

# Linux
./flutterw build linux --debug
```

---

## Known Gaps

- **In-app logo** — the header icon still uses placeholder Finamp artwork while Naviamp artwork is being created.
- **Offline play-count sync** — plays logged while offline are stored locally but not yet re-submitted to the server when connectivity returns.
- **Resume position** — OpenSubsonic `savePlayQueue` / `getPlayQueue` is not yet implemented; playback position is not persisted across sessions or devices.
- **Release builds** — no signed release APK yet; debug builds only.

---

## Contributing

Naviamp is under active development. If you find a bug or want to contribute, open an issue or pull request on [GitHub](https://github.com/Happyarch/naviamp).

The service layer (`lib/services/subsonic_*.dart`) is the primary development target. The UI widget files in `lib/components/` and `lib/screens/` are kept upstream-compatible with Finamp — see [`CLAUDE.md`](CLAUDE.md) for architecture notes.

---

## Credits

Naviamp is built on top of [Finamp](https://github.com/jmshrv/finamp) by [@jmshrv](https://github.com/jmshrv) and contributors. The UI, playback engine, download system, and most of the infrastructure come from upstream Finamp. Naviamp only replaces the server backend.

---

## Info For Advanced Users

### Dynamic Theming On Linux

On Linux, Naviamp registers itself with the DBus system, which lets you send messages locally to control the color theme without restarting the app. Two endpoints are available:

1. Reload the system accent color from GTK (`Settings > Layout & Theme > "Use System Accent"` must be *enabled*)
```sh
gdbus call \
    --session \
    --dest 'com.naviamp.NaviampSettings' \
    --object-path '/com/naviamp/Naviamp' \
    --method 'com.naviamp.Naviamp.updateAccentColor'
```

2. Override the accent color (`Settings > Layout & Theme > "Use System Accent"` must be *disabled*)
```sh
gdbus call \
    --session \
    --dest 'com.naviamp.NaviampSettings' \
    --object-path '/com/naviamp/Naviamp' \
    --method 'com.naviamp.Naviamp.setAccentColor' \
    '#ff0000' # pass "default" to clear the override
```
