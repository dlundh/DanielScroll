import Foundation

/// UserDefaults-backed settings. Defaults are tuned to feel close to SmoothScroll.
final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.stepSize: 100.0,             // pixels per wheel notch
            Key.animationTime: 360.0,        // ms per notch animation
            Key.accelerationEnabled: true,
            Key.accelerationDelta: 50.0,     // ms window for "fast" consecutive notches
            Key.accelerationMax: 3.0,        // max multiplier
            Key.pulseScale: 4.0,             // easing curve sharpness
            Key.reverseDirection: false,
            Key.horizontalSmoothing: true,
            Key.excludedApps: [String](),
        ])
    }

    private enum Key {
        static let enabled = "enabled"
        static let stepSize = "stepSize"
        static let animationTime = "animationTime"
        static let accelerationEnabled = "accelerationEnabled"
        static let accelerationDelta = "accelerationDelta"
        static let accelerationMax = "accelerationMax"
        static let pulseScale = "pulseScale"
        static let reverseDirection = "reverseDirection"
        static let horizontalSmoothing = "horizontalSmoothing"
        static let excludedApps = "excludedApps"
    }

    var enabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }
    var stepSize: Double {
        get { defaults.double(forKey: Key.stepSize) }
        set { defaults.set(newValue, forKey: Key.stepSize) }
    }
    var animationTime: Double {
        get { defaults.double(forKey: Key.animationTime) }
        set { defaults.set(newValue, forKey: Key.animationTime) }
    }
    var accelerationEnabled: Bool {
        get { defaults.bool(forKey: Key.accelerationEnabled) }
        set { defaults.set(newValue, forKey: Key.accelerationEnabled) }
    }
    var accelerationDelta: Double {
        get { defaults.double(forKey: Key.accelerationDelta) }
        set { defaults.set(newValue, forKey: Key.accelerationDelta) }
    }
    var accelerationMax: Double {
        get { defaults.double(forKey: Key.accelerationMax) }
        set { defaults.set(newValue, forKey: Key.accelerationMax) }
    }
    var pulseScale: Double {
        get { defaults.double(forKey: Key.pulseScale) }
        set { defaults.set(newValue, forKey: Key.pulseScale) }
    }
    var reverseDirection: Bool {
        get { defaults.bool(forKey: Key.reverseDirection) }
        set { defaults.set(newValue, forKey: Key.reverseDirection) }
    }
    var horizontalSmoothing: Bool {
        get { defaults.bool(forKey: Key.horizontalSmoothing) }
        set { defaults.set(newValue, forKey: Key.horizontalSmoothing) }
    }
    var excludedApps: [String] {
        get { defaults.stringArray(forKey: Key.excludedApps) ?? [] }
        set { defaults.set(newValue, forKey: Key.excludedApps) }
    }

    func isExcluded(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return excludedApps.contains(bundleID)
    }

    func toggleExcluded(_ bundleID: String) {
        var list = excludedApps
        if let i = list.firstIndex(of: bundleID) { list.remove(at: i) } else { list.append(bundleID) }
        excludedApps = list
    }
}
