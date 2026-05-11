# Google Play CI/CD

Pipeline: [.github/workflows/release-google-play.yml](../.github/workflows/release-google-play.yml)

## Trigger

Runs **only** on push to the `product` branch. Pushes to `main`, feature branches, or tags do nothing.

## Release model

The pipeline uses **tag-as-gate**: the tag `v<X.Y.Z>` (lightweight, version from `pubspec.yaml`) is the **manual release authorisation**. You create it by hand; CI only checks for it.

| Tag state when product is pushed | What happens |
|---|---|
| Tag `vX.Y.Z` does **not** exist | Workflow exits cleanly. No build, no upload. Green run with a message telling you which tag to create. |
| Tag `vX.Y.Z` exists | Workflow builds the AAB, signs it, uploads to Play Console internal track. **Never** creates or pushes tags. |

The pubspec version (`version: X.Y.Z+N`) is the single source of truth — both the tag name and the duplicate check derive from it.

### Duplicate protection

- Re-pushing `product` with the same pubspec version sees the same tag → tries to re-upload → Google Play rejects the duplicate `versionCode` and the workflow fails loudly.
- To **intentionally** re-release the same code, bump `pubspec.yaml` and create a new tag.

## Release procedure (every time)

```bash
# 1. On main: bump version in pubspec.yaml, commit your work.
#    e.g. version: 2.5.0+19 → 2.5.1+20

# 2. Merge to product.
git checkout product
git merge main

# 3. Create the lightweight release tag.
git tag v2.5.1

# 4. Push tag FIRST, then the branch.
git push origin v2.5.1
git push origin product
```

The branch push triggers CI; CI sees the tag is already on origin → release proceeds.

If you push the branch before the tag, CI runs once and skips (tag missing). Push the tag, then push the branch again (or use `git push --force-with-lease` on a no-op commit, or re-run the workflow manually from the Actions tab).

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
4. Google Play Console → Settings → **API access** → link the GCP project → invite the service account.
5. Grant **App permissions** on `cc.techteastudio.hyperion` only, with role **Release manager** (or "Admin").
6. Paste the JSON file contents verbatim into the `PLAY_SERVICE_ACCOUNT_JSON` secret.

## Notes

- Release lands on the **internal** track. To promote it to closed/open/production, do it from the Play Console or change `track:` in the workflow.
- Release notes are NOT uploaded from CI — fill them in manually in the Play Console, matching the `<en-US> / <ru-RU>` blocks.
- `permissions: contents: read` — CI has no write access to the repo. It cannot create commits, tags, branches, or releases.
- Lightweight tags only (`git tag v2.5.1`, no `-a`, no `-m`).
- `concurrency: google-play-release` serialises runs, so two pushes to `product` cannot race on the same `versionCode`.

## First-time checklist

- [ ] Create the `product` branch (`git checkout -b product && git push -u origin product`).
- [ ] Add all 5 secrets above.
- [ ] Make sure the **versionCode** in `pubspec.yaml` (`+N`) is **strictly greater** than the highest versionCode ever uploaded to that Play app — Google rejects re-used codes.
- [ ] Have an initial release already created in Play Console (the API can't create the very first release; subsequent ones are fine).
- [ ] Branch-protect `product` so only deliberate merges trigger releases.
