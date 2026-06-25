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
    }
    
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        
        defaults.register(defaults: [
            Keys.hotkeyKeyCode: 49, // Space
            Keys.hotkeyModifiers: 524288, // ⌥ (Option) modifier value
            Keys.selectedModelId: "ggml-base",
            Keys.language: "en",
            Keys.indicatorPosition: IndicatorPosition.nearCursor.rawValue,
            Keys.launchAtLogin: false,
            Keys.hasCompletedSetup: false,
            Keys.historyRetentionDays: 30
        ])
    }
    
    public var hotkeyKeyCode: UInt16 {
        get { UInt16(defaults.integer(forKey: Keys.hotkeyKeyCode)) }
        set {
            objectWillChange.send()
            defaults.set(Int(newValue), forKey: Keys.hotkeyKeyCode)
        }
    }
    
    public var hotkeyModifiers: UInt64 {
        get { UInt64(defaults.double(forKey: Keys.hotkeyModifiers)) }
        set {
            objectWillChange.send()
            defaults.set(Double(newValue), forKey: Keys.hotkeyModifiers)
        }
    }
    
    public var selectedModelId: String {
        get { defaults.string(forKey: Keys.selectedModelId) ?? "ggml-base" }
        set {
            objectWillChange.send()
            defaults.set(newValue, forKey: Keys.selectedModelId)
        }
    }
    
    public var language: String {
        get { defaults.string(forKey: Keys.language) ?? "en" }
        set {
            objectWillChange.send()
            defaults.set(newValue, forKey: Keys.language)
        }
    }
    
    public var indicatorPosition: IndicatorPosition {
        get {
            guard let rawValue = defaults.string(forKey: Keys.indicatorPosition),
                  let position = IndicatorPosition(rawValue: rawValue) else {
                return .nearCursor
            }
            return position
        }
        set {
            objectWillChange.send()
            defaults.set(newValue.rawValue, forKey: Keys.indicatorPosition)
        }
    }
    
    public var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set {
            objectWillChange.send()
            defaults.set(newValue, forKey: Keys.launchAtLogin)
        }
    }
    
    public var hasCompletedSetup: Bool {
        get { defaults.bool(forKey: Keys.hasCompletedSetup) }
        set {
            objectWillChange.send()
            defaults.set(newValue, forKey: Keys.hasCompletedSetup)
        }
    }
    
    public var historyRetentionDays: Int {
        get { defaults.integer(forKey: Keys.historyRetentionDays) }
        set {
            objectWillChange.send()
            defaults.set(newValue, forKey: Keys.historyRetentionDays)
        }
    }
}
