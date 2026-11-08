import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppStore {
    let settings: AppSettings

    private(set) var api: APIClient
    private(set) var bootstrap: Bootstrap?
    private(set) var catalog: CatalogResource?
    private(set) var progress: ProgressSummary?

    var selectedDate: Date = Date()
    var progressPeriod: TrainingPeriod = .week
    var progressAnchor: Date = Date()

    var isLoading = true
    var isLoadingProgress = false
    var isMutating = false
    var isSavingProfile = false
    var isOffline = false
    var errorMessage: String?
    var progressError: String?
    var toast: String?
    var hasStarted = false

    private var progressCache: [String: ProgressSummary] = [:]

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
        let url = settings.serverURL ?? URL(string: AppSettings.defaultServerURL)!
        api = APIClient(baseURL: url)
        catalog = CatalogStore.load()
    }

    // MARK: - Derived

    var user: UserProfile? { bootstrap?.user }
    var plan: TrainingPlan? { bootstrap?.plan }
    var facets: Facets { bootstrap?.facets ?? catalog?.facets ?? .empty }
    var exercises: [Exercise] { catalog?.exercises ?? [] }
    var today: TodaySnapshot? { bootstrap?.today }
    var streak: StreakInfo? { bootstrap?.streak }

    var selectedKey: String { FitrDate.key(selectedDate) }
    var isViewingToday: Bool { FitrDate.isSameDay(selectedDate, Date()) }

    var selectedPlanDay: PlanDay? {
        plan?.days.first { $0.date == selectedKey }
    }

    var todayGroups: [TimeRegionGroup] { today?.timeRegions ?? [] }

    var weekdayLabel: String {
        isViewingToday ? "Today" : FitrDate.fullDate(selectedDate)
    }

    func accent(for topicID: String) -> Color {
        Theme.accent(for: topicID)
    }

    // MARK: - Lifecycle

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        if let cached = BootstrapCache.load() {
            bootstrap = cached
            selectedDate = FitrDate.date(cached.date)
            isLoading = false
        }
        await refresh()
        if progress == nil {
            await loadProgress(period: .week, anchor: Date())
        }
    }

    func refresh(date: Date? = nil, silent: Bool = false) async {
        guard let url = settings.serverURL else {
            errorMessage = FitrAPIError.invalidURL.errorDescription
            isLoading = false
            return
        }
        if await api.baseURL != url {
            await api.setBaseURL(url)
        }
        let target = date ?? selectedDate
        if !silent { isLoading = bootstrap == nil }
        do {
            let payload = try await api.bootstrap(date: FitrDate.key(target))
            bootstrap = payload
            selectedDate = FitrDate.date(payload.date)
            isOffline = false
            errorMessage = nil
            BootstrapCache.save(payload)
        } catch {
            isOffline = true
            errorMessage = friendly(error)
            if bootstrap == nil, let cached = BootstrapCache.load() {
                bootstrap = cached
            }
        }
        isLoading = false
    }

    func selectDate(_ date: Date) async {
        selectedDate = date
        await refresh(date: date, silent: true)
    }

    func shiftSelectedDate(by days: Int) async {
        await selectDate(FitrDate.addDays(days, to: selectedDate))
    }

    func reconnect(serverURL: String) async {
        settings.serverURLString = serverURL
        guard let url = settings.serverURL else {
            errorMessage = FitrAPIError.invalidURL.errorDescription
            return
        }
        api = APIClient(baseURL: url)
        errorMessage = nil
        await refresh()
        await loadProgress(period: progressPeriod, anchor: progressAnchor, force: true)
    }

    // MARK: - Training actions

    func complete(
        _ task: TrainingTask,
        actualReps: Int?,
        actualHoldSeconds: Int?,
        actualLoadKg: Double?,
        effort: Int?
    ) async -> Bool {
        guard !isMutating else { return false }
        isMutating = true
        defer { isMutating = false }
        do {
            _ = try await api.complete(
                taskID: task.id,
                body: CompletionRequest(
                    actualReps: actualReps,
                    actualHoldSeconds: actualHoldSeconds,
                    actualLoadKg: actualLoadKg,
                    effort: effort
                )
            )
            await refresh(date: selectedDate, silent: true)
            invalidateProgress()
            showToast("\(task.exercise.name) logged")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        } catch {
            errorMessage = friendly(error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return false
        }
    }

    func quickToggle(_ task: TrainingTask) async {
        if task.status == .done {
            await reset(task)
            return
        }
        _ = await complete(
            task,
            actualReps: task.reps,
            actualHoldSeconds: task.holdSeconds,
            actualLoadKg: task.loadKg,
            effort: 7
        )
    }

    func skip(_ task: TrainingTask) async {
        guard !isMutating else { return }
        isMutating = true
        defer { isMutating = false }
        do {
            _ = try await api.skip(taskID: task.id)
            await refresh(date: selectedDate, silent: true)
            invalidateProgress()
            showToast("Skipped \(task.exercise.name)")
        } catch {
            errorMessage = friendly(error)
        }
    }

    func reset(_ task: TrainingTask) async {
        guard !isMutating else { return }
        isMutating = true
        defer { isMutating = false }
        do {
            _ = try await api.reset(taskID: task.id)
            await refresh(date: selectedDate, silent: true)
            invalidateProgress()
        } catch {
            errorMessage = friendly(error)
        }
    }

    // MARK: - Progress

    func loadProgress(period: TrainingPeriod, anchor: Date, force: Bool = false) async {
        progressPeriod = period
        progressAnchor = anchor
        let key = cacheKey(period: period, anchor: anchor)
        if !force, let cached = progressCache[key] {
            progress = cached
            progressError = nil
            return
        }
        if progress == nil { isLoadingProgress = true }
        do {
            let summary = try await api.progress(period: period, anchor: FitrDate.key(anchor))
            progress = summary
            progressCache[key] = summary
            progressError = nil
        } catch {
            progressError = friendly(error)
        }
        isLoadingProgress = false
    }

    func shiftProgress(by direction: Int) async {
        let calendar = FitrDate.calendar
        let next: Date?
        switch progressPeriod {
        case .day:
            next = calendar.date(byAdding: .day, value: direction, to: progressAnchor)
        case .week:
            next = calendar.date(byAdding: .weekOfYear, value: direction, to: progressAnchor)
        case .month:
            next = calendar.date(byAdding: .month, value: direction, to: progressAnchor)
        case .year:
            next = calendar.date(byAdding: .year, value: direction, to: progressAnchor)
        }
        if let next { await loadProgress(period: progressPeriod, anchor: next) }
    }

    func setProgressPeriod(_ period: TrainingPeriod) async {
        await loadProgress(period: period, anchor: progressAnchor)
    }

    private func cacheKey(period: TrainingPeriod, anchor: Date) -> String {
        "\(period.rawValue)-\(FitrDate.key(anchor))"
    }

    private func invalidateProgress() {
        progressCache.removeAll()
        Task { await loadProgress(period: progressPeriod, anchor: progressAnchor, force: true) }
    }

    // MARK: - Profile

    func saveProfile(_ patch: ProfilePatch) async -> Bool {
        guard !isSavingProfile else { return false }
        isSavingProfile = true
        defer { isSavingProfile = false }
        do {
            _ = try await api.updateProfile(patch)
            await refresh(date: selectedDate, silent: true)
            // A settings change only shapes future weeks; regenerate the next
            // week's plan eagerly so the effect is visible in the catalogue of days.
            showToast("Profile saved · new rhythm applies next week")
            return true
        } catch {
            errorMessage = friendly(error)
            return false
        }
    }

    func finishOnboarding() {
        settings.hasOnboarded = true
        Task { await refresh() }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func showToast(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            if toast == message { toast = nil }
        }
    }

    private func friendly(_ error: Error) -> String {
        if let apiError = error as? FitrAPIError {
            return [apiError.errorDescription, apiError.recoverySuggestion]
                .compactMap { $0 }
                .joined(separator: " ")
        }
        return error.localizedDescription
    }
}
