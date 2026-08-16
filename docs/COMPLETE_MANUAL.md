# Complete Manual — ITMC Bussines OS

One self-contained, start-to-finish walkthrough: installing Flutter, what
this project is made of, running it, building/exporting it, the git
tag/release workflow, and everything involved in getting it onto Google
Play. Other docs in this folder go deeper on specific parts (see
[docs/README.md](README.md) for the full index) — this one exists so you
never have to jump between files to get from zero to published.

## Table of contents

1. [What this project is](#1-what-this-project-is)
2. [Install the development environment](#2-install-the-development-environment)
3. [Project components (architecture)](#3-project-components-architecture)
4. [Get it running locally](#4-get-it-running-locally)
5. [Building / exporting artifacts](#5-building--exporting-artifacts)
6. [Branching model & CI quality gate](#6-branching-model--ci-quality-gate)
7. [One-time Google Play setup](#7-one-time-google-play-setup)
8. [Fastlane lanes reference](#8-fastlane-lanes-reference)
9. [The tag / release workflow](#9-the-tag--release-workflow)
10. [Google Play Console manual forms](#10-google-play-console-manual-forms)
11. [Ongoing release checklist (cheat sheet)](#11-ongoing-release-checklist-cheat-sheet)
12. [Troubleshooting / lessons learned](#12-troubleshooting--lessons-learned)

---

## 1. What this project is

**ITMC Bussines OS** (Dart package `itmc_estimator`, Android package
`com.itmc.itmc_estimator`) is a local-first Flutter app for a
software/development service business: manage clients, a reusable
service-price catalog, cost estimates, and invoices, with PDF export. No
login, no backend — everything lives on-device via `sqflite`.

Beyond the app itself, this repo is a working example of a **fully
automated Google Play release pipeline**: tag a version, and CI builds,
signs, and uploads the binary plus the entire store listing (text, icon,
feature graphic, screenshots) with zero manual Play Console form-filling
for anything recurring. The only manual work is a set of one-time,
Google-mandated human declarations (§7 and §10) — no tool, including
Google's own CLI, can script around those.

---

## 2. Install the development environment

You need three things: the Flutter SDK, the Android SDK, and one Android
emulator (or a physical phone).

1. **Flutter SDK:**
   ```bash
   git clone -b stable https://github.com/flutter/flutter.git
   ```
   into some folder (e.g. `C:\src\flutter`), then add its `bin` folder to
   your PATH.
2. **Android SDK:** install [Android Studio](https://developer.android.com/studio)
   (it bundles the SDK), or just the SDK command-line tools if you don't
   want the full IDE.
3. Run `flutter doctor -v` and follow whatever it flags — usually just
   accepting Android licenses:
   ```bash
   flutter doctor --android-licenses
   ```
4. Create at least one Android emulator via Android Studio's Device
   Manager, or:
   ```bash
   flutter emulators --create
   ```
5. Confirm everything's green:
   ```bash
   flutter doctor
   ```
   should report "No issues found!".

You also need **Ruby + Bundler** (Fastlane runs on Ruby) if you intend to
run release lanes locally rather than only through CI — see §8. CI
installs this for you automatically, so it's not required just to develop
the app.

---

## 3. Project components (architecture)

```text
lib/
  screens/        UI, one folder per feature area (clients, catalog,
                   estimates, invoices), each with a list screen + form
                   screen (+ detail screen for estimates/invoices)
  providers/       One ChangeNotifier per entity, wrapping DbHelper.
                   Screens read/write through these via the `provider`
                   package — no screen talks to the database directly.
  db/db_helper.dart  A sqflite singleton: schema + CRUD for all 4 tables
                   (clients, service_catalog, estimates, invoices).
                   Estimates/invoices store line items as a JSON column
                   rather than a separate table.
  pdf/pdf_generator.dart  Pure function, bytes in (estimate/invoice +
                   client) → bytes out (PDF). Screens call
                   Printing.sharePdf with those bytes to hand off to
                   Android's native share sheet.
  models/          Plain Dart classes, no codegen. toMap/fromMap for
                   direct-column models (Client), toJson/fromJson for the
                   embedded line-items list.

android/                      Flutter's generated Android project
  app/build.gradle.kts        Signing config reads android/key.properties
                               (git-ignored)
  key.properties.example      Template — copy to key.properties, fill in
                               real values

fastlane/
  Appfile                     package_name + json_key_file path
  Fastfile                    Lanes — see §8
  metadata/android/en-US/     Store listing text, changelog, icon/feature
                               graphic, screenshots — this whole folder
                               is what gets pushed to Play Console
                               automatically
  play-service-account.json   Google Cloud service account key
                               (git-ignored, not in repo)

scripts/
  capture_screenshots.sh          Auto-captures Play Store screenshots
                                   via adb (no manual screenshotting)
  generate_placeholder_graphics.ps1  Generates a placeholder icon/feature
                                   graphic

.github/workflows/
  ci.yml         Lint/test/build gate — runs on push to dev, PRs into main
  release.yml    Build+sign+upload — runs on version tags (any branch),
                  or manual dispatch — see §9

Dockerfile       Reproducible release-build image (not needed day-to-day)

docs/            This documentation set — see docs/README.md for the index
```

Full architecture diagram and rationale: [FULL_GUIDE.md, §2](FULL_GUIDE.md#2-architecture).

---

## 4. Get it running locally

```bash
flutter pub get
flutter emulators                              # list configured emulators
flutter emulators --launch <emulator-id>       # or plug in a phone via USB
flutter run
```

**This app cannot be meaningfully tested on Windows desktop or web
targets** — it uses `sqflite` for local storage, which only has real
(non-stub) implementations on Android/iOS/macOS. `flutter run -d windows`
will build, but every database call fails at runtime.

Once running, the golden-path manual test is: add a catalog item → add a
client → create an estimate for that client, add a line item from the
catalog, confirm the live total → export its PDF → convert it to an
invoice → change the invoice status → export that PDF too → restart the
app and confirm everything persisted. Full script with exact steps:
[RUNNING.md](RUNNING.md#what-to-actually-test-golden-path).

```bash
flutter analyze
flutter test
```

runs static analysis and the automated test suite.

---

## 5. Building / exporting artifacts

```bash
flutter build apk --debug        # sideload-able debug APK
flutter build apk --release      # release APK (debug-signed until §7.2 is done)
flutter build appbundle --release   # .aab — what Google Play actually wants
```

Output lands under `build/app/outputs/`. You will rarely run these by
hand for a real release — the CI pipeline (§9) does it for you — but
they're useful for a local sanity check, or for sideloading a debug build
onto a test device without touching Play Console at all.

Screenshots for the store listing are also generated, not hand-captured:

```bash
export PATH="$LOCALAPPDATA/Android/Sdk/platform-tools:$PATH"   # if adb isn't on PATH
scripts/capture_screenshots.sh
```

This taps through each bottom-nav tab (via the accessibility tree, not
hardcoded coordinates) and saves one screenshot per tab into
`fastlane/metadata/android/en-US/images/phoneScreenshots/`.

---

## 6. Branching model & CI quality gate

- **`main`** — production. Only receives merges (via PR) and release tags.
- **`dev`** — where ongoing work happens. Push here for day-to-day changes.
- **`ci.yml`** — runs `flutter analyze` / `flutter test` / `flutter build
  apk --debug` on every push to `dev` and every PR into `main`. A quality
  gate, separate from publishing — it never touches Play Console.

Normal flow: work on `dev` → open a PR into `main` → CI passes → merge →
tag a release from `main` (§9).

---

## 7. One-time Google Play setup

Everything in this section is done **once per app**, ever. After it's
done, every future release is fully automated (§9).

### 7.1 Host the privacy policy

Enable GitHub Pages (repo Settings → Pages → branch `main`, folder
`/docs`) — this app's policy is already written at
[docs/privacy-policy.md](privacy-policy.md) and live at
`https://<org>.github.io/<repo>/privacy-policy.html`. Editing that file
and pushing to `main` updates the live page automatically from then on.

### 7.2 Generate your app signing key

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keep `upload-keystore.jks` **outside** the repo (it's git-ignored on
purpose) — losing it means you can never update the app again under this
listing. For local release builds, copy
`android/key.properties.example` → `android/key.properties` and fill in
the real `storePassword`/`keyPassword`/`keyAlias` values. CI never uses
this file directly — it reconstructs it from a secret (§7.4).

### 7.3 Connect Google Cloud to Play Console (service account)

This is the credential the automated pipeline uses to authenticate as
you.

1. **Create a Google Cloud project** — [console.cloud.google.com](https://console.cloud.google.com/)
   → project dropdown → "New Project".
2. **Enable the Play Developer API** — "APIs & Services" → "Library" →
   search "Google Play Android Developer API" → "Enable".
3. **Create the service account + key** — "IAM & Admin" → "Service
   Accounts" → "Create Service Account" → name it (e.g. `play-publisher`)
   → skip role assignment (permissions are granted from Play Console
   instead) → open it → "Keys" tab → "Add Key" → "Create new key" → JSON.
   Save the downloaded file as `fastlane/play-service-account.json`
   (already git-ignored — never commit it).
4. **Grant it access in Play Console** — "Users and permissions" →
   "Invite new users" → paste the service account's email (looks like
   `play-publisher@<project-id>.iam.gserviceaccount.com`) → assign at
   least "Release apps to testing tracks" (add production release
   permission too once ready) → "Invite user".

### 7.4 Create the app in Play Console (one-time, by hand)

No API can create a brand-new app listing — this is the one part Google
requires a human for.

1. Play Console → "Create app" → fill in name/language/type/free-or-paid.
2. Store listing text: copy-paste from `fastlane/metadata/android/en-US/`
   (already written).
3. Icon + feature graphic: already generated at
   `fastlane/metadata/android/en-US/images/` — swap for real branding
   whenever you have it, same filenames.
4. Screenshots: run `scripts/capture_screenshots.sh` first, use the
   images it produces.
5. Privacy policy URL: from §7.1.
6. Content rating, target audience, data safety, ads, health apps
   declarations: exact answers → [store-listing-answers.md](store-listing-answers.md),
   click path → [play-console-manual-steps.md](play-console-manual-steps.md).
7. Upload one build (Internal testing → Create release) to get the app
   out of draft state — the `.aab` from §5, or just push a tag (§9) and
   let CI do it.

### 7.5 Configure GitHub Actions secrets

Repo → Settings → Secrets and variables → Actions:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` (Windows: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))`) |
| `ANDROID_KEYSTORE_PASSWORD` | the `storePassword` from §7.2 |
| `ANDROID_KEY_ALIAS` | `upload` (or your alias) |
| `ANDROID_KEY_PASSWORD` | the `keyPassword` from §7.2 |
| `PLAY_SERVICE_ACCOUNT_JSON` | full contents of the service account JSON from §7.3 |

---

## 8. Fastlane lanes reference

[Fastlane](https://fastlane.tools/) automates the build/sign/upload part
of releasing, via the official Play Developer API — a legitimate
automation path, unlike driving the Play Console UI directly (§10).
Defined in `fastlane/Fastfile`:

| Lane | What it does |
| --- | --- |
| `build_release` | `flutter build appbundle --release` → produces the `.aab` |
| `screenshots` | Runs `scripts/capture_screenshots.sh` |
| `deploy_internal` | Builds + uploads the binary only to **Internal testing** (fast iteration, skips listing/images) |
| `promote_production` | Promotes the build already on Internal testing straight to **Production** — no rebuild, same binary/version code already tested. **The normal path.** Accepts `rollout: '0.1'` etc. (default `1.0`) |
| `deploy_production` | Builds a **fresh** binary and pushes it — plus the full listing, images, screenshots — directly to Production. Only when production should deliberately differ from internal, and only after bumping the build number (Play rejects re-uploading an existing version code on any track) |

Running a lane locally (debugging only, needs `android/key.properties`
and `fastlane/play-service-account.json` present):

```bash
bundle exec fastlane android <lane_name>
```

More detail: [FASTLANE.md](FASTLANE.md).

---

## 9. The tag / release workflow

Once §7 is done, `.github/workflows/release.yml` is what actually ships
builds — you never run Fastlane by hand for a real release.

**Everyday release → Internal testing**, triggered by pushing a version
tag:

```bash
# 1. bump the version (pubspec.yaml): version: 1.0.1+2
#    (the number before + is versionName, after + is versionCode —
#    versionCode must increase every single release, on any track)
# 2. add a changelog:
#    fastlane/metadata/android/en-US/changelogs/2.txt
# 3. (optional) refresh screenshots if the UI changed meaningfully:
scripts/capture_screenshots.sh
git add fastlane/metadata pubspec.yaml
git commit -m "Bump to 1.0.1+2"

# 4. tag and push:
git tag v1.0.1
git push origin v1.0.1 --tags
```

This tag push runs `deploy_internal` — builds, signs, uploads the binary
plus the current listing/images/screenshots to **Internal testing**.

**Promoting (or building fresh for) Production**, triggered manually —
GitHub → Actions tab → "Release to Google Play" → "Run workflow", or:

```bash
gh workflow run "Release to Google Play" --repo itmc-cloud/itmc-business-os -f track=<choice>
```

where `<choice>` is one of:

- **`internal`** — same as a tag push (`deploy_internal`).
- **`production`** — promotes the exact build already tested on internal,
  no rebuild (`promote_production`). **This is what you want after
  testing on internal**, and what was used to first get this app's
  production release into Google's review queue.
- **`production-fresh-build`** — builds and uploads a brand-new binary
  directly to production, skipping internal (`deploy_production`). Only
  use this if production must deliberately differ from what's on
  internal, and only after bumping the build number.

Either path uploads via the service account credential from §7.3 — no
manual Play Console interaction is needed for the binary or listing
content, ever again.

---

## 10. Google Play Console manual forms

The only remaining manual work, and only once per app (or once per
policy-relevant app change): the declarations Google requires a human to
click through, since they're legal attestations, not build artifacts.
Full click-by-click path for every screen (testers, countries/regions,
content rating, target audience, data safety, ads, health apps, creating
a production release, submitting for review) →
**[play-console-manual-steps.md](play-console-manual-steps.md)**.
Exact answer for every question, based on what this app actually does →
**[store-listing-answers.md](store-listing-answers.md)**.

Condensed version of what's involved:

1. **Content rating (IARC), target audience, data safety, ads, health
   apps** — Play Console → Monitor and improve → Policy and programs →
   App content. Each is a short questionnaire; for this app (no accounts,
   no network calls, no ads, nothing leaves the device) essentially every
   question is answered "No".
2. **Countries/regions** — Test and release → Production → Countries /
   regions tab → select where the app is available.
3. **Testers** (optional) — Test and release → Testing → Internal testing
   → Testers tab, only needed if you want a controlled testing group
   before production.
4. **Create the production release** — Test and release → Production →
   Releases tab → reuse the already-uploaded bundle ("Add from library")
   or upload a new one, fill in release notes.
5. **Submit for review** — Publishing overview → once every item is
   resolved, "Submit N changes for review" becomes enabled. This is the
   actual publish trigger; Google's review is typically within 7 days.
   With "Managed publishing" off, approval publishes automatically.

None of this can be done by any tool, automated or not — see
[play-console-manual-steps.md](play-console-manual-steps.md) for why, and
for exactly what to click.

---

## 11. Ongoing release checklist (cheat sheet)

Once §7 and §10 are done once, every future release is just:

- [ ] Bump `pubspec.yaml` version (`versionCode` must increase)
- [ ] Add `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`
- [ ] (optional) `scripts/capture_screenshots.sh` if the UI changed
- [ ] Commit, then `git tag vX.Y.Z && git push origin vX.Y.Z --tags`
      → ships to Internal testing automatically
- [ ] Test it there
- [ ] `gh workflow run "Release to Google Play" -f track=production`
      → promotes that exact build to Production, no rebuild

No Play Console form-filling required for any of the above.

---

## 12. Troubleshooting / lessons learned

Real issues hit while building this pipeline:

- **Google Play package names are permanent** — a typo means deleting and
  recreating the whole app. Always copy-paste the package name, never
  retype it.
- **Gradle's `file()` in `android/app/build.gradle.kts` resolves relative
  paths against `android/app/`, not the project root** — the signing
  keystore must be decoded to `android/app/` in CI, not `android/`.
- **Fastlane's working directory during lane execution shouldn't be
  assumed** — every path in `Fastfile` is anchored via
  `File.expand_path("..", __dir__)`, not a relative path that happened to
  work interactively.
- **Google removed the old "link a Cloud project" page** — service
  accounts now get Play Console access the same way a human teammate
  would, via "Users and permissions" → "Invite new users".
- **GitHub Actions redacts every occurrence of a secret's literal value
  in logs** — if a secret's value is a common word (e.g. `upload`),
  unrelated log lines containing that word get partially redacted too.
  Cosmetic only.
- **Antivirus HTTPS-scanning (e.g. Avast) can break Gradle's dependency
  downloads on Windows** — fix in your own `~/.gradle/gradle.properties`
  (a per-machine file, never commit this into a shared project).
- **A pasted/attached chat image isn't automatically a file on disk** —
  save it to an actual path first if a tool needs to read it.
- **Don't re-run a production promotion while a release is already "in
  review"** in Publishing overview — it can conflict with the
  in-flight submission. Wait for Google's review to resolve first.

Full detail and the "reuse this repo as a template for a new app"
checklist: [FULL_GUIDE.md](FULL_GUIDE.md).
