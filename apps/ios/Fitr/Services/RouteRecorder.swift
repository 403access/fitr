import CoreLocation
import Foundation
import Observation

/// JSON archive for movement recorded on this iPhone. Routes are deliberately
/// local-only: they are never sent to the Fitr API and are pruned after a year.
enum RouteArchive {
    static let retentionDays = 400

    private static var fileURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = base.appendingPathComponent("Fitr", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("routes.json")
    }

    static func load() -> [RecordedRoute] {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([RecordedRoute].self, from: data)) ?? []
    }

    static func save(_ routes: [RecordedRoute]) {
        guard let fileURL, let data = try? JSONEncoder().encode(routes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func pruned(_ routes: [RecordedRoute], now: Date = Date()) -> [RecordedRoute] {
        guard let cutoff = FitrDate.calendar.date(byAdding: .day, value: -retentionDays, to: now) else {
            return routes
        }
        return routes.filter { $0.end >= cutoff }
    }
}

/// Records a continuous GPS trail while the user opts in. Apple Health only
/// exposes GPS for workouts, so this is how Fitr creates day-long movement
/// history from now on. iOS will keep updating in the background when the
/// location background mode and "Always" permission are granted.
@MainActor
@Observable
final class RouteRecorder: NSObject, CLLocationManagerDelegate {
    private let settings: AppSettings
    private let manager = CLLocationManager()

    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var isRecording = false
    private(set) var lastPointAt: Date?
    var errorMessage: String?

    private var recordedRoutes: [RecordedRoute] = RouteArchive.load()
    @ObservationIgnored private var activeRouteID: UUID?
    @ObservationIgnored private var lastSavedAt = Date.distantPast

    /// Split a trail when the user has been stationary for a while instead of
    /// drawing a straight line between two unrelated places.
    private let segmentGap: TimeInterval = 15 * 60
    private let saveInterval: TimeInterval = 15

    init(settings: AppSettings) {
        self.settings = settings
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 30
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - State

    var isAuthorized: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }

    var canRecordInBackground: Bool { authorizationStatus == .authorizedAlways }

    var recordedRouteCount: Int { recordedRoutes.count }

    var todayPointCount: Int {
        let today = FitrDate.calendar.startOfDay(for: Date())
        return recordedRoutes
            .filter { FitrDate.calendar.isDate($0.start, inSameDayAs: today) }
            .reduce(0) { $0 + $1.points.count }
    }

    var statusLabel: String {
        switch authorizationStatus {
        case .authorizedAlways: return "Always allowed"
        case .authorizedWhenInUse: return "While using Fitr"
        case .denied, .restricted: return "Location off"
        case .notDetermined: return "Not asked yet"
        @unknown default: return "Unknown"
        }
    }

    // MARK: - Control

    /// Called on launch and whenever the app becomes active so an enabled
    /// recorder resumes without another permission sheet.
    func resumeIfNeeded() {
        guard settings.recordGPSHistory else { return }
        start()
    }

    func setEnabled(_ enabled: Bool) {
        settings.recordGPSHistory = enabled
        if enabled {
            start()
        } else {
            stop()
        }
    }

    func requestAccess() {
        settings.recordGPSHistory = true
        if authorizationStatus == .notDetermined {
            manager.requestAlwaysAuthorization()
        } else {
            start()
        }
    }

    /// Upgrades "While Using Fitr" to "Always" so recording survives in the
    /// background. Safe to call after the initial permission sheet.
    func requestBackgroundAccess() {
        settings.recordGPSHistory = true
        manager.requestAlwaysAuthorization()
    }

    func start() {
        guard settings.recordGPSHistory else { return }
        switch authorizationStatus {
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            guard !isRecording else { return }
            errorMessage = nil
            isRecording = true
            manager.startUpdatingLocation()
        case .denied, .restricted:
            isRecording = false
            errorMessage = "Location access is off. Enable it in Settings → Fitr → Location."
        @unknown default:
            break
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        isRecording = false
        activeRouteID = nil
        persistNow()
    }

    func persistNow() {
        recordedRoutes = RouteArchive.pruned(recordedRoutes)
        RouteArchive.save(recordedRoutes)
        lastSavedAt = Date()
    }

    /// Routes that overlap the requested window, newest first.
    func routes(from start: Date, to end: Date) -> [HealthRoute] {
        recordedRoutes
            .filter { $0.end >= start && $0.start <= end && $0.points.count >= 2 }
            .map(\.healthRoute)
    }

    // MARK: - Ingest

    private func ingest(_ points: [RoutePoint]) {
        guard settings.recordGPSHistory else { return }
        for point in points.sorted(by: { $0.timestamp < $1.timestamp }) {
            append(point)
            lastPointAt = point.timestamp
        }
        persistIfNeeded()
    }

    private func append(_ point: RoutePoint) {
        if let id = activeRouteID,
           let index = recordedRoutes.firstIndex(where: { $0.id == id }) {
            let gap = point.timestamp.timeIntervalSince(recordedRoutes[index].end)
            if gap < 0 {
                return
            }
            if gap <= segmentGap {
                recordedRoutes[index].points.append(point)
                recordedRoutes[index].end = point.timestamp
                return
            }
            // A long pause starts a new segment.
            activeRouteID = nil
        }

        let route = RecordedRoute(
            id: UUID(),
            start: point.timestamp,
            end: point.timestamp,
            points: [point]
        )
        recordedRoutes.append(route)
        activeRouteID = route.id
    }

    private func persistIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastSavedAt) >= saveInterval else { return }
        persistNow()
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        guard settings.recordGPSHistory else {
            isRecording = false
            return
        }
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            start()
        case .denied, .restricted:
            isRecording = false
            errorMessage = "Location access is off. Enable it in Settings → Fitr → Location."
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.handleAuthorization(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let points = locations.compactMap { location -> RoutePoint? in
            guard location.horizontalAccuracy > 0, location.horizontalAccuracy <= 120 else { return nil }
            guard location.timestamp.timeIntervalSinceNow > -180 else { return nil }
            return RoutePoint(location: location)
        }
        guard !points.isEmpty else { return }
        Task { @MainActor in
            self.ingest(points)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            guard self.isRecording else { return }
            self.errorMessage = error.localizedDescription
        }
    }
}
