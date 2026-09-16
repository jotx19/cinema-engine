# cinema-engine

<p align="center">
  Cinema sound for Stremio (or any other Mac audio output) — on your AirPods — as a menu bar widget.<br>
  <strong>MIT licensed.</strong> Free to use, copy, modify, and sell.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow?style=flat" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/macOS-000000?style=flat&logo=apple&logoColor=white" alt="macOS">
  <img src="https://img.shields.io/badge/Swift-F05138?style=flat&logo=swift&logoColor=white" alt="Swift">
  <img src="https://img.shields.io/badge/Menu_Bar-Widget-0D96F6?style=flat" alt="Menu Bar Widget">
  <img src="https://img.shields.io/badge/Core_Audio-0D96F6?style=flat&logo=apple&logoColor=white" alt="Core Audio">
</p>

## What this is

**Stremio** (and any other Mac audio output) just sends stereo to your headphones. **Cinema Engine** sits in the middle and adds theatre-style sound: more bass, a wider image, voices that stay clear, a little room, and a spatial “in front of you” effect.

It lives in the **macOS menu bar**. No Terminal. No Dock window.

## Install

One command installs BlackHole and the menu bar widget:

```bash
curl -fsSL https://raw.githubusercontent.com/jotx19/cinema-engine/main/install.sh | bash
```

Or download `CinemaEngine-macOS.zip` from the site, then still run the install script once so BlackHole is present.

After install:

1. Look for the AirPods icon in the top-right menu bar.
2. Click it → **Start**.
3. First launch: right-click → **Open** if macOS warns about an unidentified developer.
4. Allow Microphone access when asked (for BlackHole, not your hardware mic).

### Build from source

```bash
git clone https://github.com/jotx19/cinema-engine.git
cd cinema-engine
./install.sh
```

Or package only:

```bash
./scripts/package-mac-app.sh
open "dist/Cinema Engine.app"
```

## How it works

On start, Cinema Engine routes Mac audio into BlackHole, processes it (EQ, width, HRTF, room, bass, limiter), and plays it on your headphones. On stop/quit, normal audio comes back.

If BlackHole is missing, the widget asks you to install it before Start will work.

## Prerequisites

- macOS 13 or later
- One admin password for BlackHole (first install only)
