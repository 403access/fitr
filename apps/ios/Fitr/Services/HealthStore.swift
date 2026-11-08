import Foundation
import HealthKit
import Observation

/// Reads and writes the health data Fitr is allowed to see.
///
/// Health data stays on the device. The store never sends samples to the Fitr
/// server; it normalizes HealthKit results into `HealthSnapshot` for the UI and
/// writes completed Fitr sessions back as workouts when the user asks for it.
@MainActor
@Observable
final class HealthStore {
    let settings: AppSettings

    private let healthStore = HKHealthStore()
    private let calendar: Calendar

    private(set) var snapshot: HealthSnapshot?
    private(set) var isAvailable = HKHealthStore.isHealthDataAvailable()
    private(set) var isLoading = false
    private(set) var isExporting = false
    private(set) var lastRefresh: Date?
    private(set) var lastExportDate: String?

    var errorMessage: String?

    init(settings: AppSettings, calendar: Calendar = FitrDate.calendar) {
        self.settings = settings
        self.calendar = calendar
    }

    // MARK: - Connection state

    var hasRequestedAccess: Bool { settings.hasRequestedHealthAccess }
    var isConnected: Bool { isAvailable && settings.hasRequestedHealthAccess }

    var canWriteWorkouts: Bool {
        guard isConnected else { return false }
        return healthStore.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
    }

    var permissionLabel: String {
        if !isAvailable { return "Unavailable" }
        if !hasRequestedAccess { return "Not connected" }
        if canWriteWorkouts { return "Read & write" }
        return "Read only"
    }

    /// Requests read access plus permission to save workouts and their energy.
    func requestAccess() async {
        guard isAvailable else {
            errorMessage = "Apple Health is not available on this device."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { success, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if success {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(throwing: HealthStoreError.authorizationFailed)
                    }
                }
            }
            settings.hasRequestedHealthAccess = true
            errorMessage = nil
            await refresh()
        } catch {
            errorMessage = friendly(error)
        }
    }

    /// Refresh only after the user has completed the permission sheet. This keeps
    /// the app from showing a HealthKit prompt on a cold launch.
    func refreshIfConnected() async {
        guard isConnected else { return }
        await refresh()
    }

    func refresh() async {
        guard isAvailable else {
            isAvailable = false
            return
        }
        isLoading = true
        defer { isLoading = false }

        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let sleepWindowStart = calendar.date(byAdding: .hour, value: -6, to: startOfDay) ?? startOfDay
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: now) ?? now
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now) ?? now

        async let steps = sum(.stepCount, unit: .count(), from: startOfDay, to: now)
        async let activeEnergy = sum(.activeEnergyBurned, unit: .kilocalorie(), from: startOfDay, to: now)
        async let exerciseMinutes = sum(.appleExerciseTime, unit: .minute(), from: startOfDay, to: now)
        async let distance = sum(.distanceWalkingRunning, unit: .meter(), from: startOfDay, to: now)
        async let flights = sum(.flightsClimbed, unit: .count(), from: startOfDay, to: now)
        async let standHours = standHours(from: startOfDay, to: now)
        async let sleepMinutes = sleepDuration(from: sleepWindowStart, to: now)
        async let mindfulMinutes = mindfulDuration(from: startOfDay, to: now)
        async let restingHeartRate = latestQuantity(.restingHeartRate, unit: heartRateUnit, from: startOfDay, to: now)
        async let heartRate = latestQuantity(.heartRate, unit: heartRateUnit, from: startOfDay, to: now)
        async let hrv = latestQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), from: threeDaysAgo, to: now)
        async let weight = latestQuantity(.bodyMass, unit: .gramUnit(with: .kilo), from: ninetyDaysAgo, to: now)

        async let weeklySteps = dailySeries(.stepCount, unit: .count(), days: 7, endingAt: now)
        async let weeklyEnergy = dailySeries(.activeEnergyBurned, unit: .kilocalorie(), days: 7, endingAt: now)
        async let weeklyExercise = dailySeries(.appleExerciseTime, unit: .minute(), days: 7, endingAt: now)

        async let workouts = recentWorkouts(endingAt: now)
        async let sources = contributingSources(endingAt: now)

        let todaySteps = await steps
        let todayEnergy = await activeEnergy
        let todayExercise = await exerciseMinutes
        let todayDistance = await distance
        let todayFlights = await flights
        let todayStand = await standHours
        let todaySleep = await sleepMinutes
        let todayMindful = await mindfulMinutes
        let todayRestingHeartRate = await restingHeartRate
        let todayHeartRate = await heartRate
        let todayHRV = await hrv
        let todayWeight = await weight

        let stepsMap = await weeklySteps
        let energyMap = await weeklyEnergy
        let exerciseMap = await weeklyExercise
        let workoutList = await workouts
        let sourceList = await sources

        let todayStart = calendar.startOfDay(for: now)
        let weekly = (0..<7).reversed().compactMap { offset -> HealthDayPoint? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { return nil }
            return HealthDayPoint(
                date: day,
                steps: stepsMap[day] ?? 0,
                activeEnergyKcal: energyMap[day] ?? 0,
                exerciseMinutes: exerciseMap[day] ?? 0
            )
        }

        snapshot = HealthSnapshot(
            steps: todaySteps,
            activeEnergyKcal: todayEnergy,
            exerciseMinutes: todayExercise,
            standHours: todayStand,
            distanceMeters: todayDistance,
            flightsClimbed: todayFlights,
            sleepMinutes: todaySleep,
            mindfulMinutes: todayMindful,
            restingHeartRate: todayRestingHeartRate,
            heartRate: todayHeartRate,
            heartRateVariability: todayHRV,
            weightKg: todayWeight,
            weekly: weekly,
            workouts: workoutList,
            sources: sourceList,
            generatedAt: now
        )
        lastRefresh = now
    }

    // MARK: - Export

    /// Writes one completed Fitr day to Health as a workout. The workout is
    /// idempotent per calendar date and carries a Fitr external UUID and brand.
    @discardableResult
    func exportSession(date: String, tasks: [TrainingTask]) async -> Bool {
        guard isAvailable else {
            errorMessage = "Apple Health is not available on this device."
            return false
        }
        guard hasRequestedAccess else {
            errorMessage = "Connect Apple Health before saving a session."
            return false
        }
        if settings.hasExportedHealthSession(date) {
            lastExportDate = date
            return true
        }

        let completed = tasks.filter { $0.status == .done }
        guard !completed.isEmpty else {
            errorMessage = "Complete at least one task before saving the session."
            return false
        }

        if healthStore.authorizationStatus(for: HKObjectType.workoutType()) == .sharingDenied {
            errorMessage = "Fitr cannot save workouts. Allow workout access in Health → Sharing → Apps → Fitr."
            return false
        }

        isExporting = true
        defer { isExporting = false }

        let minutes = min(max(completed.reduce(0) { $0 + $1.durationMinutes }, 5), 180)
        let end = latestCompletion(in: completed) ?? defaultSessionEnd(for: date)
        let start = end.addingTimeInterval(-minutes * 60)
        let kind = dominantKind(in: completed)
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutType(for: kind)
        configuration.locationType = .indoor

        do {
            let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
            try await beginCollection(builder, at: start)
            try await addMetadata(builder, date: date)

            let weight = snapshot?.weightKg ?? 75
            let energy = kind.estimatedMET * weight * (minutes / 60)
            if let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
                let sample = HKQuantitySample(
                    type: energyType,
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: energy),
                    start: start,
                    end: end
                )
                try await addSamples(builder, samples: [sample])
            }

            try await endCollection(builder, at: end)
            guard try await finishWorkout(builder) != nil else {
                throw HealthStoreError.exportFailed
            }

            settings.markHealthSessionExported(date)
            lastExportDate = date
            errorMessage = nil
            await refresh()
            return true
        } catch {
            errorMessage = friendly(error)
            return false
        }
    }

    // MARK: - HealthKit reads

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        let quantityIDs: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .activeEnergyBurned,
            .appleExerciseTime,
            .distanceWalkingRunning,
            .flightsClimbed,
            .restingHeartRate,
            .heartRate,
            .heartRateVariabilitySDNN,
            .bodyMass,
        ]
        for identifier in quantityIDs {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        let categoryIDs: [HKCategoryTypeIdentifier] = [
            .sleepAnalysis,
            .appleStandHour,
            .mindfulSession,
        ]
        for identifier in categoryIDs {
            if let type = HKObjectType.categoryType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        return types
    }

    private var shareTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energy)
        }
        return types
    }

    private var heartRateUnit: HKUnit {
        HKUnit.count().unitDivided(by: .minute())
    }

    private func sum(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { (continuation: CheckedContinuation<Double?, Never>) in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    private func latestQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { (continuation: CheckedContinuation<Double?, Never>) in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                let sample = samples?.first as? HKQuantitySample
                continuation.resume(returning: sample?.quantity.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    private func dailySeries(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        days: Int,
        endingAt end: Date
    ) async -> [Date: Double] {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return [:] }
        let endOfToday = calendar.startOfDay(for: end)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: endOfToday) else { return [:] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { (continuation: CheckedContinuation<[Date: Double], Never>) in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: start,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { [calendar] _, collection, _ in
                var values: [Date: Double] = [:]
                collection?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    let key = calendar.startOfDay(for: statistics.startDate)
                    if let value = statistics.sumQuantity()?.doubleValue(for: unit) {
                        values[key] = value
                    }
                }
                continuation.resume(returning: values)
            }
            healthStore.execute(query)
        }
    }

    private func standHours(from start: Date, to end: Date) async -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .appleStandHour) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { (continuation: CheckedContinuation<Double?, Never>) in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let categorySamples = samples as? [HKCategorySample], !categorySamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let stood = categorySamples.filter {
                    $0.value == HKCategoryValueAppleStandHour.stood.rawValue
                }.count
                continuation.resume(returning: Double(stood))
            }
            healthStore.execute(query)
        }
    }

    private func sleepDuration(from start: Date, to end: Date) async -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let values: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        ]
        return await categoryDuration(type: type, values: values, from: start, to: end)
    }

    private func mindfulDuration(from start: Date, to end: Date) async -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return nil }
        return await categoryDuration(type: type, values: nil, from: start, to: end)
    }

    /// Sums category intervals after merging overlaps. Multiple apps can record
    /// the same night, so summing raw samples would double count sleep.
    private func categoryDuration(
        type: HKCategoryType,
        values: Set<Int>?,
        from start: Date,
        to end: Date
    ) async -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { (continuation: CheckedContinuation<Double?, Never>) in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                guard let categorySamples = samples as? [HKCategorySample], !categorySamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let intervals = categorySamples
                    .filter { values == nil || values?.contains($0.value) == true }
                    .map { ($0.startDate, $0.endDate) }
                let seconds = HealthStore.mergedDuration(intervals)
                continuation.resume(returning: seconds > 0 ? seconds / 60 : 0)
            }
            healthStore.execute(query)
        }
    }

    nonisolated static func mergedDuration(_ intervals: [(Date, Date)]) -> TimeInterval {
        let sorted = intervals
            .filter { $0.1 > $0.0 }
            .sorted { $0.0 < $1.0 }
        guard var currentStart = sorted.first?.0, var currentEnd = sorted.first?.1 else { return 0 }

        var total: TimeInterval = 0
        for (start, end) in sorted.dropFirst() {
            if start <= currentEnd {
                currentEnd = max(currentEnd, end)
            } else {
                total += currentEnd.timeIntervalSince(currentStart)
                currentStart = start
                currentEnd = end
            }
        }
        total += currentEnd.timeIntervalSince(currentStart)
        return total
    }

    private func recentWorkouts(endingAt end: Date) async -> [HealthWorkout] {
        guard let start = calendar.date(byAdding: .day, value: -14, to: end) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { (continuation: CheckedContinuation<[HealthWorkout], Never>) in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 12,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                let workouts = (samples as? [HKWorkout])?.map { workout -> HealthWorkout in
                    let descriptor = HealthStore.activityDescriptor(for: workout.workoutActivityType)
                    let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
                    let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
                    let energy = energyType.flatMap {
                        workout.statistics(for: $0)?.sumQuantity()?.doubleValue(for: .kilocalorie())
                    }
                    let distance = distanceType.flatMap {
                        workout.statistics(for: $0)?.sumQuantity()?.doubleValue(for: .meter())
                    }
                    let brand = workout.metadata?[HKMetadataKeyWorkoutBrandName] as? String
                    let isFitr = brand == "Fitr"
                        || workout.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier
                    return HealthWorkout(
                        id: workout.uuid,
                        activityName: descriptor.name,
                        icon: descriptor.icon,
                        start: workout.startDate,
                        durationMinutes: workout.endDate.timeIntervalSince(workout.startDate) / 60,
                        energyKcal: energy,
                        distanceMeters: distance,
                        sourceName: workout.sourceRevision.source.name,
                        isFromFitr: isFitr
                    )
                } ?? []
                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }
    }

    private func contributingSources(endingAt end: Date) async -> [HealthSource] {
        guard let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount),
              let start = calendar.date(byAdding: .day, value: -30, to: end) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { (continuation: CheckedContinuation<[HealthSource], Never>) in
            let query = HKSourceQuery(sampleType: stepsType, samplePredicate: predicate) { _, sources, _ in
                let list = (sources ?? [])
                    .map { HealthSource(name: $0.name, bundleIdentifier: $0.bundleIdentifier) }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                continuation.resume(returning: list)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Workout builder

    private func beginCollection(_ builder: HKWorkoutBuilder, at date: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: date) { success, error in
                if let error { continuation.resume(throwing: error) }
                else if success { continuation.resume(returning: ()) }
                else { continuation.resume(throwing: HealthStoreError.exportFailed) }
            }
        }
    }

    private func addMetadata(_ builder: HKWorkoutBuilder, date: String) async throws {
        let metadata: [String: Any] = [
            HKMetadataKeyExternalUUID: "fitr-session-\(date)",
            HKMetadataKeyWorkoutBrandName: "Fitr",
            "FitrSessionDate": date,
        ]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.addMetadata(metadata) { success, error in
                if let error { continuation.resume(throwing: error) }
                else if success { continuation.resume(returning: ()) }
                else { continuation.resume(throwing: HealthStoreError.exportFailed) }
            }
        }
    }

    private func addSamples(_ builder: HKWorkoutBuilder, samples: [HKSample]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.add(samples) { success, error in
                if let error { continuation.resume(throwing: error) }
                else if success { continuation.resume(returning: ()) }
                else { continuation.resume(throwing: HealthStoreError.exportFailed) }
            }
        }
    }

    private func endCollection(_ builder: HKWorkoutBuilder, at date: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: date) { success, error in
                if let error { continuation.resume(throwing: error) }
                else if success { continuation.resume(returning: ()) }
                else { continuation.resume(throwing: HealthStoreError.exportFailed) }
            }
        }
    }

    private func finishWorkout(_ builder: HKWorkoutBuilder) async throws -> HKWorkout? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout?, Error>) in
            builder.finishWorkout { workout, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: workout) }
            }
        }
    }

    // MARK: - Session mapping

    private func dominantKind(in tasks: [TrainingTask]) -> HealthSessionKind {
        let counts = Dictionary(grouping: tasks, by: { $0.exercise.topic.id }).mapValues(\.count)
        let topic = counts.max { lhs, rhs in lhs.value < rhs.value }?.key
        return HealthSessionKind(topicID: topic)
    }

    private func workoutType(for kind: HealthSessionKind) -> HKWorkoutActivityType {
        switch kind {
        case .strength: return .traditionalStrengthTraining
        case .functional: return .functionalStrengthTraining
        case .cardio: return .mixedCardio
        case .yoga: return .yoga
        case .mobility: return .flexibility
        case .recovery: return .mindAndBody
        case .other: return .other
        }
    }

    private func latestCompletion(in tasks: [TrainingTask]) -> Date? {
        tasks.compactMap { task -> Date? in
            guard let raw = task.completedAt else { return nil }
            return HealthStore.parseISO(raw)
        }.max()
    }

    private func defaultSessionEnd(for date: String) -> Date {
        let day = FitrDate.date(date)
        return calendar.date(bySettingHour: 19, minute: 0, second: 0, of: day) ?? day
    }

    private static func parseISO(_ value: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: value) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }

    nonisolated private static func activityDescriptor(for type: HKWorkoutActivityType) -> (name: String, icon: String) {
        switch type {
        case .running: return ("Run", "figure.run")
        case .walking: return ("Walk", "figure.walk")
        case .cycling: return ("Cycle", "bicycle")
        case .swimming: return ("Swim", "figure.pool.swim")
        case .traditionalStrengthTraining: return ("Strength", "dumbbell.fill")
        case .functionalStrengthTraining: return ("Functional", "figure.strengthtraining.functional")
        case .highIntensityIntervalTraining: return ("HIIT", "bolt.heart.fill")
        case .mixedCardio: return ("Cardio", "heart.circle.fill")
        case .yoga: return ("Yoga", "figure.yoga")
        case .flexibility: return ("Mobility", "figure.flexibility")
        case .mindAndBody: return ("Recovery", "figure.mind.and.body")
        case .hiking: return ("Hike", "figure.hiking")
        case .rowing: return ("Row", "figure.rower")
        case .elliptical: return ("Elliptical", "figure.elliptical")
        case .stairClimbing: return ("Stairs", "figure.stairs")
        case .jumpRope: return ("Jump rope", "figure.jumprope")
        case .coreTraining: return ("Core", "figure.core.training")
        case .pilates: return ("Pilates", "figure.pilates")
        case .dance: return ("Dance", "figure.dance")
        case .boxing: return ("Boxing", "figure.boxing")
        case .tennis: return ("Tennis", "figure.tennis")
        case .soccer: return ("Football", "figure.soccer")
        case .basketball: return ("Basketball", "figure.basketball")
        default: return ("Workout", "figure.mixed.cardio")
        }
    }

    // MARK: - Errors

    private func friendly(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == HKErrorDomain {
            switch nsError.code {
            case HKError.errorAuthorizationDenied.rawValue:
                return "Health access is denied. Open Health → Sharing → Apps → Fitr to allow it."
            case HKError.errorAuthorizationNotDetermined.rawValue:
                return "Apple Health permission has not been granted yet."
            case HKError.errorNoData.rawValue:
                return "There is no health data for this session yet."
            default:
                break
            }
        }
        return error.localizedDescription
    }

    private enum HealthStoreError: LocalizedError {
        case authorizationFailed
        case exportFailed

        var errorDescription: String? {
            switch self {
            case .authorizationFailed:
                return "Apple Health did not grant access."
            case .exportFailed:
                return "The workout could not be saved to Apple Health."
            }
        }
    }
}
