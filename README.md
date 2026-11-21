# TypeLess

> Voice-to-text at the speed of thought. Speak naturally anywhere on macOS and type less.

TypeLess is a lightweight, native macOS speech-to-text utility. It provides system-wide dictation across all Mac applications—including Slack, Notes, Xcode, VS Code, and web browsers—automatically formatting and inserting text directly at your cursor.

> **Architecture & Privacy Notice**: TypeLess is a native Swift client that captures audio locally on your Mac and transcribes it via the cloud using your own **Groq** (`whisper-large-v3-turbo`) or **OpenAI** (`whisper-1`) API key. Using cloud-accelerated inference provides sub-second latency (~300ms) with zero local RAM/GPU overhead. Audio snippets are saved temporarily to `/tmp` and deleted immediately after processing.

---

## Features

- **Sub-Second Speed**: Transcribes speech in ~300ms via Groq's high-speed Whisper LPU inference or OpenAI Whisper.
- **Automatic Silence Detection**: Detects natural conversational pauses (~1.4 seconds) to automatically stop recording, format text, and paste.
- **Draggable Mic Widget**: A non-activating floating capsule with live animated audio equalizer bars that respond to your voice volume.
- **Smart Formatting**: Post-processes raw speech to remove filler words ("um", "uh", "you know"), fix repetitions, and apply proper punctuation.
- **Dictation Modes**:
  - **Smart Polish**: Cleans conversational speech into structured, punctuated text.
  - **Raw Dictation**: Exact verbatim Whisper transcription.
  - **Bullet Points**: Converts continuous thoughts into bulleted action items.
  - **Email Draft**: Formats spoken ideas into a clean email structure.
- **Liquid Glass Interface**: Native macOS translucent styling (`NSVisualEffectView`) supporting System Appearance (auto Light/Dark), Dark Glass, and Light Glass.
- **Global Shortcut**: Press `Option + Space` anywhere on macOS to dictate (configurable to `Cmd + Shift + Space`, `Control + Space`, or `F8`).

---

## Prerequisites

- macOS 12.0 (Monterey) or later (Apple Silicon & Intel).
- A free Groq API key from [console.groq.com/keys](https://console.groq.com/keys) (recommended: 14,400 free requests/day) or an OpenAI API key.

---

## Installation

### Option 1: Direct Download (Recommended)

1. Download the latest release: **[TypeLess-macOS.zip](https://github.com/Vedant-07-jadhav/TypeLess/releases/latest/download/TypeLess-macOS.zip)** (or browse [GitHub Releases](https://github.com/Vedant-07-jadhav/TypeLess/releases)).
2. Unzip the file and move `TypeLess.app` into your `/Applications` folder.
3. Open `TypeLess.app`.

### Option 2: Build From Source

Ensure Xcode Command Line Tools are installed:

```bash
xcode-select --install
```

Clone the repository and build:

```bash
git clone https://github.com/Vedant-07-jadhav/TypeLess.git
cd TypeLess
./scripts/build.sh
```

To install directly to `/Applications`:

```bash
./scripts/install.sh
```

---

## Setup & Configuration

1. Launch TypeLess. The Settings window will open automatically on first launch (or click the menu bar icon > **Settings...**).
2. Under **AI & Speech Provider**, paste your Groq or OpenAI API key.
3. Click **Test Connection** to confirm connectivity.
4. Set your preferred global shortcut, dictation profile, and appearance theme.
5. Click **Save & Apply**.

---

## macOS Permissions

TypeLess requires two standard macOS permissions:

1. **Microphone**: Used to capture audio while dictating.
   - *Prompted on first recording, or enable in System Settings > Privacy & Security > Microphone.*
2. **Accessibility**: Used to simulate `Cmd + V` to insert transcribed text at your active cursor.
   - *Enable in System Settings > Privacy & Security > Accessibility.*
   - *Note: If Accessibility is disabled, TypeLess still copies the formatted text to your clipboard so you can paste manually.*

---

## Project Structure

```
TypeLess/
├── TypeLess.app/          # Compiled macOS application bundle
├── TypeLess-macOS.zip     # Compressed release package
├── AppIcon.icns           # Native macOS application icon
├── Info.plist             # macOS bundle configuration
├── src/
│   ├── main.swift         # Application entry point
│   ├── AppDelegate.swift  # Menu bar status item, menu lifecycle, state machine
│   ├── AudioRecorder.swift# Audio capture, metering, and silence detection
│   ├── WhisperService.swift# Whisper transcription and LLM post-processing
│   ├── HotkeyManager.swift# Carbon-based system-wide global hotkey handler
│   ├── AutoPaster.swift   # Pasteboard management and simulated keystrokes
│   ├── FloatingHUD.swift  # Floating Dynamic Island widget with live visualizer
│   ├── SettingsWindow.swift# Preferences window with Liquid Glass styling
│   └── Config.swift       # Persistent configuration and theme management
├── scripts/
│   ├── build.sh           # Compiler and codesigning script
│   ├── run.sh             # Launch and restart script
│   ├── install.sh         # Helper to copy to /Applications
│   └── package_dmg.sh     # Release packaging script
├── LICENSE.md             # MIT License
└── README.md
```

---

## License

This project is licensed under the MIT License. See [LICENSE.md](LICENSE.md) for details.
