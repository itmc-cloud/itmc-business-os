#!/usr/bin/env bash
# Captures Play Store screenshots automatically — no manual screenshotting.
#
# Requires: an Android emulator or device already running with the app
# installed (see docs/RUNNING.md). Navigates each bottom-nav tab via `adb`
# (by reading the on-screen accessibility tree, not hardcoded pixel coords —
# works across screen sizes) and saves one screenshot per tab straight into
# fastlane's metadata folder, where `fastlane android deploy_production`
# (or the `screenshots` lane) will pick them up automatically.
#
# Usage:
#   export PATH="/c/Users/$USER/AppData/Local/Android/Sdk/platform-tools:$PATH"
#   scripts/capture_screenshots.sh [package-name] [device-serial]

set -euo pipefail

PACKAGE="${1:-com.itmc.itmc_estimator}"
DEVICE_ARG=()
if [ -n "${2:-}" ]; then
  DEVICE_ARG=(-s "$2")
fi

OUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/fastlane/metadata/android/en-US/images/phoneScreenshots"
mkdir -p "$OUT_DIR"

TABS=("Estimates" "Invoices" "Clients" "Catalog")

dump_bounds_for_label() {
  local label="$1"
  local local_dump
  local_dump="$(mktemp)"
  # The doubled leading slash (//sdcard/...) stops Git Bash/MSYS from
  # rewriting this Android on-device path into a Windows host path.
  adb "${DEVICE_ARG[@]}" shell uiautomator dump //sdcard/window_dump.xml >/dev/null
  adb "${DEVICE_ARG[@]}" pull //sdcard/window_dump.xml "$local_dump" >/dev/null
  # Flutter's accessibility label often includes extra hint text after the
  # visible label (e.g. `content-desc="Estimates&#10;Tab 1 of 4"`), so match
  # the label as a prefix, not an exact attribute value.
  grep -o "content-desc=\"${label}[^\"]*\"[^>]*bounds=\"\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]\"" "$local_dump" \
    | grep -o 'bounds="\[[0-9,]*\]\[[0-9,]*\]"' \
    | head -n1 \
    | grep -o '[0-9]\+' || true
  rm -f "$local_dump"
}

tap_center_of_bounds() {
  # args: x1 y1 x2 y2
  local x1=$1 y1=$2 x2=$3 y2=$4
  local cx=$(( (x1 + x2) / 2 ))
  local cy=$(( (y1 + y2) / 2 ))
  adb "${DEVICE_ARG[@]}" shell input tap "$cx" "$cy"
}

echo "Capturing screenshots for $PACKAGE into $OUT_DIR"

for i in "${!TABS[@]}"; do
  label="${TABS[$i]}"
  bounds=($(dump_bounds_for_label "$label"))
  if [ "${#bounds[@]}" -eq 4 ]; then
    tap_center_of_bounds "${bounds[0]}" "${bounds[1]}" "${bounds[2]}" "${bounds[3]}"
  else
    echo "Warning: could not find nav tab '$label' in the accessibility tree — is the app in the foreground and on the home screen? Skipping tap, capturing current screen anyway." >&2
  fi
  sleep 1
  outfile="$OUT_DIR/$((i+1))_${label,,}.png"
  adb "${DEVICE_ARG[@]}" exec-out screencap -p > "$outfile"
  echo "  -> $outfile"
done

echo "Done. Review images in $OUT_DIR before publishing — these reflect whatever data is currently in the app (empty state by default)."
