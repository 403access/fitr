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
    private(set) var analysis: HealthAnalysis?
    private(set) var analysisRange: HealthRange = .month
    private(set) var isAvailable = HKHealthStore.isHealthDataAvailable()
    private(set) var isLoading = false
    private(set) var isLoadingAnalysis = false
    private(set) var isExporting = false
    private(set) var lastRefresh: Date?
    private(set) var lastExportDate: String?

    var errorMessage: String?
    var analysisError: String?

    private var analysisCache: [HealthRange: HealthAnalysis] = [:]

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
        let weeklyStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -6, to: now) ?? now)
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

        async let weeklySteps = dailySeries(.stepCount, unit: .count(), from: weeklyStart, to: now)
        async let weeklyEnergy = dailySeries(.activeEnergyBurned, unit: .kilocalorie(), from: weeklyStart, to: now)
        async let weeklyExercise = dailySeries(.appleExerciseTime, unit: .minute(), from: weeklyStart, to: now)

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
        analysisCache.removeAll()
        lastRefresh = now
    }

    // MARK: - Analysis

    /// Loads a multi-metric daily series for the selected range. Snapshots power
    /// the Overview; the analysis powers Trends, Workouts and Sources.
    func loadAnalysis(range: HealthRange, force: Bool = false) async {
        guard isConnected else { return }
        analysisRange = range
        if !force, let cached = analysisCache[range] {
            analysis = cached
            analysisError = nil
            return
        }

        analysis = nil
        isLoadingAnalysis = true
        defer { isLoadingAnalysis = false }

        let now = Date()
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(range.days - 1), to: today) else { return }

        async let steps = dailySeries(.stepCount, unit: .count(), from: start, to: now)
        async let activeEnergy = dailySeries(.activeEnergyBurned, unit: .kilocalorie(), from: start, to: now)
        async let exercise = dailySeries(.appleExerciseTime, unit: .minute(), from: start, to: now)
        async let distance = dailySeries(.distanceWalkingRunning, unit: .meter(), from: start, to: now)
        async let sleep = sleepSeries(from: start, to: now)
        async let restingHeartRate = dailySeries(
            .restingHeartRate,
            unit: heartRateUnit,
            from: start,
            to: now,
            options: .discreteAverage
        )
        async let heartRate = dailySeries(
            .heartRate,
            unit: heartRateUnit,
            from: start,
            to: now,
            options: .discreteAverage
        )
        async let hrv = dailySeries(
            .heartRateVariabilitySDNN,
            unit: .secondUnit(with: .milli),
            from: start,
            to: now,
            options: .discreteAverage
        )
        async let mindful = mindfulSeries(from: start, to: now)
        async let weight = dailySeries(
            .bodyMass,
            unit: .gramUnit(with: .kilo),
            from: start,
            to: now,
            options: .discreteAverage
        )
        async let stand = standSeries(from: start, to: now)
        async let workoutList = workouts(from: start, to: now)
        async let sourceList = contributingSources(from: start, to: now)

        let stepsMap = await steps
        let energyMap = await activeEnergy
        let exerciseMap = await exercise
        let distanceMap = await distance
        let sleepMap = await sleep
        let restingMap = await restingHeartRate
        let heartMap = await heartRate
        let hrvMap = await hrv
        let mindfulMap = await mindful
        let weightMap = await weight
        let standMap = await stand
        let workouts = await workoutList
        var sources = await sourceList
        for workout in workouts where !sources.contains(where: { $0.name == workout.sourceName }) {
            sources.append(HealthSource(name: workout.sourceName, bundleIdentifier: nil))
        }
        sources.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        var series: [HealthSeriesPoint] = []
        series.reserveCapacity(range.days)
        for offset in 0..<range.days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            series.append(
                HealthSeriesPoint(
                    date: day,
                    steps: stepsMap[day],
                    activeEnergyKcal: energyMap[day],
                    exerciseMinutes: exerciseMap[day],
                    distanceMeters: distanceMap[day],
                    sleepMinutes: sleepMap[day],
                    restingHeartRate: restingMap[day],
                    heartRate: heartMap[day],
                    heartRateVariability: hrvMap[day],
                    mindfulMinutes: mindfulMap[day],
                    weightKg: weightMap[day],
                    standHours: standMap[day]
                )
            )
        }

        let result = HealthAnalysis(
            range: range,
            series: series,
            workouts: workouts,
            sources: sources,
            generatedAt: now
        )
        analysis = result
        analysisCache[range] = result
        analysisError = nil
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
            analysisCache.removeAll()
            await refresh()
            await loadAnalysis(range: analysisRange, force: true)
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
        from start: Date,
        to end: Date,
        options: HKStatisticsOptions = .cumulativeSum
    ) async -> [Date: Double] {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return [:] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { (continuation: CheckedContinuation<[Date: Double], Never>) in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: start,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { [calendar] _, collection, _ in
                var values: [Date: Double] = [:]
                collection?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    let key = calendar.startOfDay(for: statistics.startDate)
                    let quantity: HKQuantity?
                    if options.contains(.discreteAverage) {
                        quantity = statistics.averageQuantity()
                    } else {
                        quantity = statistics.sumQuantity()
                    }
                    if let value = quantity?.doubleValue(for: unit) {
                        values[key] = value
                    }
                }
                continuation.resume(returning: values)
            }
            healthStore.execute(query)
        }
    }

    private func categorySamples(
        type: HKCategoryType,
        values: Set<Int>?,
        from start: Date,
        to end: Date
    ) async -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { (continuation: CheckedContinuation<[HKCategorySample], Never>) in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                let categorySamples = (samples as? [HKCategorySample]) ?? []
                continuation.resume(returning: categorySamples.filter {
                    values == nil || values?.contains($0.value) == true
                })
            }
            healthStore.execute(query)
        }
    }

    private func standHours(from start: Date, to end: Date) async -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .appleStandHour) else { return nil }
        let samples = await categorySamples(type: type, values: nil, from: start, to: end)
        guard !samples.isEmpty else { return nil }
        let stood = samples.filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }.count
        return Double(stood)
    }

    private func standSeries(from start: Date, to end: Date) async -> [Date: Double] {
        guard let type = HKObjectType.categoryType(forIdentifier: .appleStandHour) else { return [:] }
        let samples = await categorySamples(type: type, values: nil, from: start, to: end)
        var values: [Date: Double] = [:]
        for sample in samples where sample.value == HKCategoryValueAppleStandHour.stood.rawValue {
            let day = calendar.startOfDay(for: sample.startDate)
            values[day, default: 0] += 1
        }
        return values
    }

    private func sleepDuration(from start: Date, to end: Date) async -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let samples = await categorySamples(type: type, values: sleepValues, from: start, to: end)
        guard !samples.isEmpty else { return nil }
        let seconds = HealthStore.mergedDuration(samples.map { ($0.startDate, $0.endDate) })
        return seconds > 0 ? seconds / 60 : 0
    }

    private func sleepSeries(from start: Date, to end: Date) async -> [Date: Double] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [:] }
        let samples = await categorySamples(type: type, values: sleepValues, from: start, to: end)
        var intervalsByDay: [Date: [(Date, Date)]] = [:]
        for sample in samples {
            // Attribute a night's sleep to the morning the user woke up.
            let day = calendar.startOfDay(for: sample.endDate)
            intervalsByDay[day, default: []].append((sample.startDate, sample.endDate))
        }
        return intervalsByDay.mapValues { intervals in
            HealthStore.mergedDuration(intervals) / 60
        }
    }

    private func mindfulDuration(from start: Date, to end: Date) async -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return nil }
        let samples = await categorySamples(type: type, values: nil, from: start, to: end)
        guard !samples.isEmpty else { return nil }
        let seconds = HealthStore.mergedDuration(samples.map { ($0.startDate, $0.endDate) })
        return seconds > 0 ? seconds / 60 : 0
    }

    private func mindfulSeries(from start: Date, to end: Date) async -> [Date: Double] {
        guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return [:] }
        let samples = await categorySamples(type: type, values: nil, from: start, to: end)
        var intervalsByDay: [Date: [(Date, Date)]] = [:]
        for sample in samples {
            let day = calendar.startOfDay(for: sample.startDate)
            intervalsByDay[day, default: []].append((sample.startDate, sample.endDate))
        }
        return intervalsByDay.mapValues { intervals in
            HealthStore.mergedDuration(intervals) / 60
        }
    }

    private var sleepValues: Set<Int> {
        [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        ]
    }

    /// Sums category intervals after merging overlaps. Multiple apps can record
    /// the same night, so summing raw samples would double count sleep.
    private func categoryDuration(
        type: HKCategoryType,
        values: Set<Int>?,
        from start: Date,
        to end: Date
    ) async -> Double? {
        let samples = await categorySamples(type: type, values: values, from: start, to: end)
        guard !samples.isEmpty else { return nil }
        let seconds = HealthStore.mergedDuration(samples.map { ($0.startDate, $0.endDate) })
        return seconds > 0 ? seconds / 60 : 0
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

    private func workouts(
        from start: Date,
        to end: Date,
        limit: Int = HKObjectQueryNoLimit
    ) async -> [HealthWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { (continuation: CheckedContinuation<[HealthWorkout], Never>) in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: limit,
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
                        category: descriptor.category,
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

    private func recentWorkouts(endingAt end: Date) async -> [HealthWorkout] {
        guard let start = calendar.date(byAdding: .day, value: -14, to: end) else { return [] }
        return await workouts(from: start, to: end, limit: 12)
    }

    private func contributingSources(from start: Date, to end: Date) async -> [HealthSource] {
        guard let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return [] }
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

    private func contributingSources(endingAt end: Date) async -> [HealthSource] {
        guard let start = calendar.date(byAdding: .day, value: -30, to: end) else { return [] }
        return await contributingSources(from: start, to: end)
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

    nonisolated private static func activityDescriptor(
        for type: HKWorkoutActivityType
    ) -> (name: String, icon: String, category: HealthWorkoutCategory) {
        switch type {
        case .running: return ("Run", "figure.run", .cardio)
        case .walking: return ("Walk", "figure.walk", .cardio)
        case .cycling: return ("Cycle", "bicycle", .cardio)
        case .swimming: return ("Swim", "figure.pool.swim", .cardio)
        case .traditionalStrengthTraining: return ("Strength", "dumbbell.fill", .strength)
        case .functionalStrengthTraining: return ("Functional", "figure.strengthtraining.functional", .strength)
        case .highIntensityIntervalTraining: return ("HIIT", "bolt.heart.fill", .cardio)
        case .mixedCardio: return ("Cardio", "heart.circle.fill", .cardio)
        case .yoga: return ("Yoga", "figure.yoga", .yoga)
        case .flexibility: return ("Mobility", "figure.flexibility", .mobility)
        case .mindAndBody: return ("Recovery", "figure.mind.and.body", .recovery)
        case .hiking: return ("Hike", "figure.hiking", .cardio)
        case .rowing: return ("Row", "figure.rower", .cardio)
        case .elliptical: return ("Elliptical", "figure.elliptical", .cardio)
        case .stairClimbing: return ("Stairs", "figure.stairs", .cardio)
        case .jumpRope: return ("Jump rope", "figure.jumprope", .cardio)
        case .coreTraining: return ("Core", "figure.core.training", .strength)
        case .pilates: return ("Pilates", "figure.pilates", .mobility)
        case .dance: return ("Dance", "figure.dance", .cardio)
        case .boxing: return ("Boxing", "figure.boxing", .cardio)
        case .tennis: return ("Tennis", "figure.tennis", .cardio)
        case .soccer: return ("Football", "figure.soccer", .cardio)
        case .basketball: return ("Basketball", "figure.basketball", .cardio)
        default: return ("Workout", "figure.mixed.cardio", .other)
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
