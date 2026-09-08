# cinema-engine

macOS command-line tool that captures system audio from a virtual driver, runs a cinema/theatre DSP chain, and plays the result on headphones (for example AirPods Pro). There is no GUI.

It exists because media players such as Stremio do not offer cinema-style spatial processing. Route the player into BlackHole, let cinema-engine process the stream, and listen on a real output device.

Fully open-source (MIT). It uses only free tools: Swift, AVAudioEngine, BlackHole, and optional MIT KEMAR HRTF impulse responses. No paid Apple entitlements and no signed DriverKit extension.

## Architecture

```
┌─────────┐     ┌──────────────┐     ┌──────────────────────────┐     ┌─────────────┐
│ Stremio │ --> │ BlackHole 2ch│ --> │ cinema-engine (terminal) │ --> │ AirPods Pro │
│ (or any │     │ (auto-routed)│     │ EQ → width → HRTF →      │     │ (or other   │
│  player)│     │              │     │ reverb → bass → limiter  │     │  output)    │
└─────────┘     └──────────────┘     └──────────────────────────┘     └─────────────┘
```

`cinema-engine start` points macOS system output at BlackHole by itself, then restores your previous output when you quit. You do not need to click Sound Settings.

Live knobs live in `~/.cinema-engine/config.json`. A running `start` process watches that file and ramps DSP parameters without restarting the graph.

## Requirements

- macOS 13+
- Your Mac password once (to install the BlackHole audio driver)
- Click **Allow** if macOS asks for Microphone access

Homebrew is optional. `./install.sh` downloads the BlackHole pkg directly if brew is missing. Xcode Command Line Tools are installed automatically if `swift` is not already present (one GUI prompt).

## Install

```bash
cd /path/to/audio-engine
./install.sh
cinema-engine
```

`cinema-engine` is the live session (like `npm run dev`). While it is running, system audio is processed. When you quit, audio is normal again.

Keys:

- **↑ / ↓** select bass, width, dialogue, or room
- **← / →** change the selected level by 5
- **[ / ]** change by 1
- **1 / 2 / 3** theatre / reference / night presets
- **q** or **ctrl-c** stop and restore normal audio

From another terminal: `cinema-engine stop`

Then just start it. Play Stremio (or anything). Allow Microphone access if macOS asks.

## Commands

```bash
cinema-engine setup
```

Installs BlackHole if needed (pkg or Homebrew), writes config, and detects your headphones/speakers. No Sound Settings steps.

```bash
cinema-engine list-devices
```

Lists CoreAudio input and output devices with name, UID, channel count, and sample rate.

```bash
cinema-engine
cinema-engine start
cinema-engine dev
```

Interactive mixer. Captures BlackHole, plays to your headphones/speakers, and switches system output until you quit. Arrow keys change levels.

Optional overrides:

```bash
cinema-engine start --output "AirPods Pro" --preset theatre
cinema-engine start --no-hrtf
cinema-engine start --plain
```

Starts the graph in the foreground until Ctrl+C (or `cinema-engine stop`). Signal path:

1. Input from the chosen capture device (BlackHole)
2. 3-band EQ (low shelf, dialogue presence, high shelf)
3. Mid-side stereo widening with dialogue-band protection
4. HRTF convolution (“in front, slightly above”)
5. Small-hall reverb at a low wet mix
6. Extra bass shelf
7. Peak limiter
8. Chosen output device

Pass `--no-hrtf` to skip convolution. `--plain` uses a single status line instead of the mixer.

```bash
cinema-engine set bass 70
cinema-engine set width 80
cinema-engine set dialogue 60
cinema-engine set room 40
cinema-engine set preset night
```

Writes `~/.cinema-engine/config.json`. Values are 0–100. The running engine hot-reloads and ramps changes over about 100 ms.

```bash
cinema-engine status
```

Prints whether the engine is active, the PID, routing, and current parameters (from `~/.cinema-engine/state.json`).

```bash
cinema-engine stop
```

Stops the live session and restores the previous system output, so audio is normal again.

## Config

`~/.cinema-engine/config.json`:

```json
{
  "preset": "theatre",
  "bass": 70,
  "width": 80,
  "dialogue": 60,
  "room": 40,
  "input_device": "auto",
  "output_device": "auto"
}
```

Presets: `theatre`, `reference`, `night`.

## HRTF data

Place MIT KEMAR (or compatible) impulse responses in `hrtf-data/` as WAV files:

- `front_left.wav` / `front_right.wav` (preferred), or
- `H10e000a.wav` (elevation +10°, azimuth 0° — in front, slightly above)

If no files are present, cinema-engine uses a short synthetic front IR so the node still runs. See `hrtf-data/README.md`.

## Latency

The engine requests 256-frame hardware buffers (falls back to the device’s allowed range, typically 256–512). Custom DSP uses preallocated buffers and does not perform I/O on the audio thread. Total input-to-output delay is intended to stay under ~40 ms so picture and sound stay in sync.

## License

MIT. BlackHole is MIT. MIT KEMAR HRTF data is a free academic dataset with its own terms; it is not redistributed here.
