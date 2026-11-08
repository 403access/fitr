import Foundation

// MARK: - Catalogue

struct NamedRef: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
}

struct ExerciseTopic: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let accent: String
    let icon: String
}

struct ExerciseType: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
}

struct ExercisePrescription: Codable, Hashable, Sendable {
    let sets: Int
    let reps: Int?
    let holdSeconds: Int?
    let loadKg: Double?
    let restSeconds: Int
}

struct Exercise: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let slug: String
    let name: String
    let summary: String
    let topic: ExerciseTopic
    let type: ExerciseType
    let difficulty: Int
    let durationSeconds: Int
    let animation: String
    let equipment: [String]
    let instructions: [String]
    let cues: [String]
    let benefits: [String]
    let breathing: String
    let regions: [NamedRef]
    let primaryMuscles: [NamedRef]
    let secondaryMuscles: [NamedRef]
    let prescription: ExercisePrescription

    static func == (lhs: Exercise, rhs: Exercise) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct TopicFacet: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    let accent: String
    let icon: String
    let count: Int
}

struct TypeFacet: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    let count: Int
}

struct RegionFacet: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let count: Int
}

struct MuscleFacet: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let regionId: String
    let count: Int
}

struct TimeRegion: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let hint: String
    let icon: String
}

struct Facets: Codable, Sendable {
    let topics: [TopicFacet]
    let types: [TypeFacet]
    let regions: [RegionFacet]
    let muscles: [MuscleFacet]
    let timeRegions: [TimeRegion]
}

struct CatalogResource: Codable, Sendable {
    let generatedAt: String
    let facets: Facets
    let exercises: [Exercise]
}

// MARK: - Training

enum TaskStatus: String, Codable, Sendable {
    case pending
    case done
    case skipped
}

struct TrainingTask: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let date: String
    let timeRegion: TimeRegion
    let orderIndex: Int
    let status: TaskStatus
    let sets: Int
    let reps: Int?
    let holdSeconds: Int?
    let restSeconds: Int
    let loadKg: Double?
    let durationMinutes: Double
    let targetNote: String
    let completedAt: String?
    let actualReps: Int?
    let actualHoldSeconds: Int?
    let actualLoadKg: Double?
    let effort: Int?
    let exercise: Exercise

    var isTimed: Bool { (holdSeconds ?? 0) > 0 }
    var isWeighted: Bool { loadKg != nil }
}

struct PlanDay: Codable, Identifiable, Sendable {
    var id: String { date }
    let date: String
    let isRestDay: Bool
    let totalMinutes: Double
    let completedTasks: Int
    let totalTasks: Int
    let tasks: [TrainingTask]
}

struct PlanSummary: Codable, Sendable {
    let totalTasks: Int
    let completedTasks: Int
    let totalMinutes: Double
}

struct TrainingPlan: Codable, Identifiable, Sendable {
    let id: String
    let weekStart: String
    let weekIndex: Int
    let focus: String
    let volumeMultiplier: Double
    let intensityMultiplier: Double
    let days: [PlanDay]
    let summary: PlanSummary
}

struct TimeRegionGroup: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let hint: String
    let icon: String
    let tasks: [TrainingTask]
    let completed: Int
    let totalMinutes: Double
}

struct TodaySnapshot: Codable, Sendable {
    let date: String
    let totalTasks: Int
    let completedTasks: Int
    let skippedTasks: Int
    let totalMinutes: Double
    let completedMinutes: Double
    let adherence: Int
    let timeRegions: [TimeRegionGroup]
}

struct StreakInfo: Codable, Sendable {
    let current: Int
    let best: Int
    let lastActive: String?
}

struct UserProfile: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let goal: String
    let experience: String
    let daysPerWeek: Int
    let sessionMinutes: Int
    let equipment: [String]
    let programStart: String
}

struct Bootstrap: Codable, Sendable {
    let user: UserProfile
    let date: String
    let weekStart: String
    let plan: TrainingPlan
    let today: TodaySnapshot
    let streak: StreakInfo
    let facets: Facets
    let serverTime: String
}

// MARK: - Progress

struct DateRange: Codable, Sendable {
    let start: String
    let end: String
}

struct ProgressTotals: Codable, Sendable {
    let scheduled: Int
    let completed: Int
    let skipped: Int
    let pending: Int
    let minutes: Double
    let volumeKg: Double
    let reps: Int
    let holdSeconds: Int
    let sessions: Int
    let adherence: Int
}

struct ProgressDeltas: Codable, Sendable {
    let minutesPct: Double?
    let volumePct: Double?
    let adherencePct: Double?
    let completedPct: Double?
    let sessionsPct: Double?
}

enum ProgressDayStatus: String, Codable, Sendable {
    case done
    case partial
    case missed
    case rest
    case future
}

struct ProgressDay: Codable, Identifiable, Sendable {
    var id: String { date }
    let date: String
    let scheduled: Int
    let completed: Int
    let minutes: Double
    let volumeKg: Double
    let status: ProgressDayStatus
}

struct MuscleShare: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let minutes: Double
    let share: Double
}

struct PersonalRecord: Codable, Identifiable, Sendable {
    var id: String { "\(exerciseId)-\(kind)" }
    let exerciseId: String
    let name: String
    let kind: String
    let value: Double
    let unit: String
    let previous: Double?
    let deltaPct: Double?
    let achievedAt: String
}

struct ExerciseImprovement: Codable, Identifiable, Sendable {
    var id: String { "\(exerciseId)-\(kind)" }
    let exerciseId: String
    let name: String
    let kind: String
    let current: Double
    let previous: Double?
    let deltaPct: Double?
    let unit: String
}

struct ProgressSummary: Codable, Sendable {
    let period: String
    let anchor: String
    let range: DateRange
    let previousRange: DateRange
    let totals: ProgressTotals
    let previousTotals: ProgressTotals
    let deltas: ProgressDeltas
    let streak: StreakInfo
    let days: [ProgressDay]
    let muscles: [MuscleShare]
    let prs: [PersonalRecord]
    let improvements: [ExerciseImprovement]
    let generatedAt: String
}

struct ExerciseProgressPoint: Codable, Sendable {
    let date: String
    let value: Double
    let minutes: Double
}

struct ExerciseProgress: Codable, Sendable {
    let exercise: ExerciseSummary
    let kind: String
    let unit: String
    let points: [ExerciseProgressPoint]
    let best: Double
    let deltaPct: Double?
    let sessions: Int

    struct ExerciseSummary: Codable, Sendable {
        let id: String
        let name: String
    }
}

// MARK: - Requests

struct CompletionRequest: Encodable, Sendable {
    var actualReps: Int?
    var actualHoldSeconds: Int?
    var actualLoadKg: Double?
    var effort: Int?
}

struct ProfilePatch: Encodable, Sendable {
    var name: String?
    var goal: String?
    var experience: String?
    var daysPerWeek: Int?
    var sessionMinutes: Int?
    var equipment: [String]?
}

struct MutationResponse: Codable, Sendable {
    let task: TrainingTask
    let plan: TrainingPlan?
    let streak: StreakInfo?
}

enum TrainingPeriod: String, CaseIterable, Identifiable {
    case day, week, month, year
    var id: String { rawValue }
    var title: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}

enum GoalOption: String, CaseIterable, Identifiable {
    case balanced, strength, endurance, mobility, recovery
    var id: String { rawValue }
    var title: String {
        switch self {
        case .balanced: return "Balanced"
        case .strength: return "Strength"
        case .endurance: return "Endurance"
        case .mobility: return "Mobility"
        case .recovery: return "Recovery"
        }
    }
    var blurb: String {
        switch self {
        case .balanced: return "A bit of everything, every day."
        case .strength: return "Lift heavy, build muscle."
        case .endurance: return "Engine first, all-day energy."
        case .mobility: return "Move freely, own your range."
        case .recovery: return "Restore, breathe, rebuild."
        }
    }
    var icon: String {
        switch self {
        case .balanced: return "circle.hexagongrid.fill"
        case .strength: return "dumbbell.fill"
        case .endurance: return "heart.fill"
        case .mobility: return "figure.flexibility"
        case .recovery: return "moon.stars.fill"
        }
    }
}

enum ExperienceOption: String, CaseIterable, Identifiable {
    case beginner, intermediate, advanced
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum AppTab: String, CaseIterable, Identifiable {
    case today, catalogue, progress, profile
    var id: String { rawValue }
    var title: String {
        switch self {
        case .today: return "Today"
        case .catalogue: return "Explore"
        case .progress: return "Progress"
        case .profile: return "You"
        }
    }
    var icon: String {
        switch self {
        case .today: return "sun.horizon.fill"
        case .catalogue: return "square.grid.2x2.fill"
        case .progress: return "chart.bar.fill"
        case .profile: return "person.fill"
        }
    }
}
