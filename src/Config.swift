import Foundation
import AppKit

enum AppTheme: String, CaseIterable {
    case system = "system"
    case dark = "dark"
    case light = "light"

    var displayName: String {
        switch self {
        case .system: return "System (Follow macOS)"
        case .dark: return "Dark Glass"
        case .light: return "Light Glass"
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .dark: return NSAppearance(named: .darkAqua)
        case .light: return NSAppearance(named: .aqua)
        }
    }
}

enum DictationMode: String, CaseIterable {
    case smart = "smart"
    case raw = "raw"
    case bullet = "bullet"
    case email = "email"

    var displayName: String {
        switch self {
        case .smart: return "Smart Polish (AI)"
        case .raw: return "Raw Dictation"
        case .bullet: return "Bullet Points"
        case .email: return "Email Draft"
        }
    }

    var shortName: String {
        switch self {
        case .smart: return "Smart Polish"
        case .raw: return "Raw"
        case .bullet: return "Bullets"
        case .email: return "Email"
        }
    }
}

enum HotKeyChoice: String, CaseIterable {
    case optionSpace = "option_space"
    case cmdShiftSpace = "cmd_shift_space"
    case ctrlSpace = "ctrl_space"
    case f8 = "f8"

    var displayName: String {
        switch self {
        case .optionSpace: return "Option + Space (⌥ Space)"
        case .cmdShiftSpace: return "Cmd + Shift + Space (⌘⇧ Space)"
        case .ctrlSpace: return "Control + Space (⌃ Space)"
        case .f8: return "Function Key F8"
        }
    }
}

enum APIProvider: String, CaseIterable {
    case groq = "groq"
    case openai = "openai"

    var displayName: String {
        switch self {
        case .groq: return "Groq (Free & Fast ~300ms)"
        case .openai: return "OpenAI (whisper-1 + gpt-4o-mini)"
        }
    }

    var whisperURL: URL {
        switch self {
        case .groq:
            return URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!
        case .openai:
            return URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        }
    }

    var whisperModel: String {
        switch self {
        case .groq: return "whisper-large-v3-turbo"
        case .openai: return "whisper-1"
        }
    }

    var chatURL: URL {
        switch self {
        case .groq:
            return URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        case .openai:
            return URL(string: "https://api.openai.com/v1/chat/completions")!
        }
    }

    var chatModel: String {
        switch self {
        case .groq: return "llama-3.1-8b-instant"
        case .openai: return "gpt-4o-mini"
        }
    }
}

class AppConfig {
    static let shared = AppConfig()

    private let defaults = UserDefaults.standard

    private let kApiKey = "TypeLess_ApiKey"
    private let kProvider = "TypeLess_Provider"
    private let kMode = "TypeLess_Mode"
    private let kHotKey = "TypeLess_HotKey"
    private let kTheme = "TypeLess_Theme"
    private let kAutoPaste = "TypeLess_AutoPaste"
    private let kSoundEffects = "TypeLess_SoundEffects"
    private let kShowHUD = "TypeLess_ShowHUD"
    private let kAutoStopOnSilence = "TypeLess_AutoStopOnSilence"
    private let kShowFloatingWidget = "TypeLess_ShowFloatingWidget"

    var theme: AppTheme {
        get {
            if let val = defaults.string(forKey: kTheme), let t = AppTheme(rawValue: val) {
                return t
            }
            return .system
        }
        set {
            defaults.set(newValue.rawValue, forKey: kTheme)
        }
    }

    var autoStopOnSilence: Bool {
        get {
            if defaults.object(forKey: kAutoStopOnSilence) == nil { return true }
            return defaults.bool(forKey: kAutoStopOnSilence)
        }
        set {
            defaults.set(newValue, forKey: kAutoStopOnSilence)
        }
    }

    var showFloatingWidget: Bool {
        get {
            if defaults.object(forKey: kShowFloatingWidget) == nil { return true }
            return defaults.bool(forKey: kShowFloatingWidget)
        }
        set {
            defaults.set(newValue, forKey: kShowFloatingWidget)
        }
    }

    var apiKey: String {
        get {
            if let saved = defaults.string(forKey: kApiKey), !saved.isEmpty {
                return saved
            }
            // Fallback to environment variables if set
            if provider == .groq, let env = ProcessInfo.processInfo.environment["GROQ_API_KEY"], !env.isEmpty {
                return env
            }
            if provider == .openai, let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !env.isEmpty {
                return env
            }
            return ""
        }
        set {
            defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: kApiKey)
        }
    }

    var provider: APIProvider {
        get {
            if let val = defaults.string(forKey: kProvider), let p = APIProvider(rawValue: val) {
                return p
            }
            return .groq
        }
        set {
            defaults.set(newValue.rawValue, forKey: kProvider)
        }
    }

    var mode: DictationMode {
        get {
            if let val = defaults.string(forKey: kMode), let m = DictationMode(rawValue: val) {
                return m
            }
            return .smart
        }
        set {
            defaults.set(newValue.rawValue, forKey: kMode)
        }
    }

    var hotKeyChoice: HotKeyChoice {
        get {
            if let val = defaults.string(forKey: kHotKey), let h = HotKeyChoice(rawValue: val) {
                return h
            }
            return .optionSpace
        }
        set {
            defaults.set(newValue.rawValue, forKey: kHotKey)
        }
    }

    var autoPaste: Bool {
        get {
            if defaults.object(forKey: kAutoPaste) == nil { return true }
            return defaults.bool(forKey: kAutoPaste)
        }
        set {
            defaults.set(newValue, forKey: kAutoPaste)
        }
    }

    var soundEffects: Bool {
        get {
            if defaults.object(forKey: kSoundEffects) == nil { return true }
            return defaults.bool(forKey: kSoundEffects)
        }
        set {
            defaults.set(newValue, forKey: kSoundEffects)
        }
    }

    var showHUD: Bool {
        get {
            if defaults.object(forKey: kShowHUD) == nil { return true }
            return defaults.bool(forKey: kShowHUD)
        }
        set {
            defaults.set(newValue, forKey: kShowHUD)
        }
    }
}
