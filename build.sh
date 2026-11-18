#!/bin/bash
# Builds DanielScroll.app into ./build
#   ./build.sh            build only
#   ./build.sh --install  build, copy to /Applications, and relaunch
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/DanielScroll"

APP="build/DanielScroll.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/DanielScroll"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# A stable signing identity keeps the Accessibility permission across rebuilds.
# Ad-hoc signing works too, but macOS forgets the permission every time you rebuild.
IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
  | awk -F'"' '/Apple Development|Developer ID Application/ {print $2; exit}')"
if [ -n "$IDENTITY" ]; then
  codesign --force --options runtime --sign "$IDENTITY" "$APP"
  echo "Signed with: $IDENTITY"
else
  codesign --force --sign - "$APP"
  echo "warning: ad-hoc signed; re-grant Accessibility after each rebuild"
fi

echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
  pkill -x DanielScroll 2>/dev/null || true
  rm -rf /Applications/DanielScroll.app
  cp -R "$APP" /Applications/
  open /Applications/DanielScroll.app
  echo "Installed to /Applications and launched"
fi
