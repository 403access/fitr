import Foundation

// MARK: - Health snapshot

/// A normalized, display-ready view of the health data Fitr reads from HealthKit.
/// HealthKit values are converted to primitives here so SwiftUI can render without
/// holding on to framework objects or query results.
struct HealthSnapshot: Sendable {
    var steps: Double?
    var activeEnergyKcal: Double?
    var exerciseMinutes: Double?
    var standHours: Double?
    var distanceMeters: Double?
    var flightsClimbed: Double?
    var sleepMinutes: Double?
    var mindfulMinutes: Double?
    var restingHeartRate: Double?
    var heartRate: Double?
    var heartRateVariability: Double?
    var weightKg: Double?
    var weekly: [HealthDayPoint]
    var workouts: [HealthWorkout]
    var sources: [HealthSource]
    var generatedAt: Date

    static let empty = HealthSnapshot(
        steps: nil,
        activeEnergyKcal: nil,
        exerciseMinutes: nil,
        standHours: nil,
        distanceMeters: nil,
        flightsClimbed: nil,
        sleepMinutes: nil,
        mindfulMinutes: nil,
        restingHeartRate: nil,
        heartRate: nil,
        heartRateVariability: nil,
        weightKg: nil,
        weekly: [],
        workouts: [],
        sources: [],
        generatedAt: Date()
    )

    var hasAnyData: Bool {
        steps != nil
            || activeEnergyKcal != nil
            || exerciseMinutes != nil
            || standHours != nil
            || distanceMeters != nil
            || flightsClimbed != nil
            || sleepMinutes != nil
            || mindfulMinutes != nil
            || restingHeartRate != nil
            || heartRate != nil
            || heartRateVariability != nil
            || weightKg != nil
            || !workouts.isEmpty
            || !sources.isEmpty
            || weekly.contains { $0.steps > 0 || $0.activeEnergyKcal > 0 || $0.exerciseMinutes > 0 }
    }
}

struct HealthDayPoint: Identifiable, Sendable {
    var id: Date { date }
    let date: Date
    let steps: Double
    let activeEnergyKcal: Double
    let exerciseMinutes: Double
}

struct HealthWorkout: Identifiable, Sendable {
    let id: UUID
    let activityName: String
    let icon: String
    let start: Date
    let durationMinutes: Double
    let energyKcal: Double?
    let distanceMeters: Double?
    let sourceName: String
    let isFromFitr: Bool
}

struct HealthSource: Identifiable, Sendable {
    let name: String
    let bundleIdentifier: String?

    var id: String { "\(bundleIdentifier ?? "health")-\(name)" }
}

// MARK: - Session export

/// The kind of workout Fitr writes back to Health. The mapping keeps exercise
/// topics and HealthKit workout activity types in one place.
enum HealthSessionKind: Sendable {
    case strength
    case functional
    case cardio
    case yoga
    case mobility
    case recovery
    case other

    init(topicID: String?) {
        switch topicID {
        case "strength": self = .strength
        case "calisthenics": self = .functional
        case "cardio", "endurance": self = .cardio
        case "yoga": self = .yoga
        case "mobility": self = .mobility
        case "recovery": self = .recovery
        default: self = .other
        }
    }

    /// A deliberately conservative MET estimate used only for the energy sample
    /// that accompanies an exported workout.
    var estimatedMET: Double {
        switch self {
        case .strength: return 5.0
        case .functional: return 6.0
        case .cardio: return 8.0
        case .yoga: return 3.0
        case .mobility: return 2.5
        case .recovery: return 2.0
        case .other: return 4.0
        }
    }
}

// MARK: - Formatting

enum HealthFormatting {
    static func energy(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded()))"
    }

    static func minutes(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded()))"
    }

    static func distance(_ meters: Double?) -> String {
        guard let meters else { return "—" }
        return String(format: "%.1f", meters / 1000)
    }

    static func heartRate(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded()))"
    }

    static func hrv(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded()))"
    }

    static func weight(_ value: Double?) -> String {
        guard let value else { return "—" }
        return FitrDate.weight(value)
    }

    static func steps(_ value: Double?) -> String {
        guard let value else { return "—" }
        return FitrDate.number(value)
    }

    static func sleep(_ value: Double?) -> String {
        guard let value else { return "—" }
        return FitrDate.minutes(value)
    }

    static func relativeDay(_ date: Date) -> String {
        if FitrDate.calendar.isDateInToday(date) { return "Today" }
        if FitrDate.calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}
