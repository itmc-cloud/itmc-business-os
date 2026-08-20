# Play Store deploy template (portable — copy this file into any new project)

Everything in this file is written generically, with placeholders
(`<APP_NAME>`, `<PACKAGE_NAME>`, `<REPO>`) — it's meant to be copy-pasted
whole into a brand-new project's `docs/` folder, not just read here. It's
the full setup for the same pipeline this repo actually uses: GitHub
Actions → Fastlane → Google Play Developer API, one command per release,
plus the manual click-path for every step Google requires a human for
(there's no way around these — no tool, including Google's own CLI, can
script past a legal/policy attestation).

For this specific project's already-filled-in versions of these docs, see
[PUBLISHING.md](PUBLISHING.md) (setup) and
[play-console-manual-steps.md](play-console-manual-steps.md) (manual
click-path with this app's actual screenshots). This file exists so the
*pattern* travels to the next project without re-deriving it — see also
[FULL_GUIDE.md §8](FULL_GUIDE.md#8-reusing-this-repo-as-a-template-for-a-new-project)
and [§9](FULL_GUIDE.md#9-lessons-learned--troubleshooting) for this repo's
own adapt-it-fresh checklist and incident log.

---

## Part A — What ends up automated vs. what stays manual

| Task | Automatable? |
| --- | --- |
| Build + sign the `.aab` | ✅ CI |
| Upload the binary to a track | ✅ Fastlane `upload_to_play_store` |
| Store listing text (title, description, changelog) | ✅ `fastlane/metadata/android/<locale>/*.txt` |
| Icon + feature graphic + screenshots | ✅ same metadata folder, pushed every release |
| Creating the app the very first time | ❌ Play Console UI, once |
| Content rating questionnaire | ❌ Play Console UI, once (legal attestation) |
| Target audience / Data safety / Ads / Health declarations | ❌ Play Console UI, once each |
| Testers list, countries/regions | ❌ Play Console UI (business decision, not just a form) |
| Granting the service account API access | ❌ Play Console UI, once (deliberate security control) |
| Creating + submitting a production release for review | ❌ Play Console UI **or** Fastlane `deploy_production` — see Part B |

Everything ❌ is a one-time cost per app (not per release) — after it's
done once, every future release is the one-command pipeline in Part B.
Note the last row: submitting a *release* is actually automatable via the
API — what's never automatable is the legal/policy declarations that have
to exist before Google will let any release (manual or API) go out.

---

## Part B — One-time pipeline setup

### B.1 Create the app in Play Console

Manual, unavoidable. [Play Console](https://play.google.com/console) →
**Create app** → name, default language, app/game, free/paid. **Copy-paste
the package name, never retype it** — it becomes permanent the instant the
app exists, with no way to change it later even by deleting and recreating
(you'd need a genuinely new package name).

### B.2 Generate the upload signing key

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
```
Back it up outside the repo. Losing it means the app can never be updated
again under this listing. Never reuse one app's key for a different app.

### B.3 Create a Google Cloud service account

1. [Google Cloud Console](https://console.cloud.google.com) → **IAM &
   Admin → Service Accounts → Create Service Account** (e.g.
   `play-publisher`).
2. Skip role assignment here — permissions come from Play Console instead
   (B.4), not GCP IAM.
3. Open it → **Keys → Add Key → Create new key → JSON**. This file is what
   CI authenticates with — never commit it to the repo.

### B.4 Grant the service account Play Console permissions

Play Console → **Users and permissions → Invite new users** → paste the
service account's email (looks like
`play-publisher@<gcp-project-id>.iam.gserviceaccount.com` — not a real
inbox, that's expected) → assign permissions → **Invite user**.

> **Grant production release permission immediately — don't scope it to
> "testing tracks only" and mean to widen it later.** A too-narrow scope
> doesn't fail loudly or early: the build succeeds, every metadata/image
> upload succeeds, and only the very last API call (committing the release
> to the production track) fails with
> `Google Api Error: Invalid request - The caller does not have permission`.
> That reads exactly like a pipeline bug, when it's actually a one-checkbox
> permissions gap. Save yourself the debugging loop and grant full release
> permission (or at least testing **and** production) at setup time.

### B.5 Fastlane metadata folder layout

```
fastlane/
  metadata/
    android/
      <locale>/                  # e.g. en-US
        title.txt
        short_description.txt
        full_description.txt
        changelogs/
          <versionCode>.txt      # one file per release, named by build number
        images/
          icon.png               # 512x512 — see B.6, must match the real app icon
          featureGraphic.png     # 1024x500
          phoneScreenshots/
            1_*.png
            2_*.png
```
Every file here uploads automatically with every release — no manual
Play Console form-filling for listing text/icon/screenshots, ever again.

### B.6 One icon source, used twice

The store listing icon (`fastlane/metadata/android/<locale>/images/icon.png`)
and the real installed app icon
(`android/app/src/main/res/mipmap-*/ic_launcher.png`) are two independent
files. Nothing keeps them in sync unless you set that up — and if they
drift, Google's automated review flags it as a **Misleading Claims**
violation ("app icon or name differs from your store listing") and rejects
the release outright.

`pubspec.yaml` (Flutter):
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.3

flutter_launcher_icons:
  android: "ic_launcher"
  image_path: "assets/icon/icon.png"
```
```bash
cp fastlane/metadata/android/<locale>/images/icon.png assets/icon/icon.png
dart run flutter_launcher_icons
```
Whenever the icon changes: update `assets/icon/icon.png`, re-run the
command above, then copy the result to the Fastlane images path too — one
source of truth, regenerated into both places together, every time.

(Non-Flutter Android: whatever generates `mipmap-*/ic_launcher.png` — e.g.
Android Studio's Image Asset tool — needs to point at the exact same
source art as the Fastlane listing icon, for the same reason.)

### B.7 CI secrets

Repo → Settings → Secrets and variables → Actions:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore's `storePassword` |
| `ANDROID_KEY_ALIAS` | `upload` (or your alias) |
| `ANDROID_KEY_PASSWORD` | keystore's `keyPassword` |
| `PLAY_SERVICE_ACCOUNT_JSON` | full contents of the JSON from B.3 |

### B.8 Fastlane lanes (`fastlane/Fastfile`)

```ruby
default_platform(:android)

PROJECT_ROOT = File.expand_path("..", __dir__)
AAB_PATH = File.join(PROJECT_ROOT, "build/app/outputs/bundle/release/app-release.aab")

platform :android do
  desc "Build the release .aab"
  lane :build_release do
    Dir.chdir(PROJECT_ROOT) do
      sh("flutter", "build", "appbundle", "--release")
    end
  end

  desc "Build and upload to Internal testing (binary only, no listing changes)"
  lane :deploy_internal do
    build_release
    upload_to_play_store(
      track: "internal",
      aab: AAB_PATH,
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true,
    )
  end

  desc "Promote the build already on Internal straight to Production — no rebuild"
  lane :promote_production do |options|
    upload_to_play_store(
      track: "internal",
      track_promote_to: "production",
      rollout: (options[:rollout] || "1.0"),
      skip_upload_aab: true,
      skip_upload_apk: true,
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true,
      skip_upload_changelogs: true,
    )
  end

  desc "Build and upload a FRESH binary directly to Production — binary + full listing"
  lane :deploy_production do |options|
    build_release
    upload_to_play_store(
      track: "production",
      aab: AAB_PATH,
      rollout: (options[:rollout] || "1.0"),
    )
  end
end
```
Non-Flutter apps: swap only `build_release`'s `flutter build appbundle` for
your platform's release build command — everything else stays identical.

### B.9 CI workflow (`.github/workflows/release.yml`)

```yaml
name: Release to Google Play

on:
  push:
    tags:
      - "v*.*.*"
  workflow_dispatch:
    inputs:
      track:
        description: "internal: build+upload fresh. production: promote the build already on internal (no rebuild). production-fresh-build: build+upload a new binary straight to production (bump the build number first)."
        required: true
        default: "internal"
        type: choice
        options:
          - internal
          - production
          - production-fresh-build

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"

      - uses: subosito/flutter-action@v2
        with:
          channel: stable

      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.3"
          bundler-cache: true

      - name: Decode signing key and write key.properties
        env:
          ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          ANDROID_KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          ANDROID_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
        run: |
          # storeFile is relative to android/app/, since that's where
          # Gradle's file() resolves it from in app/build.gradle.kts.
          echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > android/app/upload-keystore.jks
          cat > android/key.properties <<EOF
          storePassword=$ANDROID_KEYSTORE_PASSWORD
          keyPassword=$ANDROID_KEY_PASSWORD
          keyAlias=$ANDROID_KEY_ALIAS
          storeFile=upload-keystore.jks
          EOF

      - name: Write Play Console service account key
        env:
          PLAY_SERVICE_ACCOUNT_JSON: ${{ secrets.PLAY_SERVICE_ACCOUNT_JSON }}
        run: echo "$PLAY_SERVICE_ACCOUNT_JSON" > fastlane/play-service-account.json

      - run: flutter pub get

      - name: Deploy (internal track, on tag push)
        if: github.event_name == 'push'
        run: bundle exec fastlane android deploy_internal

      - name: Deploy (manual track selection)
        if: github.event_name == 'workflow_dispatch' && github.event.inputs.track == 'internal'
        run: bundle exec fastlane android deploy_internal

      - name: Promote internal build to production
        if: github.event_name == 'workflow_dispatch' && github.event.inputs.track == 'production'
        run: bundle exec fastlane android promote_production

      - name: Deploy fresh build directly to production
        if: github.event_name == 'workflow_dispatch' && github.event.inputs.track == 'production-fresh-build'
        run: bundle exec fastlane android deploy_production
```
`fastlane/Gemfile` needs at minimum:
```ruby
source "https://rubygems.org"
gem "fastlane"
```

### B.10 Version bump convention

`pubspec.yaml`: `version: 1.0.1+2` — `versionName+versionCode`. The build
number (`+2`) **must increase on every release pushed to any track**, or
Google rejects the upload outright. `android/app/build.gradle.kts` should
read both from Flutter rather than hardcode them:
```kotlin
versionCode = flutter.versionCode
versionName = flutter.versionName
```
Add a matching `fastlane/metadata/android/<locale>/changelogs/<versionCode>.txt`
for every release.

### B.11 Command cheat-sheet

```bash
# fast iteration — build + upload to internal testing only
gh workflow run "Release to Google Play" --repo <REPO> -f track=internal

# ship exactly what's on internal to production, untouched
gh workflow run "Release to Google Play" --repo <REPO> -f track=production

# build fresh and ship straight to production + full listing
# (bump pubspec.yaml's build number first)
gh workflow run "Release to Google Play" --repo <REPO> -f track=production-fresh-build

# watch it
gh run list --repo <REPO> --workflow "Release to Google Play" --limit 1
gh run view <run-id> --repo <REPO>
gh run view <run-id> --repo <REPO> --log-failed   # only if it failed
```

---

## Part C — Manual click-path (the parts Part B can't touch)

Everything here happens once per app, in the Play Console UI, before or
alongside the automated pipeline above. Google requires a human for these
regardless of tool — they're legal/policy attestations, not paperwork that
happens to lack an API today.

### C.1 Dashboard / Publishing overview — orientation

Open **Dashboard** first — it lists locked/unlocked steps still blocking
the app out of draft status. A "Temporary app name '... (unreviewed)'" tag
next to the package name is normal for a draft app and persists until
Google finishes reviewing a submitted release; it isn't itself a blocker.

**Publishing overview** lists every pending change grouped by area (store
listings, app content, store settings, production/testing tracks). Its
"Send app for review" button stays disabled until Dashboard's required
steps are complete. Once submitted, this page shows a "Changes in review"
section listing exactly what was sent.

### C.2 Internal testing — add testers (optional, not required to publish)

Path: **Test and release → Testing → Internal testing → Testers tab**

1. **Create email list** → name it, add tester email addresses (Enter or
   comma-separated).
2. **Save changes** → confirm in the dialog. (This save step can fail
   transiently with a red error and an emptied list — just re-enter the
   emails and save again.)
3. Tick the new list's checkbox on the Testers tab → **Save** (bottom
   right) to attach it to the track.

Whose email(s) to use is a business decision, not something to guess at.

### C.3 Production track — select countries/regions

Path: **Test and release → Production → Countries / regions tab**

1. **Add countries / regions**.
2. Click the header checkbox to select every country/region in one action,
   or hand-pick specific ones.
3. **Save**.

Worldwide vs. a specific country list is a business decision for the app
owner.

### C.4 App content — Content ratings questionnaire

Path: **Monitor and improve → Policy and programs → App content → Content
ratings → Edit declaration**

This is the IARC questionnaire — the one declaration Google requires
resubmitted whenever it shows incomplete, even if a prior rating exists.

1. **Category page:** contact email, a category radio (Game / Social or
   Communication / All Other App Types — business/utility apps pick "All
   Other App Types"), agree to Terms of Use → **Next**.
2. **Questionnaire page:** Yes/No questions grouped by header (varies by
   category). Every group needs a green "Completed" tag before the **Next**
   button un-greys — click **Save** first if it looks stuck. A plain
   business/utility app with no mature content, gambling, user-generated
   content, or location-sharing between users answers **No** to everything.
3. **Summary page:** review the resulting per-territory age rating → **Save**.

Category and every mature-content answer are factual claims that drive an
official age rating — confirm with the app owner, never assume.

### C.5 App content — Target audience, Data safety, Ads, Health

Path for all: **Monitor and improve → Policy and programs → App content**.
Check the **Actioned** tab first — these often carry over from a prior
session and don't need redoing.

- **Target audience:** select the target age group(s) (adult range for a
  business/utility app, not "designed for children"), answer the
  children's-appeal question, **Save**.
- **Data safety form:** the gate question ("does your app collect or share
  any required user data types?") determines whether per-category
  questions (location, personal info, financial info, …) even appear.
  Answer encryption-in-transit and data-deletion questions near the end,
  review the store-listing preview, **Submit**.
- **Ads declaration:** answer "does your app contain ads?", **Save**.
- **Health apps declaration:** only appears for some categories; if App
  content doesn't list it, it doesn't apply. Otherwise answer and **Save**.

All of these surface together in Publishing overview alongside content
rating, countries, and release changes — they submit together in C.7.

### C.6 Production track — create the release

Path: **Test and release → Production → Releases tab → Create new release**

1. **App bundles:** **Upload** a new `.aab`, or **Add from library** to
   reuse a bundle already sitting on another track.
2. **Release details:** release name auto-fills from the bundle version;
   release notes box is pre-seeded with locale tags — replace only the
   placeholder text, keep the closing tag on its own line.
3. **Next** → **Preview and confirm** should show a green "Ready to
   release" banner → **Save**.

This is the point of no return before Google review — always get explicit
sign-off from the app owner before saving a real production release.

### C.7 Publishing overview — submit for review

1. Once every blocking item clears, "Send app for review" becomes
   **"Submit N changes for review"**.
2. Click it → confirm in the dialog (review typically completes within 7
   days, can take longer on a first submission).
3. The section flips to **"Changes in review"** — Google runs an automated
   pre-check before human review starts.

The actual publish trigger — always get explicit sign-off first. After
approval, the release goes live automatically if "Managed publishing" is
off; if on, one more manual "Publish" click is needed.

### Decisions that need the app owner, not automation

- Tester email addresses
- Countries/regions to release in
- Content rating category + every mature-content answer
- Release notes wording
- Final go-ahead to save/submit a production release

---

## Part D — Pitfalls checklist (both cost a real rejected release before)

- [ ] Service account permission includes **production**, not just testing
      tracks (B.4) — a scope gap fails silently at the very last API call.
- [ ] The launcher-icon source (`assets/icon/icon.png` or equivalent) is
      the **same file, byte-for-byte**, as the Fastlane store listing icon
      (B.6) — re-run the icon generator after every icon change, don't just
      swap the Fastlane copy alone.
- [ ] `versionCode` increases on every release to *any* track.
- [ ] A changelog file exists for the new `versionCode` before deploying.
- [ ] The package name was copy-pasted into Play Console, never retyped —
      it's permanent from the moment the app is created.
