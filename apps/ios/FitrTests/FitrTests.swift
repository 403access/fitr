import XCTest
@testable import Fitr

final class FitrTests: XCTestCase {
    func testDateKeysRoundTrip() {
        let date = FitrDate.date("2026-11-08")
        XCTAssertEqual(FitrDate.key(date), "2026-11-08")
        XCTAssertEqual(FitrDate.key(FitrDate.addDays(1, to: date)), "2026-11-09")
    }

    func testWeekStartsOnMonday() {
        let sunday = FitrDate.date("2026-11-08")
        let monday = FitrDate.startOfWeek(sunday)
        XCTAssertEqual(FitrDate.key(monday), "2026-11-02")
        XCTAssertEqual(FitrDate.weekDates(containing: sunday).count, 7)
    }

    func testEveryAnimationHasMovement() {
        let keys = [
            "squat", "hinge", "lunge", "pushup", "pike", "bench", "row", "press",
            "curl", "lateralRaise", "calfRaise", "hipThrust", "bridge", "pullup",
            "dip", "plank", "sidePlank", "hollowHold", "legRaise", "mountainClimber",
            "burpee", "downwardDog", "cobra", "warrior", "tree", "childsPose",
            "catCow", "twist", "pigeon", "legsUp", "hipRotation", "shoulderStretch",
            "hipFlexorStretch", "hamstringStretch", "calfStretch", "neckStretch",
            "wristPrep", "breathe", "run", "jumpingJack", "boxing",
        ]
        for key in keys {
            let motion = ExerciseMotion.sequence(for: key)
            XCTAssertGreaterThanOrEqual(motion.keyframes.count, 2, "\(key) needs at least two poses")
            let first = motion.pose(at: 0)
            let middle = motion.pose(at: motion.duration / 2)
            let pairs: [(CGPoint, CGPoint)] = [
                (first.head, middle.head),
                (first.neck, middle.neck),
                (first.shoulderL, middle.shoulderL),
                (first.shoulderR, middle.shoulderR),
                (first.elbowL, middle.elbowL),
                (first.elbowR, middle.elbowR),
                (first.handL, middle.handL),
                (first.handR, middle.handR),
                (first.hipL, middle.hipL),
                (first.hipR, middle.hipR),
                (first.kneeL, middle.kneeL),
                (first.kneeR, middle.kneeR),
                (first.ankleL, middle.ankleL),
                (first.ankleR, middle.ankleR),
            ]
            let distance = pairs.reduce(CGFloat(0)) { partial, pair in
                partial + hypot(pair.0.x - pair.1.x, pair.0.y - pair.1.y)
            }
            XCTAssertGreaterThan(distance, 0.001, "\(key) does not move")
        }
    }

    func testBootstrapDecodes() throws {
        let json = """
        {
          "user": {"id":"me","name":"Alex","goal":"balanced","experience":"intermediate","daysPerWeek":5,"sessionMinutes":45,"equipment":[],"programStart":"2026-10-12"},
          "date":"2026-11-08",
          "weekStart":"2026-11-02",
          "plan":{"id":"p","weekStart":"2026-11-02","weekIndex":4,"focus":"Foundation","volumeMultiplier":1.18,"intensityMultiplier":1.12,"days":[],"summary":{"totalTasks":0,"completedTasks":0,"totalMinutes":0}},
          "today":{"date":"2026-11-08","totalTasks":0,"completedTasks":0,"skippedTasks":0,"totalMinutes":0,"completedMinutes":0,"adherence":0,"timeRegions":[]},
          "streak":{"current":0,"best":3,"lastActive":null},
          "facets":{"topics":[],"types":[],"regions":[],"muscles":[],"timeRegions":[]},
          "serverTime":"2026-11-08T10:00:00.000Z"
        }
        """
        let bootstrap = try JSONDecoder().decode(Bootstrap.self, from: Data(json.utf8))
        XCTAssertEqual(bootstrap.user.name, "Alex")
        XCTAssertEqual(bootstrap.plan.weekIndex, 4)
    }

    func testDurationFormatting() {
        XCTAssertEqual(FitrDate.minutes(42.4), "42 min")
        XCTAssertEqual(FitrDate.minutes(90), "1 h 30 m")
        XCTAssertEqual(FitrDate.delta(12.34), "+12.3%")
        XCTAssertEqual(FitrDate.weight(12.5), "12.5 kg")
    }

    func testOverlappingHealthIntervalsAreNotDoubleCounted() {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let intervals: [(Date, Date)] = [
            (base, base.addingTimeInterval(600)),
            (base.addingTimeInterval(300), base.addingTimeInterval(900)),
            (base.addingTimeInterval(1_200), base.addingTimeInterval(1_500)),
        ]
        XCTAssertEqual(HealthStore.mergedDuration(intervals), 1_200)
        XCTAssertEqual(HealthStore.mergedDuration([]), 0)
    }

    func testHealthSessionKindUsesExerciseTopics() {
        XCTAssertEqual(HealthSessionKind(topicID: "strength").estimatedMET, 5.0)
        XCTAssertEqual(HealthSessionKind(topicID: "yoga").estimatedMET, 3.0)
        XCTAssertEqual(HealthSessionKind(topicID: "mobility").estimatedMET, 2.5)
        XCTAssertEqual(HealthSessionKind(topicID: "recovery").estimatedMET, 2.0)
        XCTAssertEqual(HealthSessionKind(topicID: nil).estimatedMET, 4.0)
    }

    func testHealthAnalysisSummariesAndFilters() {
        XCTAssertEqual(HealthRange.day.days, 1)
        XCTAssertEqual(HealthRange.week.days, 7)
        XCTAssertEqual(HealthRange.month.days, 30)
        XCTAssertEqual(HealthRange.quarter.days, 90)
        XCTAssertEqual(HealthRange.year.days, 365)
        let start = FitrDate.date("2026-11-02")
        let series = (0..<7).map { offset in
            HealthSeriesPoint(
                date: FitrDate.addDays(offset, to: start),
                steps: Double((offset + 1) * 1_000),
                activeEnergyKcal: Double(100 + offset * 10),
                exerciseMinutes: 20,
                distanceMeters: 1_000,
                sleepMinutes: 420,
                restingHeartRate: 52,
                heartRate: 60,
                heartRateVariability: 40,
                mindfulMinutes: 5,
                weightKg: 80,
                standHours: 10
            )
        }
        let strength = HealthWorkout(
            id: UUID(),
            activityName: "Strength",
            icon: "dumbbell.fill",
            category: .strength,
            start: start,
            durationMinutes: 30,
            energyKcal: 120,
            distanceMeters: nil,
            sourceName: "Fitr",
            isFromFitr: true
        )
        let run = HealthWorkout(
            id: UUID(),
            activityName: "Run",
            icon: "figure.run",
            category: .cardio,
            start: FitrDate.addDays(1, to: start),
            durationMinutes: 20,
            energyKcal: 180,
            distanceMeters: 3_000,
            sourceName: "Apple Watch",
            isFromFitr: false
        )
        let analysis = HealthAnalysis(
            range: .week,
            series: series,
            workouts: [strength, run],
            sources: [HealthSource(name: "Fitr", bundleIdentifier: nil)],
            generatedAt: Date()
        )

        let steps = analysis.summary(for: .steps)
        XCTAssertEqual(steps.total, 28_000)
        XCTAssertEqual(steps.best, 7_000)
        XCTAssertEqual(steps.count, 7)
        XCTAssertEqual(analysis.fitrWorkoutCount, 1)
        XCTAssertEqual(analysis.workouts(category: .cardio).count, 1)
        XCTAssertEqual(analysis.workouts(source: "Fitr").count, 1)
    }
}
