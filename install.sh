#!/usr/bin/env bash
set -euo pipefail

echo "Cinema Engine installer"
echo "======================="
echo "Installs BlackHole and the Cinema Engine menu bar widget."
echo

ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${HOME}/.cinema-engine"
APP_DEST="/Applications/Cinema Engine.app"
BLACKHOLE_PKG_URLS=(
  "https://existential.audio/downloads/BlackHole2ch.v0.7.1.pkg"
  "https://github.com/ExistentialAudio/BlackHole/releases/download/v0.7.1/BlackHole2ch.v0.7.1.pkg"
)

have_blackhole() {
  system_profiler SPAudioDataType 2>/dev/null | grep -qi "BlackHole" && return 0
  [[ -d "/Library/Audio/Plug-Ins/HAL/BlackHole2ch.driver" ]] && return 0
  [[ -d "/Library/Audio/Plug-Ins/HAL/BlackHole.driver" ]] && return 0
  return 1
}

ensure_clt() {
  if xcode-select -p >/dev/null 2>&1 && command -v swift >/dev/null 2>&1; then
    return 0
  fi
  echo "Xcode Command Line Tools are needed once to build Cinema Engine."
  echo "macOS will show a GUI installer — finish it, then re-run this script."
  xcode-select --install >/dev/null 2>&1 || true
  exit 1
}

install_blackhole() {
  if have_blackhole; then
    echo "BlackHole is already installed."
    return 0
  fi

  echo "Installing BlackHole 2ch (your Mac password will be requested)..."
  export HOMEBREW_NO_AUTO_UPDATE=1
  if command -v brew >/dev/null 2>&1; then
    if brew install --cask blackhole-2ch || brew install blackhole-2ch; then
      sudo killall coreaudiod >/dev/null 2>&1 || true
      sleep 2
      if have_blackhole; then
        echo "BlackHole installed via Homebrew."
        return 0
      fi
    fi
    echo "Homebrew install did not expose BlackHole yet; downloading the pkg..."
  fi

  PKG="$(mktemp -t BlackHole2ch).pkg"
  DOWNLOADED=0
  for url in "${BLACKHOLE_PKG_URLS[@]}"; do
    echo "Downloading ${url}"
    if curl -fsSL -o "${PKG}" "${url}"; then
      DOWNLOADED=1
      break
    fi
  done
  if [[ "${DOWNLOADED}" -ne 1 ]]; then
    echo "Could not download BlackHole. Check your network and try again."
    exit 1
  fi

  sudo installer -pkg "${PKG}" -target /
  sudo killall coreaudiod >/dev/null 2>&1 || true
  sleep 2
  rm -f "${PKG}"

  if have_blackhole; then
    echo "BlackHole installed."
  else
    echo "BlackHole package was installed. If it does not show up yet, log out and back in."
  fi
}

write_config() {
  mkdir -p "${CONFIG_DIR}"
  CONFIG_FILE="${CONFIG_DIR}/config.json"
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    cat > "${CONFIG_FILE}" <<'EOF'
{
  "preset" : "theatre",
  "bass" : 70,
  "width" : 80,
  "dialogue" : 60,
  "room" : 40,
  "input_device" : "auto",
  "output_device" : "auto"
}
EOF
    echo "Wrote ${CONFIG_FILE}"
  else
    echo "Config already exists at ${CONFIG_FILE}"
  fi
}

install_app() {
  echo
  echo "Building Cinema Engine menu bar widget..."
  (cd "${ROOT}" && ./scripts/package-mac-app.sh)

  echo "Installing to ${APP_DEST}"
  rm -rf "${APP_DEST}"
  ditto "${ROOT}/dist/Cinema Engine.app" "${APP_DEST}"
  codesign --force --deep --sign - "${APP_DEST}" >/dev/null 2>&1 || true
}

open_app() {
  open "${APP_DEST}" || open "${ROOT}/dist/Cinema Engine.app"
}

ensure_clt
install_blackhole
write_config
install_app
open_app

cat <<EOF

Done.

Cinema Engine is in your menu bar (AirPods / waveform icon, top-right).
Click it → Start.

If macOS blocks the app the first time: right-click Cinema Engine.app → Open.
Allow Microphone access when asked (used for BlackHole, not your hardware mic).

App location: ${APP_DEST}
EOF
