# TypeLess

> Voice-to-text at the speed of thought. Speak naturally anywhere on macOS and type less.

TypeLess is a lightweight, native macOS speech-to-text utility powered by Whisper and AI language models. It enables system-wide voice dictation across any application—such as Slack, Notes, Xcode, VS Code, and web browsers—automatically inserting polished, punctuated text directly at your cursor.

---

## Features

- **Sub-Second Latency**: Transcribes voice input in ~300ms using Groq-accelerated `whisper-large-v3-turbo` or OpenAI's `whisper-1`.
- **Automatic Silence Detection**: Detects natural conversational pauses (~1.4 seconds) to automatically stop recording, transcribe, and insert text without manual keystrokes.
- **Floating Interactive Widget**: A draggable, non-activating floating mic widget that stays accessible on-screen without stealing window focus from your active document or chat.
- **Smart Formatting**: Post-processes raw speech to eliminate disfluencies (e.g., filler words like "um", "uh", "you know"), fix stutters, and structure grammar and punctuation while retaining original phrasing and vocabulary.
- **Multiple Dictation Profiles**:
  - **Smart Polish**: Formats natural speech into clean, punctuated prose.
  - **Raw Dictation**: Direct, verbatim transcription from the speech model.
  - **Bullet Points**: Converts continuous thoughts into actionable bulleted items.
  - **Email Draft**: Structures voice streams into a standard email format.
- **Native macOS Liquid Glass Design**: Built using native AppKit translucent materials (`NSVisualEffectView`) supporting System Appearance (automatically tracks macOS Light/Dark mode), explicit Dark Glass, and Light Glass themes.
- **Global Shortcut**: System-wide trigger via `Option + Space` (configurable to `Cmd + Shift + Space`, `Control + Space`, or `F8`).

---

## Prerequisites

- macOS 12.0 (Monterey) or later (Apple Silicon and Intel supported).
- A free Groq API key (from [console.groq.com](https://console.groq.com)) or an OpenAI API key.

---

## Installation

### Option 1: Using the Pre-Built Application

1. Download the latest `TypeLess-macOS.zip` release.
2. Unzip the archive and move `TypeLess.app` to your `/Applications` directory.
3. Launch `TypeLess.app`.

### Option 2: Building from Source

Ensure the Xcode Command Line Tools are installed:

```bash
xcode-select --install
```

Clone the repository and run the build script:

```bash
git clone https://github.com/your-username/TypeLess.git
cd TypeLess
./scripts/build.sh
```

To install directly to `/Applications`:

```bash
./scripts/install.sh
```

---

## Configuration

1. Launch TypeLess. The Settings window will open automatically on first launch (or select **Settings...** from the menu bar item).
2. Under **AI & Speech Provider**, paste your API key (Groq or OpenAI).
3. Click **Test Connection** to verify API communication.
4. Customize your preferred shortcut, dictation mode, and theme.
5. Click **Save & Apply**.

---

## macOS Permissions

TypeLess requires standard macOS system permissions to operate:

1. **Microphone**: Needed to capture audio for speech recognition.
   - *Prompt*: Requested on initial recording.
   - *Path*: System Settings > Privacy & Security > Microphone.

2. **Accessibility**: Needed to automatically insert transcribed text (`Cmd + V`) at the user's cursor across other applications.
   - *Path*: System Settings > Privacy & Security > Accessibility.
   - *Note*: If Accessibility is not enabled, TypeLess copies the transcribed text to your system clipboard, allowing manual pasting via `Cmd + V`.

---

## Project Structure

```
TypeLess/
├── TypeLess.app/          # Compiled macOS application bundle
├── TypeLess-macOS.zip     # Distribution archive
├── AppIcon.icns           # Native application icon
├── Info.plist             # macOS bundle configuration
├── src/
│   ├── main.swift         # Application entry point
│   ├── AppDelegate.swift  # Menu bar status item, menu lifecycle, state machine
│   ├── AudioRecorder.swift# 16kHz AAC capture and voice activity / silence detection
│   ├── WhisperService.swift# Speech-to-text API client and LLM post-processing
│   ├── HotkeyManager.swift# Carbon-based system-wide global hotkey handler
│   ├── AutoPaster.swift   # Pasteboard management and simulated keystroke dispatch
│   ├── FloatingHUD.swift  # Draggable, non-activating floating mic widget
│   ├── SettingsWindow.swift# Preferences window with Liquid Glass styling
│   └── Config.swift       # Persistent UserDefaults configuration and themes
├── scripts/
│   ├── build.sh           # Standalone Swift compiler and codesigning script
│   ├── run.sh             # Launch / restart utility script
│   ├── install.sh         # Copy to /Applications helper
│   └── package_dmg.sh     # Release packaging script
└── README.md
```

---

## License

This project is licensed under the MIT License. See the LICENSE file for details.
