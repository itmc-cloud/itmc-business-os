# Getting Started — From Zero to Published on Google Play

One linear checklist covering the whole lifecycle: setting up your machine,
running the app, and publishing it to Google Play. Each phase links to a
deeper doc for detail — but you can follow just this page top to bottom and
not get lost. Do the phases in order; later ones depend on earlier ones.

## Phase 0 — What you're building

A Flutter app (`itmc_estimator`) for quoting/invoicing a service business:
clients, a service-price catalog, cost estimates, invoices, PDF export. It
runs entirely on-device (no login, no server) and is set up to publish to
Google Play with almost everything automated — building, signing,
uploading, store listing text, and even screenshots.

## Phase 1 — Install the development environment

You need three things: the Flutter SDK, the Android SDK, and one Android
emulator (or a physical phone). If you're on the same machine this was set
up on, skip to Phase 2 — it's already done here.

On a fresh machine:

1. **Flutter SDK:** `git clone -b stable https://github.com/flutter/flutter.git`
   into some folder (e.g. `C:\src\flutter`), then add its `bin` folder to
   your PATH.
2. **Android SDK:** install [Android Studio](https://developer.android.com/studio)
   (it bundles the SDK), or install just the SDK command-line tools if you
   don't want the full IDE.
3. Run `flutter doctor -v` and follow whatever it flags — usually just
   accepting Android licenses (`flutter doctor --android-licenses`).
4. Create at least one Android emulator via Android Studio's Device
   Manager, or `flutter emulators --create`.
5. Confirm everything's green: `flutter doctor` should say
   "No issues found!".

## Phase 2 — Run the app locally

```bash
flutter pub get
flutter emulators --launch <your-emulator-id>   # or plug in a phone via USB
flutter run
```

Full detail, golden-path manual test script, and why this app specifically
needs an Android target (not Windows/web) → **[docs/RUNNING.md](RUNNING.md)**.

## Phase 3 — Build a release artifact

```bash
flutter build appbundle --release
```

This is the `.aab` file Google Play actually wants (not an `.apk`). It'll
work with debug signing until Phase 4 is done — fine for a first test
upload, not for anything you intend to keep live.

## Phase 4 — Generate your app signing key

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keep this file **outside** the repo, somewhere safe — losing it means you
can never update the app again under the same listing. Copy
`android/key.properties.example` → `android/key.properties` and fill in the
real values for local release builds.

## Phase 5 — Connect Google Cloud to Play Console

This is the credential the automation uses to upload on your behalf.
Four parts: create a Cloud project → enable the Play Developer API →
create a service account + JSON key → link it in Play Console.

Full click-by-click walkthrough → **[docs/PUBLISHING.md, step 4](PUBLISHING.md#4-connect-google-cloud-to-play-console-service-account--api-access)**.

## Phase 6 — Create the app in Play Console (one-time, by hand)

This is the one part Google requires a human to do — no API can create a
brand-new app listing. Everything you need is already written for you:

1. Play Console → "Create app" → fill in name/language/type.
2. Store listing text: copy-paste from `fastlane/metadata/android/en-US/`
   (title, short/full description already written for this app).
3. Icon + feature graphic: already generated at
   `fastlane/metadata/android/en-US/images/` (placeholders — swap for real
   branding whenever you have it, same filenames).
4. Screenshots: run `scripts/capture_screenshots.sh` first (see
   [docs/RUNNING.md](RUNNING.md#capturing-play-store-screenshots-no-manual-screenshotting))
   and use the images it produces.
5. Privacy policy URL: enable GitHub Pages once (repo Settings → Pages →
   deploy from `main` /docs) and use the resulting URL to
   `docs/privacy-policy.md`.
6. Content rating questionnaire + Data safety form: exact answer for every
   question → **[docs/store-listing-answers.md](store-listing-answers.md)**.
7. Upload one build (Internal testing → Create release) to get the app out
   of draft state — the `.aab` from Phase 3.

Full detail → **[docs/PUBLISHING.md](PUBLISHING.md)**.

## Phase 7 — Configure GitHub Actions secrets

Repo → Settings → Secrets and variables → Actions, add 5 secrets (keystore,
its passwords/alias, and the service account JSON from Phase 5). Exact list
→ **[docs/PUBLISHING.md, step 5](PUBLISHING.md#5-configure-github-actions-secrets)**.

## Phase 8 — Publish

Once Phases 1–7 are done once, every release is just:

```bash
scripts/capture_screenshots.sh        # optional: refresh screenshots if UI changed
git add fastlane/metadata && git commit -m "Update screenshots"

git tag v1.0.1
git push origin v1.0.1 --tags
```

The tag push triggers CI (`.github/workflows/release.yml`), which builds
the signed `.aab` and uploads it — plus the current listing text, images,
and screenshots — to the **internal testing** track automatically. From
there:

- Promote internal → production from Play Console once you've tested it, or
- Trigger the workflow manually (GitHub → Actions tab → "Release to Google
  Play" → "Run workflow") and pick `production` directly.

## Phase 9 — Every update after that

Bump the version in `pubspec.yaml` (`version: 1.0.1+2` — the number after
`+` is the build number, must increase every release), add a changelog file
at `fastlane/metadata/android/en-US/changelogs/<build-number>.txt`, then
repeat Phase 8's tag-and-push. That's the entire release process, forever.
