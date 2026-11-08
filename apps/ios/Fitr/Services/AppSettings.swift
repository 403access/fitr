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

    /// True after the HealthKit permission sheet has been shown once. HealthKit
    /// deliberately hides read authorization, so this is the honest signal we
    /// can use for the connection state.
    var hasRequestedHealthAccess: Bool {
        didSet { defaults.set(hasRequestedHealthAccess, forKey: Keys.hasRequestedHealthAccess) }
    }

    /// Automatically save a completed training day as a Health workout.
    var healthAutoExport: Bool {
        didSet { defaults.set(healthAutoExport, forKey: Keys.healthAutoExport) }
    }

    private(set) var exportedHealthSessions: Set<String> {
        didSet { defaults.set(Array(exportedHealthSessions).sorted(), forKey: Keys.exportedHealthSessions) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        serverURLString = defaults.string(forKey: Keys.serverURL) ?? Self.defaultServerURL
        hasOnboarded = defaults.bool(forKey: Keys.hasOnboarded)
        usesMetric = defaults.object(forKey: Keys.usesMetric) as? Bool ?? true
        hasRequestedHealthAccess = defaults.bool(forKey: Keys.hasRequestedHealthAccess)
        healthAutoExport = defaults.bool(forKey: Keys.healthAutoExport)
        exportedHealthSessions = Set(defaults.stringArray(forKey: Keys.exportedHealthSessions) ?? [])
    }

    func hasExportedHealthSession(_ date: String) -> Bool {
        exportedHealthSessions.contains(date)
    }

    func markHealthSessionExported(_ date: String) {
        exportedHealthSessions.insert(date)
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
        static let hasRequestedHealthAccess = "fitr.health.hasRequestedAccess"
        static let healthAutoExport = "fitr.health.autoExport"
        static let exportedHealthSessions = "fitr.health.exportedSessions"
    }
}
