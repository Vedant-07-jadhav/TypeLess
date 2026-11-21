import Foundation
import AppKit
import ApplicationServices

class AutoPaster {
    static let shared = AutoPaster()

    func paste(text: String, targetApp: NSRunningApplication? = nil, completion: ((Bool) -> Void)? = nil) {
        // 1. Always copy text to clipboard immediately
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // If user disabled auto-paste in settings, stop here
        guard AppConfig.shared.autoPaste else {
            completion?(true)
            return
        }

        // 2. Reactivate the target application where the user had their cursor
        if let target = targetApp, target.bundleIdentifier != Bundle.main.bundleIdentifier {
            if #available(macOS 14.0, *) {
                target.activate()
            } else {
                target.activate(options: .activateIgnoringOtherApps)
            }
        }

        // 3. Always dispatch simulated Cmd+V after target window settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.simulateCmdV()
            let trusted = AXIsProcessTrusted()
            completion?(trusted)
        }
    }

    private func simulateCmdV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode: CGKeyCode = 9 // Virtual key for 'v'
        let cmdFlag = CGEventFlags.maskCommand

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }

        keyDown.flags = cmdFlag
        keyUp.flags = cmdFlag

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
