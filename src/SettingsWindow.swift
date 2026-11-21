import Foundation
import AppKit

class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private var visualEffectView: NSVisualEffectView!
    private var providerPopUp: NSPopUpButton!
    private var apiKeyField: NSSecureTextField!
    private var apiKeyVisibleField: NSTextField!
    private var showApiKeyCheckbox: NSButton!
    private var testConnectionButton: NSButton!
    private var testStatusLabel: NSTextField!

    private var modePopUp: NSPopUpButton!
    private var hotkeyPopUp: NSPopUpButton!
    private var themePopUp: NSPopUpButton!

    private var autoPasteCheckbox: NSButton!
    private var autoStopSilenceCheckbox: NSButton!
    private var showHUDCheckbox: NSButton!
    private var soundEffectsCheckbox: NSButton!

    private var micStatusLabel: NSTextField!
    private var micActionButton: NSButton!
    private var axStatusLabel: NSTextField!
    private var axActionButton: NSButton!
    private var axRefreshButton: NSButton!
    private var permTimer: Timer?

    init() {
        let windowWidth: CGFloat = 520
        let windowHeight: CGFloat = 720

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "TypeLess Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        guard let window = window else { return }
        let winBounds = window.contentRect(forFrameRect: window.frame)
        let totalW = winBounds.width
        let totalH = winBounds.height

        // Root Liquid Glass Background
        visualEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: totalW, height: totalH))
        visualEffectView.material = .underWindowBackground
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        window.contentView = visualEffectView

        // 1. Header (Top)
        let headerY: CGFloat = totalH - 72
        let iconView = NSImageView(frame: NSRect(x: 28, y: headerY - 4, width: 44, height: 44))
        if let img = NSImage(named: "AppIcon") ?? NSImage(systemSymbolName: "waveform.badge.mic", accessibilityDescription: nil) {
            iconView.image = img
        }
        visualEffectView.addSubview(iconView)

        let titleLabel = NSTextField(labelWithString: "TypeLess")
        titleLabel.font = NSFont.systemFont(ofSize: 19, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 82, y: headerY + 14, width: 200, height: 24)
        visualEffectView.addSubview(titleLabel)

        let subtitleLabel = NSTextField(labelWithString: "Voice-to-Text at the Speed of Thought")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.frame = NSRect(x: 82, y: headerY - 6, width: 350, height: 18)
        visualEffectView.addSubview(subtitleLabel)

        var curY: CGFloat = totalH - 96

        // 2. Section: AI & Speech Provider (Card)
        curY -= 150
        let card1 = createCard(x: 20, y: curY, w: totalW - 40, h: 142)
        visualEffectView.addSubview(card1)

        let s1Header = createSectionHeader(title: "AI & Speech Provider", x: 16, y: 114)
        card1.addSubview(s1Header)

        let pLabel = createFieldLabel(title: "Provider:", x: 16, y: 84)
        card1.addSubview(pLabel)

        providerPopUp = NSPopUpButton(frame: NSRect(x: 95, y: 81, width: 355, height: 26))
        for p in APIProvider.allCases {
            providerPopUp.addItem(withTitle: p.displayName)
        }
        providerPopUp.target = self
        providerPopUp.action = #selector(providerChanged)
        card1.addSubview(providerPopUp)

        let kLabel = createFieldLabel(title: "API Key:", x: 16, y: 52)
        card1.addSubview(kLabel)

        apiKeyField = NSSecureTextField(frame: NSRect(x: 95, y: 52, width: 285, height: 22))
        apiKeyField.placeholderString = "Enter your API key..."
        card1.addSubview(apiKeyField)

        apiKeyVisibleField = NSTextField(frame: NSRect(x: 95, y: 52, width: 285, height: 22))
        apiKeyVisibleField.placeholderString = "Enter your API key..."
        apiKeyVisibleField.isHidden = true
        card1.addSubview(apiKeyVisibleField)

        showApiKeyCheckbox = NSButton(checkboxWithTitle: "Show", target: self, action: #selector(toggleShowApiKey))
        showApiKeyCheckbox.frame = NSRect(x: 390, y: 52, width: 60, height: 20)
        card1.addSubview(showApiKeyCheckbox)

        let getKeyBtn = NSButton(title: "Get Free Groq Key (instant)", target: self, action: #selector(openAPIKeyPage))
        getKeyBtn.bezelStyle = .inline
        getKeyBtn.frame = NSRect(x: 95, y: 22, width: 200, height: 20)
        card1.addSubview(getKeyBtn)

        testConnectionButton = NSButton(title: "Test Connection", target: self, action: #selector(testConnection))
        testConnectionButton.bezelStyle = .rounded
        testConnectionButton.frame = NSRect(x: 320, y: 20, width: 130, height: 24)
        card1.addSubview(testConnectionButton)

        testStatusLabel = NSTextField(labelWithString: "")
        testStatusLabel.font = NSFont.systemFont(ofSize: 11)
        testStatusLabel.frame = NSRect(x: 95, y: 4, width: 355, height: 16)
        card1.addSubview(testStatusLabel)

        // 3. Section: Dictation & Shortcut (Card)
        curY -= 124
        let card2 = createCard(x: 20, y: curY, w: totalW - 40, h: 112)
        visualEffectView.addSubview(card2)

        let s2Header = createSectionHeader(title: "Dictation & Shortcut", x: 16, y: 84)
        card2.addSubview(s2Header)

        let mLabel = createFieldLabel(title: "Mode:", x: 16, y: 54)
        card2.addSubview(mLabel)

        modePopUp = NSPopUpButton(frame: NSRect(x: 95, y: 51, width: 355, height: 26))
        for m in DictationMode.allCases {
            modePopUp.addItem(withTitle: m.displayName)
        }
        card2.addSubview(modePopUp)

        let scLabel = createFieldLabel(title: "Shortcut:", x: 16, y: 22)
        card2.addSubview(scLabel)

        hotkeyPopUp = NSPopUpButton(frame: NSRect(x: 95, y: 19, width: 355, height: 26))
        for h in HotKeyChoice.allCases {
            hotkeyPopUp.addItem(withTitle: h.displayName)
        }
        card2.addSubview(hotkeyPopUp)

        // 4. Section: Appearance & Behavior (Card)
        curY -= 170
        let card3 = createCard(x: 20, y: curY, w: totalW - 40, h: 158)
        visualEffectView.addSubview(card3)

        let s3Header = createSectionHeader(title: "Preferences & Appearance", x: 16, y: 130)
        card3.addSubview(s3Header)

        let tLabel = createFieldLabel(title: "Theme:", x: 16, y: 102)
        card3.addSubview(tLabel)

        themePopUp = NSPopUpButton(frame: NSRect(x: 95, y: 99, width: 355, height: 26))
        for t in AppTheme.allCases {
            themePopUp.addItem(withTitle: t.displayName)
        }
        themePopUp.target = self
        themePopUp.action = #selector(themeChanged)
        card3.addSubview(themePopUp)

        autoPasteCheckbox = NSButton(checkboxWithTitle: "Auto-paste transcript into active app at cursor", target: nil, action: nil)
        autoPasteCheckbox.frame = NSRect(x: 16, y: 74, width: 440, height: 20)
        card3.addSubview(autoPasteCheckbox)

        autoStopSilenceCheckbox = NSButton(checkboxWithTitle: "Auto-stop recording when you pause speaking (Silence Detection)", target: nil, action: nil)
        autoStopSilenceCheckbox.frame = NSRect(x: 16, y: 50, width: 440, height: 20)
        card3.addSubview(autoStopSilenceCheckbox)

        showHUDCheckbox = NSButton(checkboxWithTitle: "Show draggable floating mic widget on screen", target: nil, action: nil)
        showHUDCheckbox.frame = NSRect(x: 16, y: 26, width: 440, height: 20)
        card3.addSubview(showHUDCheckbox)

        soundEffectsCheckbox = NSButton(checkboxWithTitle: "Play audio feedback chimes on start and finish", target: nil, action: nil)
        soundEffectsCheckbox.frame = NSRect(x: 16, y: 2, width: 440, height: 20)
        card3.addSubview(soundEffectsCheckbox)

        // 5. Section: macOS Permissions (Card)
        curY -= 104
        let card4 = createCard(x: 20, y: curY, w: totalW - 40, h: 94)
        visualEffectView.addSubview(card4)

        let s4Header = createSectionHeader(title: "macOS System Permissions", x: 16, y: 66)
        card4.addSubview(s4Header)

        let micLbl = createFieldLabel(title: "Microphone:", x: 16, y: 38)
        card4.addSubview(micLbl)

        micStatusLabel = NSTextField(labelWithString: "Checking...")
        micStatusLabel.font = NSFont.systemFont(ofSize: 12)
        micStatusLabel.frame = NSRect(x: 120, y: 38, width: 190, height: 20)
        card4.addSubview(micStatusLabel)

        micActionButton = NSButton(title: "Request Access", target: self, action: #selector(requestMicAccess))
        micActionButton.bezelStyle = .rounded
        micActionButton.frame = NSRect(x: 320, y: 34, width: 130, height: 24)
        card4.addSubview(micActionButton)

        let axLbl = createFieldLabel(title: "Accessibility:", x: 16, y: 10)
        card4.addSubview(axLbl)

        axStatusLabel = NSTextField(labelWithString: "Checking...")
        axStatusLabel.font = NSFont.systemFont(ofSize: 11)
        axStatusLabel.frame = NSRect(x: 120, y: 10, width: 200, height: 20)
        card4.addSubview(axStatusLabel)

        axActionButton = NSButton(title: "Open Settings", target: self, action: #selector(openAXSettings))
        axActionButton.bezelStyle = .rounded
        axActionButton.frame = NSRect(x: 325, y: 6, width: 95, height: 24)
        card4.addSubview(axActionButton)

        axRefreshButton = NSButton(title: "↻", target: self, action: #selector(refreshPermissions))
        axRefreshButton.bezelStyle = .rounded
        axRefreshButton.toolTip = "Check status"
        axRefreshButton.frame = NSRect(x: 422, y: 6, width: 32, height: 24)
        card4.addSubview(axRefreshButton)

        // 6. Fixed Dedicated Footer Bar (Zero Overlap Guaranteed!)
        let footerBar = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: totalW, height: 60))
        footerBar.material = .headerView
        footerBar.blendingMode = .withinWindow
        footerBar.state = .active
        visualEffectView.addSubview(footerBar)

        let footerSep = NSBox(frame: NSRect(x: 0, y: 59, width: totalW, height: 1))
        footerSep.boxType = .separator
        footerBar.addSubview(footerSep)

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(closeWindow))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"
        cancelBtn.frame = NSRect(x: totalW - 245, y: 14, width: 100, height: 32)
        footerBar.addSubview(cancelBtn)

        let saveBtn = NSButton(title: "Save & Apply", target: self, action: #selector(saveAndClose))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        saveBtn.frame = NSRect(x: totalW - 140, y: 14, width: 120, height: 32)
        footerBar.addSubview(saveBtn)
    }

    private func createCard(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> NSView {
        let card = NSView(frame: NSRect(x: x, y: y, width: w, height: h))
        card.wantsLayer = true
        card.layer?.cornerRadius = 10
        card.layer?.masksToBounds = true
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.28).cgColor
        card.layer?.borderWidth = 1.0
        card.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.25).cgColor
        return card
    }

    private func createSectionHeader(title: String, x: CGFloat, y: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: x, y: y, width: 350, height: 18)
        return label
    }

    private func createFieldLabel(title: String, x: CGFloat, y: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = .labelColor
        label.frame = NSRect(x: x, y: y, width: 90, height: 20)
        return label
    }

    func showSettings() {
        loadCurrentValues()
        applyTheme()
        updatePermissionsStatus()

        // Auto-refresh permissions every 1s while Settings window is open
        permTimer?.invalidate()
        permTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updatePermissionsStatus()
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func loadCurrentValues() {
        let config = AppConfig.shared

        let currentKey = config.apiKey
        apiKeyField.stringValue = currentKey
        apiKeyVisibleField.stringValue = currentKey

        if let idx = APIProvider.allCases.firstIndex(of: config.provider) {
            providerPopUp.selectItem(at: idx)
        }
        if let idx = DictationMode.allCases.firstIndex(of: config.mode) {
            modePopUp.selectItem(at: idx)
        }
        if let idx = HotKeyChoice.allCases.firstIndex(of: config.hotKeyChoice) {
            hotkeyPopUp.selectItem(at: idx)
        }
        if let idx = AppTheme.allCases.firstIndex(of: config.theme) {
            themePopUp.selectItem(at: idx)
        }

        autoPasteCheckbox.state = config.autoPaste ? .on : .off
        autoStopSilenceCheckbox.state = config.autoStopOnSilence ? .on : .off
        showHUDCheckbox.state = config.showFloatingWidget ? .on : .off
        soundEffectsCheckbox.state = config.soundEffects ? .on : .off
        testStatusLabel.stringValue = ""
    }

    private func applyTheme() {
        let theme = AppConfig.shared.theme
        window?.appearance = theme.appearance
    }

    @objc private func themeChanged() {
        let selectedIdx = themePopUp.indexOfSelectedItem
        if selectedIdx >= 0 && selectedIdx < AppTheme.allCases.count {
            let chosen = AppTheme.allCases[selectedIdx]
            window?.appearance = chosen.appearance
        }
    }

    @objc private func toggleShowApiKey() {
        let isVisible = (showApiKeyCheckbox.state == .on)
        if isVisible {
            apiKeyVisibleField.stringValue = apiKeyField.stringValue
            apiKeyField.isHidden = true
            apiKeyVisibleField.isHidden = false
        } else {
            apiKeyField.stringValue = apiKeyVisibleField.stringValue
            apiKeyVisibleField.isHidden = true
            apiKeyField.isHidden = false
        }
    }

    @objc private func providerChanged() {
        let selectedIdx = providerPopUp.indexOfSelectedItem
        if selectedIdx >= 0 && selectedIdx < APIProvider.allCases.count {
            testStatusLabel.stringValue = ""
        }
    }

    @objc private func openAPIKeyPage() {
        let selectedIdx = providerPopUp.indexOfSelectedItem
        let provider = APIProvider.allCases[selectedIdx]
        let urlStr: String
        switch provider {
        case .groq:
            urlStr = "https://console.groq.com/keys"
        case .openai:
            urlStr = "https://platform.openai.com/api-keys"
        }
        if let url = URL(string: urlStr) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func testConnection() {
        let key = showApiKeyCheckbox.state == .on ? apiKeyVisibleField.stringValue : apiKeyField.stringValue
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedIdx = providerPopUp.indexOfSelectedItem
        let provider = APIProvider.allCases[selectedIdx]

        guard !trimmedKey.isEmpty else {
            testStatusLabel.stringValue = "Please enter an API key first."
            testStatusLabel.textColor = .systemOrange
            return
        }

        testStatusLabel.stringValue = "Testing connection to \(provider.rawValue.capitalized)..."
        testStatusLabel.textColor = .secondaryLabelColor
        testConnectionButton.isEnabled = false

        WhisperService.shared.testConnection(provider: provider, apiKey: trimmedKey) { [weak self] result in
            DispatchQueue.main.async {
                self?.testConnectionButton.isEnabled = true
                switch result {
                case .success(let msg):
                    self?.testStatusLabel.stringValue = "\(msg)"
                    self?.testStatusLabel.textColor = .systemGreen
                case .failure(let err):
                    self?.testStatusLabel.stringValue = "\(err.localizedDescription)"
                    self?.testStatusLabel.textColor = .systemRed
                }
            }
        }
    }

    private func updatePermissionsStatus() {
        // Microphone
        AudioRecorder.checkMicrophonePermission { [weak self] granted in
            if granted {
                self?.micStatusLabel.stringValue = "Granted"
                self?.micStatusLabel.textColor = .systemGreen
                self?.micActionButton.isEnabled = false
            } else {
                self?.micStatusLabel.stringValue = "Permission Needed"
                self?.micStatusLabel.textColor = .systemOrange
                self?.micActionButton.isEnabled = true
            }
        }

        // Accessibility
        let axGranted = AutoPaster.shared.isAccessibilityGranted()
        if axGranted {
            axStatusLabel.stringValue = "Granted (Auto-paste ready)"
            axStatusLabel.textColor = .systemGreen
            axActionButton.title = "Verified ✓"
            axActionButton.isEnabled = false
        } else {
            axStatusLabel.stringValue = "Toggle ON in Settings (restart app)"
            axStatusLabel.textColor = .systemOrange
            axActionButton.title = "Open Settings"
            axActionButton.isEnabled = true
        }
    }

    @objc private func refreshPermissions() {
        updatePermissionsStatus()
    }

    @objc private func requestMicAccess() {
        AudioRecorder.checkMicrophonePermission { [weak self] _ in
            self?.updatePermissionsStatus()
        }
    }

    @objc private func openAXSettings() {
        AutoPaster.shared.openAccessibilitySettings()
    }

    @objc private func saveAndClose() {
        permTimer?.invalidate()
        permTimer = nil

        let config = AppConfig.shared

        let key = showApiKeyCheckbox.state == .on ? apiKeyVisibleField.stringValue : apiKeyField.stringValue
        config.apiKey = key

        let pIdx = providerPopUp.indexOfSelectedItem
        if pIdx >= 0 && pIdx < APIProvider.allCases.count {
            config.provider = APIProvider.allCases[pIdx]
        }

        let mIdx = modePopUp.indexOfSelectedItem
        if mIdx >= 0 && mIdx < DictationMode.allCases.count {
            config.mode = DictationMode.allCases[mIdx]
        }

        let hIdx = hotkeyPopUp.indexOfSelectedItem
        if hIdx >= 0 && hIdx < HotKeyChoice.allCases.count {
            config.hotKeyChoice = HotKeyChoice.allCases[hIdx]
        }

        let tIdx = themePopUp.indexOfSelectedItem
        if tIdx >= 0 && tIdx < AppTheme.allCases.count {
            config.theme = AppTheme.allCases[tIdx]
            applyTheme()
        }

        config.autoPaste = (autoPasteCheckbox.state == .on)
        config.autoStopOnSilence = (autoStopSilenceCheckbox.state == .on)
        config.showFloatingWidget = (showHUDCheckbox.state == .on)
        config.soundEffects = (soundEffectsCheckbox.state == .on)

        if config.showFloatingWidget {
            FloatingHUD.shared.showWidget()
        } else {
            FloatingHUD.shared.hide()
        }

        // Refresh hotkey registration
        HotkeyManager.shared.registerCurrentHotKey()

        window?.orderOut(nil)
    }

    @objc private func closeWindow() {
        permTimer?.invalidate()
        permTimer = nil
        window?.orderOut(nil)
    }
}
