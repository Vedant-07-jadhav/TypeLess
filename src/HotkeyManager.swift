import Foundation
import Carbon
import AppKit

class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    var onHotKeyPressed: (() -> Void)?

    private init() {}

    func setup() {
        registerCurrentHotKey()
    }

    func registerCurrentHotKey() {
        unregisterHotKey()

        let choice = AppConfig.shared.hotKeyChoice
        var keyCode: UInt32 = 49 // Space
        var modifiers: UInt32 = UInt32(optionKey) // Option

        switch choice {
        case .optionSpace:
            keyCode = 49
            modifiers = UInt32(optionKey)
        case .cmdShiftSpace:
            keyCode = 49
            modifiers = UInt32(cmdKey | shiftKey)
        case .ctrlSpace:
            keyCode = 49
            modifiers = UInt32(controlKey)
        case .f8:
            keyCode = 100 // F8
            modifiers = 0
        }

        // Install event handler if not already installed
        if eventHandlerRef == nil {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let err = InstallEventHandler(GetApplicationEventTarget(), { (_, _, _) -> OSStatus in
                DispatchQueue.main.async {
                    HotkeyManager.shared.onHotKeyPressed?()
                }
                return noErr
            }, 1, &eventType, nil, &eventHandlerRef)

            if err != noErr {
                print("TypeLess: Failed to install event handler: \(err)")
            }
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x544C), id: 1) // "TL" (TypeLess)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            print("TypeLess: Failed to register hotkey \(choice.displayName): \(status)")
        } else {
            print("TypeLess: Registered hotkey \(choice.displayName)")
        }
    }

    func unregisterHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    deinit {
        unregisterHotKey()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
        }
    }
}
