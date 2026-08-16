# Fastlane — what it is and how it's used here

[Fastlane](https://fastlane.tools/) automates mobile release tasks —
building, signing, and uploading to app stores — as scriptable "lanes"
instead of manual clicking through a console. It talks to Google Play
through the official Play Developer API, using the service account
credentials set up in [PUBLISHING.md](PUBLISHING.md#4-connect-google-cloud-to-play-console-service-account--api-access) —
this is a legitimate, Google-sanctioned automation path, unlike driving
the Play Console UI directly (which Google doesn't offer an API for, see
[play-console-manual-steps.md](play-console-manual-steps.md)).

## Where it lives in this repo

- `fastlane/Appfile` — the app's `package_name` and the path to the
  service account JSON key (`play-service-account.json`, git-ignored).
- `fastlane/Fastfile` — the lane definitions (below).
- `fastlane/metadata/android/en-US/` — everything Fastlane pushes to the
  store listing: title, descriptions, changelog, icon, feature graphic,
  screenshots. Edit these files directly to change the listing; Fastlane
  reads them, you don't type anything into Play Console.

## The lanes

| Lane | What it does |
| --- | --- |
| `build_release` | `flutter build appbundle --release` → produces the `.aab` |
| `screenshots` | Runs `scripts/capture_screenshots.sh` to auto-capture Play Store screenshots from a running emulator/device |
| `deploy_internal` | Builds + uploads the binary only to the **Internal testing** track (fast iteration, skips listing/images) |
| `promote_production` | Promotes the build already sitting on Internal testing straight to **Production** — no rebuild, same binary/version code already tested. **This is the normal path.** Accepts `rollout: '0.1'` etc. for a staged rollout (default full `1.0`) |
| `deploy_production` | Builds a **fresh** binary and pushes it — plus the full store listing, images, and screenshots — directly to Production. Only use this when production should deliberately differ from what's on internal, and only after bumping the build number in `pubspec.yaml` (Play rejects re-uploading a version code that already exists on any track) |

Source of truth for exact behavior: `fastlane/Fastfile`.

## How releases actually trigger these lanes

You don't normally run Fastlane directly — `.github/workflows/release.yml`
does, triggered one of two ways:

**Tag push → Internal testing** (`deploy_internal`):
```bash
git tag v1.0.1
git push origin v1.0.1 --tags
```

**Manual dispatch → any track**, e.g. to promote to production:
```bash
gh workflow run "Release to Google Play" --repo itmc-cloud/itmc-business-os -f track=production
```
(GitHub → Actions tab → "Release to Google Play" → "Run workflow" works
the same way from the UI.) `track=production` runs `promote_production`.

## Running a lane locally (debugging only)

```bash
bundle exec fastlane android <lane_name>
```

from the repo root. Requires, locally, the two files that are git-ignored
on purpose and only ever injected as CI secrets normally:
- `android/key.properties` (signing config — see
  [PUBLISHING.md, step 3](PUBLISHING.md#3-generate-your-app-signing-key))
- `fastlane/play-service-account.json` (Play Developer API credential —
  see [PUBLISHING.md, step 4](PUBLISHING.md#4-connect-google-cloud-to-play-console-service-account--api-access))

Never commit either file.
