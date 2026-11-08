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
    let category: HealthWorkoutCategory
    let start: Date
    let durationMinutes: Double
    let energyKcal: Double?
    let distanceMeters: Double?
    let sourceName: String
    let isFromFitr: Bool
}

enum HealthWorkoutCategory: String, CaseIterable, Identifiable, Sendable {
    case strength
    case cardio
    case yoga
    case mobility
    case recovery
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strength: return "Strength"
        case .cardio: return "Cardio"
        case .yoga: return "Yoga"
        case .mobility: return "Mobility"
        case .recovery: return "Recovery"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.circle.fill"
        case .yoga: return "figure.yoga"
        case .mobility: return "figure.flexibility"
        case .recovery: return "figure.mind.and.body"
        case .other: return "figure.mixed.cardio"
        }
    }
}

struct HealthSource: Identifiable, Sendable {
    let name: String
    let bundleIdentifier: String?

    var id: String { "\(bundleIdentifier ?? "health")-\(name)" }
}

// MARK: - Ranges, metrics and series

enum HealthRange: String, CaseIterable, Identifiable, Sendable {
    case week
    case month
    case quarter
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "7D"
        case .month: return "30D"
        case .quarter: return "90D"
        case .year: return "1Y"
        }
    }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }

    var subtitle: String {
        switch self {
        case .week: return "Last seven days"
        case .month: return "Last thirty days"
        case .quarter: return "Last ninety days"
        case .year: return "Last twelve months"
        }
    }
}

enum HealthAggregation: Sendable {
    case sum
    case average
}

enum HealthMetric: String, CaseIterable, Identifiable, Sendable {
    case steps
    case activeEnergy
    case exercise
    case distance
    case sleep
    case restingHeartRate
    case heartRate
    case hrv
    case mindful
    case weight
    case stand

    var id: String { rawValue }

    var title: String {
        switch self {
        case .steps: return "Steps"
        case .activeEnergy: return "Active energy"
        case .exercise: return "Exercise"
        case .distance: return "Distance"
        case .sleep: return "Sleep"
        case .restingHeartRate: return "Resting HR"
        case .heartRate: return "Heart rate"
        case .hrv: return "HRV"
        case .mindful: return "Mindful"
        case .weight: return "Weight"
        case .stand: return "Stand"
        }
    }

    var shortTitle: String {
        switch self {
        case .steps: return "Steps"
        case .activeEnergy: return "Energy"
        case .exercise: return "Exercise"
        case .distance: return "Distance"
        case .sleep: return "Sleep"
        case .restingHeartRate: return "Resting"
        case .heartRate: return "Heart"
        case .hrv: return "HRV"
        case .mindful: return "Mindful"
        case .weight: return "Weight"
        case .stand: return "Stand"
        }
    }

    var icon: String {
        switch self {
        case .steps: return "figure.walk"
        case .activeEnergy: return "flame.fill"
        case .exercise: return "figure.run"
        case .distance: return "figure.walk.motion"
        case .sleep: return "moon.stars.fill"
        case .restingHeartRate: return "heart.fill"
        case .heartRate: return "heart.text.square.fill"
        case .hrv: return "waveform.path.ecg"
        case .mindful: return "brain.head.profile"
        case .weight: return "scalemass.fill"
        case .stand: return "figure.stand"
        }
    }

    var unit: String {
        switch self {
        case .steps: return "steps"
        case .activeEnergy: return "kcal"
        case .exercise: return "min"
        case .distance: return "km"
        case .sleep: return "sleep"
        case .restingHeartRate, .heartRate: return "bpm"
        case .hrv: return "ms"
        case .mindful: return "min"
        case .weight: return "kg"
        case .stand: return "h"
        }
    }

    var aggregation: HealthAggregation {
        switch self {
        case .steps, .activeEnergy, .exercise, .distance, .sleep, .mindful:
            return .sum
        case .restingHeartRate, .heartRate, .hrv, .weight, .stand:
            return .average
        }
    }

    func value(in point: HealthSeriesPoint) -> Double? {
        switch self {
        case .steps: return point.steps
        case .activeEnergy: return point.activeEnergyKcal
        case .exercise: return point.exerciseMinutes
        case .distance: return point.distanceMeters
        case .sleep: return point.sleepMinutes
        case .restingHeartRate: return point.restingHeartRate
        case .heartRate: return point.heartRate
        case .hrv: return point.heartRateVariability
        case .mindful: return point.mindfulMinutes
        case .weight: return point.weightKg
        case .stand: return point.standHours
        }
    }

    func format(_ value: Double?) -> String {
        guard let value else { return "—" }
        switch self {
        case .steps:
            if value >= 10_000 {
                return FitrDate.number(value)
            }
            return "\(Int(value.rounded()))"
        case .distance:
            return String(format: "%.1f", value / 1000)
        case .sleep:
            return FitrDate.minutes(value)
        case .weight:
            return FitrDate.weight(value)
        case .activeEnergy, .exercise, .restingHeartRate, .heartRate, .hrv, .mindful, .stand:
            return "\(Int(value.rounded()))"
        }
    }
}

struct HealthSeriesPoint: Identifiable, Sendable {
    var id: Date { date }
    let date: Date
    var steps: Double?
    var activeEnergyKcal: Double?
    var exerciseMinutes: Double?
    var distanceMeters: Double?
    var sleepMinutes: Double?
    var restingHeartRate: Double?
    var heartRate: Double?
    var heartRateVariability: Double?
    var mindfulMinutes: Double?
    var weightKg: Double?
    var standHours: Double?
}

struct HealthMetricPoint: Identifiable, Sendable {
    var id: Date { date }
    let date: Date
    let value: Double
}

struct HealthMetricSummary: Sendable {
    let total: Double?
    let average: Double?
    let best: Double?
    let latest: Double?
    let changePct: Double?
    let count: Int
}

struct HealthAnalysis: Sendable {
    let range: HealthRange
    let series: [HealthSeriesPoint]
    let workouts: [HealthWorkout]
    let sources: [HealthSource]
    let generatedAt: Date

    var fitrWorkoutCount: Int {
        workouts.filter(\.isFromFitr).count
    }

    var workoutMinutes: Double {
        workouts.reduce(0) { $0 + $1.durationMinutes }
    }

    var workoutEnergy: Double {
        workouts.reduce(0) { $0 + ($1.energyKcal ?? 0) }
    }

    var workoutDistance: Double {
        workouts.reduce(0) { $0 + ($1.distanceMeters ?? 0) }
    }

    func points(for metric: HealthMetric) -> [HealthMetricPoint] {
        series.compactMap { point in
            guard let value = metric.value(in: point) else { return nil }
            return HealthMetricPoint(date: point.date, value: value)
        }
    }

    func summary(for metric: HealthMetric) -> HealthMetricSummary {
        let values = points(for: metric)
        guard !values.isEmpty else {
            return HealthMetricSummary(total: nil, average: nil, best: nil, latest: nil, changePct: nil, count: 0)
        }
        let total = values.reduce(0) { $0 + $1.value }
        let average = total / Double(values.count)
        let best = values.map(\.value).max()
        let latest = values.last?.value
        let half = max(values.count / 2, 1)
        let first = values.prefix(half).map(\.value)
        let second = values.suffix(half).map(\.value)
        let firstAverage = first.isEmpty ? nil : first.reduce(0, +) / Double(first.count)
        let secondAverage = second.isEmpty ? nil : second.reduce(0, +) / Double(second.count)
        let change: Double?
        if let firstAverage, let secondAverage, firstAverage != 0 {
            change = ((secondAverage - firstAverage) / firstAverage) * 100
        } else {
            change = nil
        }
        return HealthMetricSummary(
            total: metric.aggregation == .sum ? total : average,
            average: average,
            best: best,
            latest: latest,
            changePct: change,
            count: values.count
        )
    }

    func workouts(category: HealthWorkoutCategory?) -> [HealthWorkout] {
        guard let category else { return workouts }
        return workouts.filter { $0.category == category }
    }

    func workouts(source: String?) -> [HealthWorkout] {
        guard let source else { return workouts }
        return workouts.filter { $0.sourceName == source }
    }
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
