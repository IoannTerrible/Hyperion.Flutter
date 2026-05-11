# Changelog

All notable changes to the **Hyperion Flutter** client (mobile + desktop) are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows `MAJOR.MINOR.PATCH+BUILD` from `pubspec.yaml` — `+BUILD` is the monotonic Android `versionCode` / iOS `CFBundleVersion` and is **never reset**.

---

## [2.4.0+18] — 2026-05-11

### Added
- **Google Sign-In** on Android (native `google_sign_in` plugin with `serverClientId`) and Windows/Linux/macOS desktop (loopback OAuth + PKCE via a temporary `127.0.0.1:<random>` HTTP server). iOS is intentionally not part of this release.
- Three-state Google flow matches the backend contract:
  - **Success** → log in immediately.
  - **Account exists, password required** → `GoogleLinkPage` asks for the existing password before linking the Google identity.
  - **Registration requires username** → `GoogleUsernamePage` lets the user pick a unique username before the account is created.
- New API client methods in `lib/auth/auth_api.dart`: `postGoogleLogin`, `postGoogleLink`, `postGoogleCompleteRegistration`, plus `GoogleSignInResult` / `GoogleSignInStatus` DTOs.
- `GoogleIdTokenProvider` abstraction with platform implementations:
  - `AndroidGoogleIdTokenProvider` — uses `google_sign_in: ^6.2.1`
  - `DesktopGoogleIdTokenProvider` — loopback PKCE flow on Windows / Linux / macOS
- `--dart-define` knobs in `ApiConfig`:
  - `GOOGLE_SERVER_CLIENT_ID` — the Web client id (audience) used by Android
  - `GOOGLE_DESKTOP_CLIENT_ID` / `GOOGLE_DESKTOP_CLIENT_SECRET` — desktop OAuth client

### Changed
- `AuthService` interface gained `googleSignIn`, `linkGoogleAccount`, `completeGoogleRegistration`. Test fakes updated.
- `AuthNotifier` wraps each Google method with the same isLoading / lastError lifecycle as `signIn` / `register`.
- `lib/auth_page.dart` now renders a "Sign in with Google" button below the password row.

---

## [2.3.3+17] — 2026-05-01
- Add bottom safe area inset below navbar.

## [2.3.2+?] — 2026-05-01
- Page perf — cache base-page blur, lazy-keep-alive tabs, isolate tiles.

## [2.3.1+?] — 2026-05-01
- Liquid glass navbar performance — isolate blur layer, halve sigma.

## [2.3.0+?] — 2026-04-30
- Custom liquid glass nav bar with sliding bubble + shimmer.

## [2.2.3+?] — 2026-04-30
- Use `AppTheme` constants in liquid glass navbar.

## [2.2.2+?] — 2026-04-30 (2nd)
- Liquid glass bottom nav bar with blur and glass rim.

## [2.2.1+?] — 2026-04-30 (2nd)
- Refactor `profile_page` into `lib/profile/` with MVVM controllers.

## [2.2.2+?] — 2026-04-30
- Fix `AssetSource` path for `audioplayers` `assets/` convention.

## [2.2.1+?] — 2026-04-30
- Fix click sound not playing on Windows.

## [2.2.0+?] — 2026-04-30
- Button click sound + fix white flash on transitions.

## [2.1.1+?] — 2026-04-30
- Persist reset-password step across app switches.

## [2.1.0+?] — 2026-04-29
- Device page, biometric sign-in, bug fixes.

## Pre-versioned commits

| Date | Subject |
|---|---|
| 2026-04-25 | CICD Actions |
| 2026-04-20 | Biometric Sign In |
| 2026-04-17 | Biometric Auth |
| 2026-04-03 | Fix device page |
| 2026-04-02 | fix: Devices Info |
| 2026-03-26 | Deploy Update |
| 2026-03-10 | Fallback to http from https |
| 2026-03-10 | Auth Error Catches |
| 2026-03-05 | Device Segregation |
| 2026-02-24 | Device API integration |
| 2026-02-24 | AuthPage Fix |
| 2026-02-17 | AuthPage |
| 2026-02-12 | Theme things |
| 2026-02-10 | Delete Demo from repository |
| 2026-02-10 | UpdateHome Application |
| 2026-02-10 | SandBox Demo |
| 2026-02-10 | NavBar |
| 2026-02-09 | Flutter installation and app design |
| 2026-02-05 | Remove catalog |
| 2026-02-05 | Update License |
| 2026-02-05 | Rename |
| 2026-02-05 | Fix gitignore and remove ignored files |
| 2026-02-05 | Initial commit |
