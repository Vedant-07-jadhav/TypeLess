import Foundation
import AppKit

// MARK: - Live Dancing Audio Waveform Visualizer
class WaveformView: NSView {
    private var barLayers: [CALayer] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        let barCount = 4
        let barW: CGFloat = 3.0
        let spacing: CGFloat = 3.0
        let totalW = CGFloat(barCount) * barW + CGFloat(barCount - 1) * spacing
        let startX = (frame.width - totalW) / 2

        for i in 0..<barCount {
            let layer = CALayer()
            layer.backgroundColor = NSColor.white.cgColor
            layer.cornerRadius = barW / 2
            let x = startX + CGFloat(i) * (barW + spacing)
            layer.frame = CGRect(x: x, y: (frame.height - 6) / 2, width: barW, height: 6)
            self.layer?.addSublayer(layer)
            barLayers.append(layer)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateLevel(_ level: Float) {
        let multipliers: [CGFloat] = [0.6, 1.0, 0.85, 0.5]
        for (i, layer) in barLayers.enumerated() {
            let targetH = max(5, CGFloat(level) * 18 * multipliers[i] + 5)
            let y = (bounds.height - targetH) / 2
            var f = layer.frame
            f.origin.y = y
            f.size.height = targetH
            layer.frame = f
        }
    }

    func reset() {
        for layer in barLayers {
            var f = layer.frame
            f.size.height = 6
            f.origin.y = (bounds.height - 6) / 2
            layer.frame = f
        }
    }
}

// MARK: - Modern Dynamic Island Floating Mic Widget
class FloatingHUD: NSObject {
    static let shared = FloatingHUD()

    private var panel: NSPanel?
    private var visualEffectView: NSVisualEffectView?
    private var micButton: NSButton?
    private var waveformView: WaveformView?
    private var statusLabel: NSTextField?
    private var modeBadgeLabel: NSTextField?
    private var settingsButton: NSButton?
    private var closeButton: NSButton?

    private var dismissTimer: Timer?
    private var elapsedTimer: Timer?
    private var recordSeconds: Int = 0

    var onMicButtonClicked: (() -> Void)?

    override init() {
        super.init()
        setupPanel()
        setupAudioLevelObserver()
    }

    private func setupPanel() {
        let width: CGFloat = 268
        let height: CGFloat = 52

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.level = .floating
        newPanel.hasShadow = true
        newPanel.isMovableByWindowBackground = true
        newPanel.hidesOnDeactivate = false
        newPanel.alphaValue = 0.0

        // Liquid Glass Capsule Base
        let effectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        effectView.material = .hudWindow
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = height / 2
        effectView.layer?.masksToBounds = true
        effectView.layer?.borderWidth = 1.0
        effectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.22).cgColor

        // 1. Action Orb / Mic Button
        let orbSize: CGFloat = 38
        let btn = NSButton(frame: NSRect(x: 7, y: (height - orbSize) / 2, width: orbSize, height: orbSize))
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = orbSize / 2
        btn.layer?.masksToBounds = true
        btn.layer?.backgroundColor = NSColor.systemIndigo.withAlphaComponent(0.4).cgColor
        btn.target = self
        btn.action = #selector(handleMicClick)
        btn.toolTip = "Click to Dictate (⌥ Space)"
        effectView.addSubview(btn)
        self.micButton = btn

        // Live Dancing Waveform View (inside Orb when recording)
        let wave = WaveformView(frame: NSRect(x: 0, y: 0, width: orbSize, height: orbSize))
        wave.isHidden = true
        btn.addSubview(wave)
        self.waveformView = wave

        updateMicButtonIcon(isRecording: false, isProcessing: false)

        // 2. Primary Status Label
        let label = NSTextField(frame: NSRect(x: 52, y: 24, width: 156, height: 18))
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.textColor = .labelColor
        label.font = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
        label.alignment = .left
        label.lineBreakMode = .byTruncatingTail
        label.stringValue = "Click to Speak"
        effectView.addSubview(label)
        self.statusLabel = label

        // 3. Subtitle / Mode Badge Label
        let badge = NSTextField(frame: NSRect(x: 52, y: 8, width: 156, height: 14))
        badge.isEditable = false
        badge.isSelectable = false
        badge.isBordered = false
        badge.backgroundColor = .clear
        badge.textColor = .secondaryLabelColor
        badge.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        badge.alignment = .left
        badge.stringValue = "Press ⌥ Space to start"
        effectView.addSubview(badge)
        self.modeBadgeLabel = badge

        // 4. Subtle Settings Button (Gear)
        let gearBtn = NSButton(frame: NSRect(x: width - 48, y: (height - 20) / 2, width: 20, height: 20))
        gearBtn.bezelStyle = .regularSquare
        gearBtn.isBordered = false
        if let gImg = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "Settings") {
            let cfg = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
            gearBtn.image = gImg.withSymbolConfiguration(cfg)
        }
        gearBtn.target = self
        gearBtn.action = #selector(handleOpenSettings)
        gearBtn.toolTip = "Open Settings"
        effectView.addSubview(gearBtn)
        self.settingsButton = gearBtn

        // 5. Subtle Close Button (X)
        let close = NSButton(frame: NSRect(x: width - 26, y: (height - 20) / 2, width: 20, height: 20))
        close.bezelStyle = .regularSquare
        close.isBordered = false
        if let xImg = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Hide Widget") {
            let cfg = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
            close.image = xImg.withSymbolConfiguration(cfg)
        }
        close.target = self
        close.action = #selector(handleClose)
        close.toolTip = "Hide widget (Reopen from menu bar)"
        effectView.addSubview(close)
        self.closeButton = close

        newPanel.contentView = effectView
        self.panel = newPanel
        self.visualEffectView = effectView

        positionOnScreen()
    }

    private func setupAudioLevelObserver() {
        AudioRecorder.shared.onAudioLevel = { [weak self] level in
            DispatchQueue.main.async {
                self?.waveformView?.updateLevel(level)
            }
        }
    }

    private func positionOnScreen() {
        guard let panel = panel, let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        let x = screenRect.origin.x + (screenRect.width - panel.frame.width) / 2
        let y = screenRect.origin.y + 70 // Floating gracefully above dock
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func showWidget() {
        guard AppConfig.shared.showFloatingWidget else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let panel = self.panel else { return }
            panel.appearance = AppConfig.shared.theme.appearance
            self.dismissTimer?.invalidate()
            self.updateIdleUI()
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                panel.animator().alphaValue = 1.0
            }
        }
    }

    @objc private func handleMicClick() {
        onMicButtonClicked?()
    }

    @objc private func handleOpenSettings() {
        SettingsWindowController.shared.showSettings()
    }

    @objc private func handleClose() {
        AppConfig.shared.showFloatingWidget = false
        hide()
    }

    func showRecording() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let panel = self.panel else { return }
            self.dismissTimer?.invalidate()
            self.elapsedTimer?.invalidate()
            self.recordSeconds = 0

            // Glowing red pulse border
            self.visualEffectView?.layer?.borderColor = NSColor.systemRed.withAlphaComponent(0.55).cgColor

            self.waveformView?.isHidden = false
            self.waveformView?.reset()
            self.micButton?.image = nil
            self.micButton?.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.85).cgColor

            self.statusLabel?.stringValue = "Listening..."
            self.statusLabel?.textColor = .systemRed

            self.modeBadgeLabel?.stringValue = "00:00 • speak naturally"

            // Start live timer
            self.elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.recordSeconds += 1
                let mins = self.recordSeconds / 60
                let secs = self.recordSeconds % 60
                let timeStr = String(format: "%02d:%02d", mins, secs)
                self.modeBadgeLabel?.stringValue = "\(timeStr) • auto-stops on silence"
            }

            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                panel.animator().alphaValue = 1.0
            }
        }
    }

    func showProcessing() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let panel = self.panel else { return }
            self.dismissTimer?.invalidate()
            self.elapsedTimer?.invalidate()

            // Glowing purple rim
            self.visualEffectView?.layer?.borderColor = NSColor.systemPurple.withAlphaComponent(0.55).cgColor

            self.waveformView?.isHidden = true
            self.updateMicButtonIcon(isRecording: false, isProcessing: true)
            self.micButton?.layer?.backgroundColor = NSColor.systemPurple.withAlphaComponent(0.8).cgColor

            self.statusLabel?.stringValue = "Polishing speech..."
            self.statusLabel?.textColor = .systemPurple

            self.modeBadgeLabel?.stringValue = "Whisper AI processing"

            panel.orderFrontRegardless()
        }
    }

    func showSuccess(message: String = "✓ Pasted at cursor!") {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dismissTimer?.invalidate()
            self.elapsedTimer?.invalidate()

            // Glowing emerald green rim
            self.visualEffectView?.layer?.borderColor = NSColor.systemGreen.withAlphaComponent(0.6).cgColor

            self.waveformView?.isHidden = true
            self.updateMicButtonIcon(isRecording: false, isProcessing: false, isSuccess: true)
            self.micButton?.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.85).cgColor

            self.statusLabel?.stringValue = message
            self.statusLabel?.textColor = .systemGreen

            self.modeBadgeLabel?.stringValue = "Ready for next dictation"

            // Return gracefully to idle after 2.2 seconds
            self.dismissTimer = Timer.scheduledTimer(withTimeInterval: 2.2, repeats: false) { [weak self] _ in
                self?.updateIdleUI()
            }
        }
    }

    func showError(message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dismissTimer?.invalidate()
            self.elapsedTimer?.invalidate()

            self.visualEffectView?.layer?.borderColor = NSColor.systemOrange.withAlphaComponent(0.6).cgColor

            self.waveformView?.isHidden = true
            self.updateMicButtonIcon(isRecording: false, isProcessing: false)
            self.micButton?.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.85).cgColor

            self.statusLabel?.stringValue = message
            self.statusLabel?.textColor = .systemOrange

            self.modeBadgeLabel?.stringValue = "Check settings"

            self.dismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.updateIdleUI()
            }
        }
    }

    private func updateIdleUI() {
        self.elapsedTimer?.invalidate()
        self.waveformView?.isHidden = true
        self.visualEffectView?.layer?.borderColor = NSColor.white.withAlphaComponent(0.22).cgColor

        self.updateMicButtonIcon(isRecording: false, isProcessing: false)
        self.micButton?.layer?.backgroundColor = NSColor.systemIndigo.withAlphaComponent(0.4).cgColor

        self.statusLabel?.stringValue = "Click to Speak"
        self.statusLabel?.textColor = .labelColor

        let hotkey = AppConfig.shared.hotKeyChoice == .optionSpace ? "⌥ Space" : "Shortcut"
        self.modeBadgeLabel?.stringValue = "Press \(hotkey) to start"
    }

    private func updateMicButtonIcon(isRecording: Bool, isProcessing: Bool, isSuccess: Bool = false) {
        guard let btn = micButton else { return }
        if isRecording {
            btn.image = nil
        } else if isProcessing {
            if let img = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Processing") {
                let cfg = NSImage.SymbolConfiguration(pointSize: 15, weight: .bold)
                btn.image = img.withSymbolConfiguration(cfg)
            }
        } else if isSuccess {
            if let img = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Success") {
                let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .heavy)
                btn.image = img.withSymbolConfiguration(cfg)
            }
        } else {
            if let img = NSImage(systemSymbolName: "waveform.badge.mic", accessibilityDescription: "Idle") ?? NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Idle") {
                let cfg = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
                btn.image = img.withSymbolConfiguration(cfg)
            }
        }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let panel = self.panel else { return }
            self.elapsedTimer?.invalidate()
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                panel.animator().alphaValue = 0.0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        }
    }
}
