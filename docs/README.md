# Docs index

Start here. Docs are ordered by when you'd actually reach for them, from
first setup to ongoing release work.

## Read this one first

- **[COMPLETE_MANUAL.md](COMPLETE_MANUAL.md)** — the whole lifecycle in one
  self-contained document: installing Flutter, what the project is made of,
  running it, building/exporting it, branching & CI, one-time Google Play
  setup, Fastlane, the tag/release workflow, and the Play Console manual
  forms. Everything below goes deeper on one specific part of it.

## Start / run

- **[GETTING_STARTED.md](GETTING_STARTED.md)** — one linear checklist,
  phase by phase, from installing Flutter to publishing on Google Play.
  If you're not sure where to start, start here.
- **[RUNNING.md](RUNNING.md)** — local dev setup, running on an
  emulator/device, the golden-path manual test script, static analysis.

## Publishing to Google Play

- **[PUBLISHING.md](PUBLISHING.md)** — the one-time setup (signing key,
  Google Cloud service account, GitHub secrets) and what is/isn't
  automatable, with the ongoing release command.
- **[FASTLANE.md](FASTLANE.md)** — what Fastlane is and how this repo
  uses it: the lanes, what triggers them, running one locally.
- **[play-console-manual-steps.md](play-console-manual-steps.md)** —
  click-by-click walkthrough of every Play Console screen that requires a
  human (testers, countries/regions, content rating, target audience,
  data safety, ads, health apps, creating a release, submitting for
  review).
- **[store-listing-answers.md](store-listing-answers.md)** — copy-paste
  answer key for the content-rating and data-safety questionnaires,
  specific to what this app actually does.
- **[privacy-policy.md](privacy-policy.md)** — the actual policy text,
  hosted live via GitHub Pages and linked from the Play Store listing.
- **[DEPLOY_TEMPLATE.md](DEPLOY_TEMPLATE.md)** — the portable version of
  all of the above: generic placeholders, meant to be copied wholesale
  into a brand-new project's `docs/` folder, including the full manual
  Play Console click-path and the pitfalls checklist.

## Reference

- **[FULL_GUIDE.md](FULL_GUIDE.md)** — the comprehensive reference:
  architecture, folder structure, branching/CI, and — since this repo is
  meant to be reused as a template — exactly what to change to adapt it
  into a brand-new app, plus lessons learned/troubleshooting.
