<p align="center">
  <img src="lib/auth_logo.png" alt="Hyperion logo" width="160" />
</p>

<h1 align="center">Hyperion Mobile</h1>

<p align="center">
  Companion client for the Hyperion Ecosystem — monitor and remotely control your Hyperion instances and their plugins from any device.
</p>

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter&logoColor=white" />
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3-0175C2?logo=dart&logoColor=white" />
  <img alt="Platforms" src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows%20%7C%20Linux-blueviolet" />
  <img alt="License" src="https://img.shields.io/badge/license-CC%20BY--NC--ND%204.0-lightgrey" />
</p>

---

## About

Hyperion is a modular platform that acts as a universal client for external services and APIs. It runs on a desktop or server and connects, manages and automates work against other systems (web services, platforms, local APIs) through a plugin-based architecture. Each Hyperion instance hosts multiple plugins, while the core platform provides unified control, state management and security.

**Hyperion Mobile** is the companion app for monitoring and controlling those instances remotely. It is *not* a generic REST client and does not let you author API requests — it is a control panel for live Hyperion deployments.

### What you can do

- Sign in to your Hyperion account (email/password, Google, or biometrics)
- Discover Hyperion instances running on your devices
- Inspect every plugin per instance and its health
- Enable or disable plugins remotely
- Manage active sessions on your account
- Edit profile, avatar, and delete the account if needed

### Comparable products

Conceptually related, but each handles a single backend:

- **Portainer Mobile** — Docker container monitoring
- **Grafana Mobile** — observability dashboards
- **Firebase Console** — project overview
- **UptimeRobot** — service health monitoring

Hyperion Mobile differs in that it controls a plugin-driven backend rather than a fixed product, supports multiple instances across multiple machines, and provides remote *control*, not just read-only monitoring.

---

## Tech stack

| Layer | Used |
|---|---|
| Framework | Flutter / Dart |
| State | `ChangeNotifier` + lightweight scopes (`AuthScope`, `BiometricScope`, `PluginScope`) |
| Networking | `http` |
| Auth | Native `google_sign_in` (Android), custom PKCE loopback OAuth (desktop), `local_auth` for biometrics |
| Storage | `flutter_secure_storage` |
| Audio | `audioplayers` |
| Desktop tray | `tray_manager` (Windows / Linux / macOS) |

---

## Project layout

```
lib/
├── auth/              Authentication state, API, and Google flows
├── biometric/         Local-authentication service and notifier
├── common/            Shared widgets and utilities
├── config/            API base URLs (overridable at build time)
├── devices/           Devices/instances API client
├── plugins/           Plugin settings, scope, persistence
├── profile/           MVVM profile page (avatar, sessions, edit, delete, upload logs)
├── logging/           Centralised file + console logger
├── sound/             Click-sound service
├── widgets/           Reusable widgets (error/retry, etc.)
├── app_theme.dart     Centralised colours, radii, gradients
├── base_page.dart     Background gradient + falling-light layer
├── main.dart          Entry point, scopes, navigation
├── auth_page.dart     Sign-in / sign-up / reset-password
├── device_page.dart   List of Hyperion instances
├── instance_plugins_page.dart   Per-instance plugin management
└── profile_page.dart  Profile shell
```

Additional supporting directories:

- `android/`, `ios/`, `web/`, `windows/`, `linux/` — platform-specific projects
- `assets/` — bundled assets (audio, etc.)
- `scripts/` — convenience launchers for local development
- `fastlane/metadata/android/` — Google Play store metadata and changelogs
- `docs/` — operational documentation (CI/CD, release notes)

---

## Getting started

### Prerequisites

- Flutter SDK **3.41+** (`flutter --version` to verify)
- For Android: Android Studio with SDK 33 + JDK 17
- For desktop: platform toolchain per Flutter docs

### Clone & install

```bash
git clone https://github.com/IoannTerrible/Hyperion.Flutter.git
cd Hyperion.Flutter
flutter pub get
```

### Run

Use the helper scripts in `scripts/` or invoke Flutter directly. All build commands require dart-defines for backend URLs and OAuth client IDs (see below).

```powershell
# Local development against the production backend (PowerShell):
scripts\run-android.ps1
scripts\run-windows.ps1
```

Or manually:

```bash
flutter run \
  --dart-define=AUTH_BASE_URL=https://hyperion.techteastudio.cc/auth \
  --dart-define=DEVICES_BASE_URL=https://hyperion.techteastudio.cc/mobileapi \
  --dart-define=PLUGIN_BASE_URL=https://hyperion.techteastudio.cc/plugins \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-oauth-client-id>
```

### Configuration via `--dart-define`

| Variable | Used on | Purpose |
|---|---|---|
| `AUTH_BASE_URL` | All platforms | Base URL of the Hyperion auth service |
| `DEVICES_BASE_URL` | All platforms | Base URL of the mobile API |
| `PLUGIN_BASE_URL` | All platforms | Base URL of the plugin service |
| `GOOGLE_SERVER_CLIENT_ID` | Android | Web OAuth client ID used as the token audience |
| `GOOGLE_DESKTOP_CLIENT_ID` | Windows / Linux / macOS | Desktop OAuth client ID for the loopback PKCE flow |
| `GOOGLE_DESKTOP_CLIENT_SECRET` | Windows / Linux / macOS | Matching client secret (required by Google for desktop client type) |

Defaults are baked in for local development. Production builds always pass these explicitly through CI.

---

## Building for release

### Android App Bundle

```bash
flutter build appbundle --release \
  --dart-define=AUTH_BASE_URL=... \
  --dart-define=DEVICES_BASE_URL=... \
  --dart-define=PLUGIN_BASE_URL=... \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=...
```

Signing config is read from `android/key.properties` (see `android/key.properties.template`).

### Web

```bash
flutter build web --release --base-href /flutter/ \
  --dart-define=AUTH_BASE_URL=... \
  --dart-define=DEVICES_BASE_URL=... \
  --dart-define=PLUGIN_BASE_URL=... \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=...
```

### Desktop (Windows example)

```bash
flutter build windows --release \
  --dart-define=AUTH_BASE_URL=... \
  --dart-define=DEVICES_BASE_URL=... \
  --dart-define=PLUGIN_BASE_URL=... \
  --dart-define=GOOGLE_DESKTOP_CLIENT_ID=... \
  --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=...
```

---

## CI / CD

Two GitHub Actions workflows live in `.github/workflows/`:

| Workflow | Trigger | What it does |
|---|---|---|
| `release-google-play.yml` | push to `product` | Builds the AAB, signs it, uploads to the internal track on Google Play. Requires a release tag `vX.Y.Z` to exist on the commit. |
| `deploy-web.yml` | push to `web` | Builds the web bundle, packages it into a Docker image, pushes to GHCR, and deploys the new image to the production server over SSH. |

Push to `main` triggers nothing — it is the development branch. See [docs/google-play-cicd.md](docs/google-play-cicd.md) for the full release procedure and the secrets each workflow expects.

---

## Versioning

Version lives in `pubspec.yaml` as `version: X.Y.Z+N`:

- `X.Y.Z` is the semantic version shown in app stores
- `+N` is the build number (Android `versionCode` / iOS `CFBundleVersion`) — monotonically increasing, never reset

Bump rules:

- Bug fix → `Z + 1`
- New feature → `Y + 1` (reset `Z = 0`)
- Breaking change → `X + 1` (reset `Y = Z = 0`)
- `N` always `+ 1`

Commit format is `v<X.Y.Z> <short description>`. The corresponding lightweight tag is created manually before pushing to `product`.

---

## License

This project is licensed under [Creative Commons Attribution–NonCommercial–NoDerivatives 4.0 International](LICENSE) (CC BY‑NC‑ND 4.0).

---

<p align="center">
  Built with Flutter as part of the Hyperion Ecosystem by <a href="https://techteastudio.cc">TechTeaStudio</a>.
</p>
