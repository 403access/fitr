import Foundation
import Observation

@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var serverURLString: String {
        didSet { defaults.set(serverURLString, forKey: Keys.serverURL) }
    }

    var hasOnboarded: Bool {
        didSet { defaults.set(hasOnboarded, forKey: Keys.hasOnboarded) }
    }

    var usesMetric: Bool {
        didSet { defaults.set(usesMetric, forKey: Keys.usesMetric) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        serverURLString = defaults.string(forKey: Keys.serverURL) ?? Self.defaultServerURL
        hasOnboarded = defaults.bool(forKey: Keys.hasOnboarded)
        usesMetric = defaults.object(forKey: Keys.usesMetric) as? Bool ?? true
    }

    static let defaultServerURL = "http://localhost:8787"

    static let equipmentOptions = [
        "Barbell", "Dumbbell", "Dumbbells", "Kettlebell", "Bench", "Rack",
        "Pull-up bar", "Parallel bars", "Bar", "Cable machine", "Rope",
        "Mat", "Wall", "Jump rope", "Running shoes",
    ]

    var serverURL: URL? {
        guard let url = URL(string: serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else { return nil }
        return url
    }

    private enum Keys {
        static let serverURL = "fitr.serverURL"
        static let hasOnboarded = "fitr.hasOnboarded"
        static let usesMetric = "fitr.usesMetric"
    }
}
