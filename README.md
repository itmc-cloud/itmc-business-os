# itmc_estimator

App name shown to users: **ITMC Bussines OS**. (`itmc_estimator` is this
repo's internal package/project name — it's independent of the user-facing
app name and Play Store listing title.)

A local-first Flutter app for software/development service businesses:
manage clients, a reusable service-price catalog, cost estimates, and
invoices — with PDF export and a share sheet. No login, no backend; data
lives on-device (SQLite).

This repo is also meant as a **boilerplate for future projects** — the
project structure, local-DB pattern, PDF export, and Google Play release
pipeline (Docker + Fastlane + GitHub Actions) are all reusable as-is.

**New to this project? Start here → [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)**
— one linear checklist from installing Flutter through publishing on Google
Play. Everything below is the same information split into reference docs.

**Want the full picture in one place (architecture diagrams, CI/CD flow, and
a checklist for reusing this whole repo as a template for a new project)?
→ [docs/FULL_GUIDE.md](docs/FULL_GUIDE.md)**

## Structure

```text
lib/
  models/      Client, ServiceCatalogItem, Estimate, Invoice, LineItem
  db/          sqflite-backed DbHelper (CRUD, one table per model)
  providers/   ChangeNotifier providers wrapping DbHelper for state mgmt
  pdf/         PDF generation for estimates/invoices
  screens/     Clients, Catalog, Estimates, Invoices UI
docs/
  GETTING_STARTED.md   Start here — full checklist, setup to publish
  FULL_GUIDE.md   Everything in one place + diagrams + template-reuse checklist
  RUNNING.md      Local dev/test setup, golden-path test script
  PUBLISHING.md   Google Play release setup — what's automated vs. one-time manual
  store-listing-answers.md   Answer key for the content rating + data safety forms
  privacy-policy.md   Hosted via GitHub Pages; linked from the Play listing
  images/         Architecture and CI/CD diagrams
fastlane/
  metadata/android/en-US/   Store listing text, changelog, icon/feature graphic,
                            screenshots — all pushed automatically, nothing
                            typed into Play Console by hand
scripts/
  capture_screenshots.sh          Auto-captures Play Store screenshots via adb
  generate_placeholder_graphics.ps1   Generates a placeholder icon/feature graphic
.github/workflows/release.yml   CI: build signed .aab + upload on tag push
Dockerfile        Reproducible release-build image (not needed for local dev)
legacy-appcreator24/   The original AppCreator24-built .aab, kept for reference
```

## Getting started (local development)

```bash
flutter pub get
flutter run
```

Requires Flutter (stable channel) and the Android SDK — run `flutter doctor`
to confirm your environment is ready. **This app requires an Android
emulator or physical device** — it won't work correctly on the Windows
desktop or web targets (see below). See [docs/RUNNING.md](docs/RUNNING.md)
for full setup, emulator/device instructions, and a golden-path test script.

## Publishing to Google Play

Binary, store listing text, icon/feature graphic, and screenshots are all
pushed automatically — including screenshots, which are captured by
`scripts/capture_screenshots.sh` driving an emulator via `adb`, not taken by
hand. See [docs/PUBLISHING.md](docs/PUBLISHING.md) for the one-time setup
(Play Console app creation, signing key, Google Cloud service account, CI
secrets — a short list of things Google requires a human to do exactly
once; everything else is automated). Once that's done, shipping a release is
just:

```bash
git tag v1.0.1 && git push origin v1.0.1
```
