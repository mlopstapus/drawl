import Foundation
import Combine

public class PreferencesStore: ObservableObject {
    private let defaults: UserDefaults
    
    private enum Keys {
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let selectedModelId = "selectedModelId"
        static let language = "language"
        static let indicatorPosition = "indicatorPosition"
        static let launchAtLogin = "launchAtLogin"
        static let hasCompletedSetup = "hasCompletedSetup"
        static let historyRetentionDays = "historyRetentionDays"
        static let screenContextEnabled = "screenContextEnabled"
        static let indicatorColorHex = "indicatorColorHex"
    }
    
    @Published public var hotkeyKeyCode: UInt16 {
        didSet {
            defaults.set(Int(hotkeyKeyCode), forKey: Keys.hotkeyKeyCode)
        }
    }
    
    @Published public var hotkeyModifiers: UInt64 {
        didSet {
            defaults.set(Double(hotkeyModifiers), forKey: Keys.hotkeyModifiers)
        }
    }
    
    @Published public var selectedModelId: String {
        didSet {
            defaults.set(selectedModelId, forKey: Keys.selectedModelId)
        }
    }
    
    @Published public var language: String {
        didSet {
            defaults.set(language, forKey: Keys.language)
        }
    }
    
    @Published public var indicatorPosition: IndicatorPosition {
        didSet {
            defaults.set(indicatorPosition.rawValue, forKey: Keys.indicatorPosition)
        }
    }
    
    @Published public var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        }
    }
    
    @Published public var hasCompletedSetup: Bool {
        didSet {
            defaults.set(hasCompletedSetup, forKey: Keys.hasCompletedSetup)
        }
    }
    
    @Published public var historyRetentionDays: Int {
        didSet {
            defaults.set(historyRetentionDays, forKey: Keys.historyRetentionDays)
        }
    }

    @Published public var screenContextEnabled: Bool {
        didSet {
            defaults.set(screenContextEnabled, forKey: Keys.screenContextEnabled)
        }
    }

    @Published public var indicatorColorHex: String {
        didSet {
            defaults.set(indicatorColorHex, forKey: Keys.indicatorColorHex)
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        
        defaults.register(defaults: [
            Keys.hotkeyKeyCode: 55, // Command
            Keys.hotkeyModifiers: 1048576, // ⌘ (Command) modifier value
            Keys.selectedModelId: "base",
            Keys.language: "en",
            Keys.indicatorPosition: IndicatorPosition.nearCursor.rawValue,
            Keys.launchAtLogin: false,
            Keys.hasCompletedSetup: false,
            Keys.historyRetentionDays: 30,
            Keys.screenContextEnabled: false,
            Keys.indicatorColorHex: "#8B5CF6"
        ])
        
        // Load initial values from defaults
        self.hotkeyKeyCode = UInt16(defaults.integer(forKey: Keys.hotkeyKeyCode))
        self.hotkeyModifiers = UInt64(defaults.double(forKey: Keys.hotkeyModifiers))
        self.selectedModelId = defaults.string(forKey: Keys.selectedModelId) ?? "base"
        self.language = defaults.string(forKey: Keys.language) ?? "en"
        
        let rawPos = defaults.string(forKey: Keys.indicatorPosition) ?? IndicatorPosition.nearCursor.rawValue
        self.indicatorPosition = IndicatorPosition(rawValue: rawPos) ?? .nearCursor
        
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.hasCompletedSetup = defaults.bool(forKey: Keys.hasCompletedSetup)
        self.historyRetentionDays = defaults.integer(forKey: Keys.historyRetentionDays)
        self.screenContextEnabled = defaults.bool(forKey: Keys.screenContextEnabled)
        self.indicatorColorHex = defaults.string(forKey: Keys.indicatorColorHex) ?? "#8B5CF6"
    }
}
