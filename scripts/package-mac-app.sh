#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

echo "Building Cinema Engine.app…"
swift build -c release --product CinemaEngine

BIN="${ROOT}/.build/release/CinemaEngine"
APP_DIR="${ROOT}/dist/Cinema Engine.app"
CONTENTS="${APP_DIR}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

rm -rf "${APP_DIR}"
mkdir -p "${MACOS}" "${RESOURCES}"

cp "${BIN}" "${MACOS}/CinemaEngine"
chmod +x "${MACOS}/CinemaEngine"
cp "${ROOT}/Sources/CinemaEngineApp/Info.plist" "${CONTENTS}/Info.plist"

if [[ -f "${ROOT}/Resources/AppIcon.icns" ]]; then
  cp "${ROOT}/Resources/AppIcon.icns" "${RESOURCES}/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${CONTENTS}/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "${CONTENTS}/Info.plist"
fi

# Copy menu bar / brand assets into the app bundle resources as well
if [[ -d "${ROOT}/Sources/CinemaEngineApp/Resources" ]]; then
  cp -f "${ROOT}/Sources/CinemaEngineApp/Resources/"*.png "${RESOURCES}/" 2>/dev/null || true
fi

# Ad-hoc sign so Gatekeeper is less noisy for local builds
codesign --force --deep --sign - "${APP_DIR}" >/dev/null 2>&1 || true

ZIP="${ROOT}/dist/CinemaEngine-macOS.zip"
rm -f "${ZIP}"
(
  cd "${ROOT}/dist"
  ditto -c -k --sequesterRsrc --keepParent "Cinema Engine.app" "CinemaEngine-macOS.zip"
)

echo
echo "Built:"
echo "  ${APP_DIR}"
echo "  ${ZIP}"
echo
echo "Open once with right-click → Open if macOS blocks the download."
