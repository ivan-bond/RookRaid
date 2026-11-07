#!/bin/bash
# One layout for every iPhone. Size comes from the window, not a device check,
# so a fold (iPhone Duo) or a new screen size updates the board by itself.
set -euo pipefail

if git grep -n -E -e 'UIScreen\.main|userInterfaceIdiom|UIDevice\.current\.orientation|statusBarOrientation' -- 'RookRaid' >/dev/null; then
  echo "Layout must follow the window, not the device or the screen:"
  git grep -n -E -e 'UIScreen\.main|userInterfaceIdiom|UIDevice\.current\.orientation|statusBarOrientation' -- 'RookRaid'
  exit 1
fi

project=RookRaid.xcodeproj/project.pbxproj
# The App Store build is iPhone only, in portrait. Debug and Release must agree, so a test build
# looks like the one that ships.
family=$(grep -c 'TARGETED_DEVICE_FAMILY = 1;' "$project" || true)
if [ "$family" -lt 2 ] || grep -q 'TARGETED_DEVICE_FAMILY = "1,2"' "$project"; then
  echo "Debug and Release must target iPhone only (TARGETED_DEVICE_FAMILY 1)."
  exit 1
fi

portrait=$(grep -c 'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;' "$project" || true)
if [ "$portrait" -lt 2 ]; then
  echo "Debug and Release must allow portrait only on iPhone."
  exit 1
fi

echo "iPhone in portrait, layout follows the window."
