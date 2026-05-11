# Google Play CI/CD

Pipeline: [.github/workflows/release-google-play.yml](../.github/workflows/release-google-play.yml)

## Trigger

Runs **only** on push to the `product` branch. Pushes to `main`, feature branches, or tags do nothing.

## What it does

1. Reads `version: X.Y.Z+N` from `pubspec.yaml`.
2. Computes the tag `v<X.Y.Z>`.
3. **Skips the whole job** if that tag already exists locally or on `origin` — duplicate pushes are no-ops, no failed runs.
4. Decodes the upload keystore and writes `android/key.properties` from secrets.
5. Builds the release AAB (`flutter build appbundle --release`).
6. Uploads the AAB to Google Play's **internal** track via `r0adkll/upload-google-play`.
7. Creates a **lightweight** tag (`git tag v<X.Y.Z>`) and pushes it to `origin`.

So: bump the version in `pubspec.yaml`, merge into `product` → release happens, tag appears. Forget to bump → workflow runs but exits cleanly at step 3.

## Required GitHub Secrets

Settings → Secrets and variables → Actions → New repository secret.

| Secret | What it is | How to get it |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | The `.jks` keystore as a single base64 string | `base64 -w0 upload-keystore.jks` (Linux) or `[Convert]::ToBase64String([IO.File]::ReadAllBytes('upload-keystore.jks'))` (PowerShell) |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password | From `android/key.properties` (`storePassword`) |
| `ANDROID_KEY_PASSWORD` | Key password | `keyPassword` |
| `ANDROID_KEY_ALIAS` | Key alias | `keyAlias` (currently `hyperion`) |
| `PLAY_SERVICE_ACCOUNT_JSON` | Full JSON contents of a Google Play service-account key | See below |

### Generating `PLAY_SERVICE_ACCOUNT_JSON`

1. Google Cloud Console → IAM & Admin → Service Accounts → **Create service account**.
2. Grant it no project-level roles. Skip the optional "grant users access" step.
3. Open the new service account → **Keys** → **Add key** → **JSON**. Save the downloaded JSON.
4. Google Play Console → Setup → **API access** → link the GCP project → invite the service account.
5. Grant **App permissions** on `cc.techteastudio.hyperion` only, with role **Release manager** (or "Admin" if you want it to manage releases without restriction).
6. Paste the JSON file contents verbatim into the `PLAY_SERVICE_ACCOUNT_JSON` secret.

## Notes

- The release goes to the **internal** track. To promote it to closed/open/production, do it from the Play Console or change `track:` in the workflow.
- Release notes (what-the-user-sees) are NOT uploaded from CI — fill them in manually in the Play Console, matching the `<en-US> / <ru-RU>` blocks we keep in chat.
- The workflow uses the built-in `GITHUB_TOKEN` to push tags. No PAT needed because `permissions: contents: write` is granted at the top.
- Lightweight tag, not annotated: `git tag v2.3.3` (no `-a`, no `-m`).
- `concurrency: google-play-release` serialises runs, so two pushes to `product` won't try to upload the same `versionCode` simultaneously.

## First-time checklist

- [ ] Create the `product` branch (`git checkout -b product && git push -u origin product`).
- [ ] Add all 5 secrets above.
- [ ] Make sure the **versionCode** in `pubspec.yaml` (`+N`) is **strictly greater** than the highest versionCode ever uploaded to that Play app — Google rejects re-used codes.
- [ ] Have an initial release already created in Play Console (the API can't create the very first release; subsequent ones are fine).
- [ ] Branch protect `product` so only deliberate merges trigger it.
