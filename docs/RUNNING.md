# Running & Testing

## Prerequisites

- Flutter SDK (stable channel) on your PATH.
- Android SDK with at least one platform + build-tools installed, and its
  licenses accepted (`flutter doctor` should report "No issues found!").
- An Android emulator (AVD) or a physical Android device with USB debugging
  enabled. **This app cannot be meaningfully tested on Windows desktop or web
  targets** — it uses `sqflite` for local storage, which only has real
  (non-stub) implementations on Android/iOS/macOS. `flutter run -d windows`
  will build, but every database call will fail at runtime.

Run `flutter doctor -v` any time to check all of the above.

## Option A — Android emulator

1. List available emulators:
   ```bash
   flutter emulators
   ```
2. Launch one (this machine already has `Pixel_3a_API_34_extension_level_7_x86_64`
   configured):
   ```bash
   flutter emulators --launch Pixel_3a_API_34_extension_level_7_x86_64
   ```
   Wait for it to fully boot (first boot can take a minute or two).
3. Run the app:
   ```bash
   flutter run
   ```
   Flutter auto-detects the running emulator as the target. If more than one
   device is available, pass `-d <device-id>` (see `flutter devices` for ids).

## Option B — Physical Android device

1. On the phone: Settings → About phone → tap "Build number" 7 times to
   enable Developer options → Developer options → enable "USB debugging".
2. Connect via USB, accept the "Allow USB debugging?" prompt on the phone.
3. Confirm it's detected:
   ```bash
   adb devices
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## What to actually test (golden path)

Once the app is running:

1. **Catalog tab** — add a service item (e.g. "Backend API development" /
   hour / a default rate).
2. **Clients tab** — add a client.
3. **Estimates tab** — create a new estimate for that client; add a line item
   by picking the catalog entry (should prefill description + rate), adjust
   quantity, set a tax/discount %, confirm the live total updates correctly,
   save.
4. Open the estimate → **Export PDF** → confirm the share sheet opens with a
   correctly formatted PDF (client info, line items, totals).
5. Open the estimate → **Convert to Invoice** → confirm a new invoice is
   created with a generated invoice number and a due date 30 days out.
6. **Invoices tab** — confirm the new invoice appears; open it, change its
   status (e.g. to "Paid"), export its PDF too.
7. Restart the app (`R` for hot restart, or fully kill and `flutter run`
   again) and confirm everything persisted — this is the real test that
   sqflite is actually writing to disk, not just holding state in memory.

## Static analysis & automated tests

```bash
flutter analyze
flutter test
```

## Building artifacts without running the app live

```bash
flutter build apk --debug      # sideload-able debug APK
flutter build apk --release    # release APK (uses debug signing until
                                # android/key.properties exists — see
                                # docs/PUBLISHING.md)
flutter build appbundle --release   # .aab — what Play Store actually wants
```

The resulting files land under `build/app/outputs/`.

## Capturing Play Store screenshots (no manual screenshotting)

With the app running on an emulator/device (see above):

```bash
export PATH="$LOCALAPPDATA/Android/Sdk/platform-tools:$PATH"   # if adb isn't already on PATH
scripts/capture_screenshots.sh
```

This taps through each bottom-nav tab (found via the accessibility tree, not
hardcoded coordinates, so it's resilient to screen-size differences) and
saves one screenshot per tab into
`fastlane/metadata/android/en-US/images/phoneScreenshots/`, which Fastlane
uploads automatically on the next `deploy_production` — see
[docs/PUBLISHING.md](PUBLISHING.md). By default this captures whatever data
is currently in the app (empty state, unless you've added clients/estimates
first) — add a bit of demo data before running it if you want the
screenshots to show a populated app.
