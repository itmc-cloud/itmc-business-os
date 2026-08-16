# Content Rating & Data Safety — Answer Key

This is a copy-paste answer key for the two Play Console forms that must be
filled in by hand (see [PUBLISHING.md](PUBLISHING.md) — there's no API for
either). It's based on what's actually true about this app: no accounts, no
network calls, no ads, no analytics, no crash reporting, and no data leaves
the device (everything is stored locally via `sqflite`). Google's exact
question wording shifts over time, so treat this as "the underlying answer,"
and match it to whatever phrasing is on screen when you get there — the
logic doesn't change even if the wording does.

**If you later add anything to this app that changes these facts** — an ad
network, Firebase Analytics/Crashlytics, a backend, cloud sync, sign-in —
**revisit this doc before your next release.** The answers below are only
correct for the app as it exists today (local-only estimator/invoicing).

## Content rating questionnaire (IARC)

Play Console → your app → Policy → App content → Content ratings.

- **Category:** Productivity / Business / Utility app (not a game).
- **Violence:** No, none of any kind.
- **Sexual content:** No.
- **Profanity / crude humor:** No.
- **Controlled substances** (tobacco, alcohol, drugs — depicted or
  referenced): No.
- **Gambling** (real-money or simulated): No.
- **User-generated content / can users interact or exchange content with
  each other:** No — there is no chat, no multiplayer, no shared/public
  content of any kind. Each install's data is private to that device.
- **Location sharing:** No — the app never accesses or shares location.
- **Personal information sharing:** No — nothing is shared, since nothing
  leaves the device.
- **Digital purchases:** No, unless you've added in-app purchases (this
  boilerplate has none).
- **Miscellaneous / scary or intense content:** No.

Answering "No" to the interactive/objectionable-content questions typically
resolves to the lowest rating tier (e.g. "Everyone" / PEGI 3) automatically
— IARC computes the rating from these answers, you don't pick it directly.

## Data safety form

Play Console → your app → Policy → App content → Data safety.

- **"Does your app collect or share any of the required user data types?"**
  → **No.** This is the key question — answering "No" here skips almost
  everything below, since the form is only asking about data that leaves
  the device or gets shared with anyone.
- If it separately asks about specific categories (location, personal info,
  financial info, health & fitness, messages, photos/videos, audio, files &
  docs, calendar, contacts, app activity, web browsing, device/other IDs):
  **none collected, none shared**, for all of them.
- **"Is all of the user data collected by your app encrypted in transit?"**
  → Not applicable / no data is transmitted, so there's no transit to
  encrypt. If the form forces a Yes/No here regardless, "Yes" is defensible
  since nothing is ever sent in plaintext (nothing is sent, period) — but
  this only comes up if you answered "collects data" somewhere, which you
  shouldn't have.
- **"Do you provide a way for users to request data deletion?"** → Users
  can delete all their data themselves at any time by uninstalling the app,
  or by deleting individual clients/estimates/invoices in-app. There is no
  server-side data to delete because none exists.
- **Privacy policy URL:** the GitHub Pages URL from
  [docs/privacy-policy.md](privacy-policy.md) — set this up per
  [PUBLISHING.md](PUBLISHING.md) step 1 before you get to this form.

## Target audience & content

- **Target age group:** Business/productivity tool for adults running a
  service business — select 18+ (or your actual target range), not "designed
  for children." This also means you should answer **No** to any
  "designed for or appealing to children" style question, and the
  Families Policy / Ads-for-children sections won't apply.

## Ads declaration

Play Console → App content → Ads.

- **"Does your app contain ads?"** → **No.** No ad SDK/network is
  integrated in this app.

## Health apps declaration

Play Console → App content → Health apps.

- This app doesn't collect, store, or display any health or fitness data
  (no steps, workouts, medical records, symptoms, etc.) — it's a
  business/invoicing tool. Answer **No** / select that your app is not a
  health app, or skip this declaration if Play Console doesn't force an
  answer for apps outside the health category.

## App category & store settings

- **Category:** Business (Play Console → Store settings → App category).
- **Store listing (default, en-US):** should already show the title,
  descriptions, icon, feature graphic, and screenshots pushed by Fastlane
  (`fastlane/metadata/android/en-US/`) — open it once and confirm it looks
  complete/saved rather than showing a "missing information" warning. If
  anything looks missing, it's the automation's job to have filled it, not
  something to type in by hand — check `fastlane/metadata/android/en-US/`
  matches what you expect and re-run a release if not.
