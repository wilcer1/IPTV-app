# IPTV App

A cross-platform IPTV client built with Flutter, targeting Android (phone and Google TV) and Windows. Connects to any Xtream Codes-compatible IPTV subscription.

## Features

- **Xtream Codes login** — sign in with host, username, and password (no manual M3U URLs needed)
- **Live TV, Movies, and Series**, browsable by category
- **Search** across channels, movies, series, and the program guide (EPG) at once
- **Favorites** — star any channel, movie, or episode for quick access later
- **Account tab** — view subscription status/expiry/connection count, log out
- **Light/dark theme**, follows system by default, with an adaptive layout (side navigation rail on wide/desktop windows, bottom bar on phones)
- Auto-reconnect on launch using securely stored credentials

## Download (Windows)

Grab the latest `iptv-app-windows-x64.zip` from the [Releases](../../releases) page, extract it anywhere, and run `iptv_app.exe`. No installer needed — the zip contains everything required to run.

## Building from source

Requirements: [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel), and for Windows builds, Visual Studio with the "Desktop development with C++" workload.

```bash
flutter pub get
flutter run -d windows
```

Release builds must pass `--no-tree-shake-icons` (see [Known issues](#known-issues)):

```bash
flutter build windows --release --no-tree-shake-icons
```

For Android: `flutter build apk --release --no-tree-shake-icons`.

## Tech stack

- **Flutter** — single codebase across Android phone/TV and Windows
- **media_kit** — video playback (libmpv-based), handles the HLS/MPEG-TS streams Xtream panels serve
- **flutter_secure_storage** — credentials are stored via OS-level secure storage (Windows Credential Manager / Android Keystore), not plaintext

## Known issues

- Flutter's release-build icon tree-shaking drops icons this app uses (nav bar, favorite stars). Always build release with `--no-tree-shake-icons` until resolved upstream.
- Movie/episode playback assumes the `container_extension` reported by the Xtream API is accurate; unusual providers may need adjustment.
- Search's EPG (program guide) matching depends on the provider populating `epg_channel_id` on live streams and serving `xmltv.php`; providers without EPG support will only get channel/movie/series-name search results.
- **Windows builds are unsigned.** Regular SmartScreen shows a one-click "Run anyway" prompt, but Windows 11's stricter **Smart App Control** blocks unsigned/unrecognized binaries outright with no override — if you hit this, either code-sign the build yourself or disable Smart App Control (note: once it's fully "On" rather than "Evaluation", Microsoft only lets you turn it off via a clean Windows reinstall).
