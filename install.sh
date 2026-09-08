#!/usr/bin/env bash
set -euo pipefail

echo "cinema-engine installer"
echo "======================="
echo "This installs BlackHole, builds cinema-engine, and puts it on your PATH."
echo "You should not need Homebrew or to change System Settings > Sound."
echo

ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.cinema-engine"
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
  echo "Xcode Command Line Tools are needed once to compile cinema-engine."
  echo "macOS will show a GUI installer — finish it, then re-run ./install.sh"
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

  if ! have_blackhole; then
    echo "BlackHole was installed. If it does not show up yet, log out and back in, then run:"
    echo "  cinema-engine start"
  else
    echo "BlackHole installed."
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

install_binary() {
  echo
  echo "Building cinema-engine (release)..."
  (cd "${ROOT}" && swift build -c release)
  mkdir -p "${BIN_DIR}"
  cp -f "${ROOT}/.build/release/cinema-engine" "${BIN_DIR}/cinema-engine"
  chmod +x "${BIN_DIR}/cinema-engine"
  echo "Installed ${BIN_DIR}/cinema-engine"

  if [[ ":${PATH}:" != *":${BIN_DIR}:"* ]]; then
    SHELL_NAME="$(basename "${SHELL:-zsh}")"
    RC="${HOME}/.zshrc"
    [[ "${SHELL_NAME}" == "bash" ]] && RC="${HOME}/.bashrc"
    MARKER='export PATH="$HOME/.local/bin:$PATH"'
    if [[ ! -f "${RC}" ]] || ! grep -Fq "${MARKER}" "${RC}"; then
      echo "" >> "${RC}"
      echo "# cinema-engine" >> "${RC}"
      echo "${MARKER}" >> "${RC}"
      echo "Added ${BIN_DIR} to PATH in ${RC} (open a new terminal, or: source ${RC})"
    fi
    export PATH="${BIN_DIR}:${PATH}"
  fi
}

ensure_clt
install_blackhole
write_config
install_binary

cat <<EOF

Done. From now on:

  cinema-engine

That's the live mixer (same as `cinema-engine start` / `cinema-engine dev`):
  • system audio goes through the cinema DSP
  • ↑↓ select a knob, ←→ change the level
  • q or ctrl-c stops it and audio is normal again

  cinema-engine stop
EOF
