import Foundation
import AppKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var toggleMenuItem: NSMenuItem!
    private var lastTranscriptMenuItem: NSMenuItem!
    private var modeSubmenu: NSMenu!
    private var widgetMenuItem: NSMenuItem!

    private var lastTranscript: String = ""
    private var lastTargetApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupMenu()
        setupHotkey()
        setupCallbacks()

        // Show floating on-screen mic widget
        FloatingHUD.shared.showWidget()

        // Check if API key is configured; if not, open Settings
        if AppConfig.shared.apiKey.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                SettingsWindowController.shared.showSettings()
            }
        } else {
            // Prompt mic access proactively
            AudioRecorder.checkMicrophonePermission { _ in }
        }
    }

    private func setupCallbacks() {
        // When user clicks the floating mic widget on screen
        FloatingHUD.shared.onMicButtonClicked = { [weak self] in
            self?.toggleDictation()
        }

        // When user stops speaking for ~1.4 seconds (Auto-Stop silence detection)
        AudioRecorder.shared.onSilenceDetected = { [weak self] in
            guard let self = self else { return }
            if AudioRecorder.shared.isRecording {
                self.stopAndProcess()
            }
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            setIdleIcon()
            button.toolTip = "TypeLess - Voice Dictation (⌥ Space)"
        }
    }

    private func setupMenu() {
        menu = NSMenu()

        toggleMenuItem = NSMenuItem(title: "● Start Dictation (\(AppConfig.shared.hotKeyChoice.displayName))", action: #selector(toggleDictation), keyEquivalent: "")
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Modes Submenu
        let modeMenuItem = NSMenuItem(title: "Mode", action: nil, keyEquivalent: "")
        modeSubmenu = NSMenu()
        rebuildModeSubmenu()
        modeMenuItem.submenu = modeSubmenu
        menu.addItem(modeMenuItem)

        widgetMenuItem = NSMenuItem(title: "Show Floating Mic Widget", action: #selector(toggleFloatingWidget), keyEquivalent: "")
        widgetMenuItem.target = self
        menu.addItem(widgetMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Last Transcript Item
        lastTranscriptMenuItem = NSMenuItem(title: "Last: (None yet)", action: #selector(copyLastTranscript), keyEquivalent: "")
        lastTranscriptMenuItem.target = self
        lastTranscriptMenuItem.isEnabled = false
        menu.addItem(lastTranscriptMenuItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "⚙️ Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: "About TypeLess", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit TypeLess", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleFloatingWidget() {
        AppConfig.shared.showFloatingWidget.toggle()
        if AppConfig.shared.showFloatingWidget {
            FloatingHUD.shared.showWidget()
        } else {
            FloatingHUD.shared.hide()
        }
    }

    private func rebuildModeSubmenu() {
        modeSubmenu.removeAllItems()
        let currentMode = AppConfig.shared.mode

        for mode in DictationMode.allCases {
            let item = NSMenuItem(title: mode.displayName, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            item.state = (mode == currentMode) ? .on : .off
            modeSubmenu.addItem(item)
        }
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? DictationMode else { return }
        AppConfig.shared.mode = mode
        rebuildModeSubmenu()
    }

    private func setupHotkey() {
        HotkeyManager.shared.onHotKeyPressed = { [weak self] in
            self?.toggleDictation()
        }
        HotkeyManager.shared.setup()
    }

    @objc func toggleDictation() {
        if AudioRecorder.shared.isRecording {
            stopAndProcess()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        if AppConfig.shared.apiKey.isEmpty {
            FloatingHUD.shared.showError(message: "⚠️ API Key missing. Open Settings.")
            SettingsWindowController.shared.showSettings()
            return
        }

        // Remember which app was active so we can paste back into it!
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != Bundle.main.bundleIdentifier {
            self.lastTargetApp = front
        }

        let result = AudioRecorder.shared.startRecording()
        if !result.success {
            FloatingHUD.shared.showError(message: result.error ?? "Failed to start recording")
            playSound(name: "Basso")
            return
        }

        playSound(name: "Tink")
        setRecordingIcon()
        toggleMenuItem.title = "■ Stop Dictation"
        FloatingHUD.shared.showRecording()
    }

    private func stopAndProcess() {
        playSound(name: "Pop")
        setProcessingIcon()
        toggleMenuItem.title = "⏳ Transcribing..."
        toggleMenuItem.isEnabled = false
        FloatingHUD.shared.showProcessing()

        let result = AudioRecorder.shared.stopRecording()
        guard let url = result.url else {
            resetToIdle()
            if let err = result.error {
                FloatingHUD.shared.showError(message: err)
            }
            return
        }

        WhisperService.shared.transcribeAndPolish(audioURL: url) { [weak self] res in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.resetToIdle()

                // Clean up audio file
                try? FileManager.default.removeItem(at: url)

                switch res {
                case .success(let text):
                    self.lastTranscript = text
                    self.updateLastTranscriptItem(text)

                    if AppConfig.shared.autoPaste {
                        AutoPaster.shared.paste(text: text, targetApp: self.lastTargetApp) { _ in
                            self.playSound(name: "Pop")
                            FloatingHUD.shared.showSuccess(message: "✓ Pasted at cursor!")
                        }
                    } else {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        FloatingHUD.shared.showSuccess(message: "✓ Copied to clipboard!")
                    }

                case .failure(let err):
                    self.playSound(name: "Basso")
                    FloatingHUD.shared.showError(message: err.localizedDescription)
                }
            }
        }
    }

    private func resetToIdle() {
        setIdleIcon()
        toggleMenuItem.title = "● Start Dictation (\(AppConfig.shared.hotKeyChoice.displayName))"
        toggleMenuItem.isEnabled = true
    }

    private func setIdleIcon() {
        guard let button = statusItem.button else { return }
        button.title = ""
        if let img = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "TypeLess Idle") {
            img.isTemplate = true
            button.image = img
        }
    }

    private func setRecordingIcon() {
        guard let button = statusItem.button else { return }
        button.title = " REC"
        if let img = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "TypeLess Recording") {
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            button.image = img.withSymbolConfiguration(config)
        }
    }

    private func setProcessingIcon() {
        guard let button = statusItem.button else { return }
        button.title = " ..."
        if let img = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "TypeLess Transcribing") {
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemPurple])
            button.image = img.withSymbolConfiguration(config)
        }
    }

    private func updateLastTranscriptItem(_ text: String) {
        lastTranscriptMenuItem.isEnabled = true
        let preview = text.prefix(28).replacingOccurrences(of: "\n", with: " ")
        lastTranscriptMenuItem.title = "Last: \"\(preview)...\" (Click to copy)"
    }

    @objc private func copyLastTranscript() {
        guard !lastTranscript.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastTranscript, forType: .string)
        FloatingHUD.shared.showSuccess(message: "✓ Copied to clipboard!")
    }

    private func playSound(name: String) {
        guard AppConfig.shared.soundEffects else { return }
        NSSound(named: name)?.play()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showSettings()
    }

    @objc private func openAbout() {
        let alert = NSAlert()
        alert.messageText = "TypeLess for Mac"
        alert.informativeText = "Version 1.0.0\n\nSpeak naturally anywhere on your Mac and type less.\nPowered by Whisper & AI.\n\nCreated with ❤️ for macOS."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quitApp() {
        AudioRecorder.shared.cancelRecording()
        FloatingHUD.shared.hide()
        HotkeyManager.shared.unregisterHotKey()
        NSApp.terminate(nil)
    }
}
