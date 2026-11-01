#!/bin/bash
# iPhone, iPad, and iPhone Duo share one layout. Size comes from the window,
# so a fold, a rotation, or Split View updates the board without a device check.
set -euo pipefail

if git grep -n -E -e 'UIScreen\.main|userInterfaceIdiom|UIDevice\.current\.orientation|statusBarOrientation' -- 'RookRaid' >/dev/null; then
  echo "Layout must follow the window, not the device or the screen:"
  git grep -n -E -e 'UIScreen\.main|userInterfaceIdiom|UIDevice\.current\.orientation|statusBarOrientation' -- 'RookRaid'
  exit 1
fi

project=RookRaid.xcodeproj/project.pbxproj
if ! grep -q 'TARGETED_DEVICE_FAMILY = "1,2"' "$project"; then
  echo "The app must target iPhone and iPad (TARGETED_DEVICE_FAMILY 1,2)."
  exit 1
fi

iphone=$(grep -c 'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"' "$project" || true)
ipad=$(grep -c 'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"' "$project" || true)
if [ "$iphone" -lt 2 ] || [ "$ipad" -lt 2 ]; then
  echo "Debug and Release must allow portrait and landscape on iPhone and iPad."
  exit 1
fi

echo "iPhone, iPad, and landscape layouts are enabled."
