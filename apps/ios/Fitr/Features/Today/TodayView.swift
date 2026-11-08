import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedTask: TrainingTask?

    private var accent: Color { Theme.lime }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                weekStrip

                if let message = store.errorMessage, store.isOffline {
                    ErrorBanner(message: message) {
                        Task { await store.refresh(date: store.selectedDate) }
                    } dismiss: {
                        store.dismissError()
                    }
                }

                if store.isLoading && store.bootstrap == nil {
                    loadingState
                } else if let bootstrap = store.bootstrap {
                    hero(bootstrap)
                    timeline(bootstrap)
                } else {
                    offlineState
                }

                footer
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await store.refresh(date: store.selectedDate, silent: true)
        }
        .sheet(item: $selectedTask) { task in
            ExercisePlayerView(task: task)
                .environment(store)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(34)
                .presentationBackground(Theme.ink)
        }
        .onAppear { openDebugPlayerIfNeeded() }
        .onChange(of: store.bootstrap?.serverTime) { _, _ in openDebugPlayerIfNeeded() }
    }

    private func openDebugPlayerIfNeeded() {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["FITR_PLAYER"] == "1",
              selectedTask == nil,
              let groups = store.today?.timeRegions else { return }
        let tasks = groups.flatMap(\.tasks)
        selectedTask = tasks.first { $0.timeRegion.id == "morning" && $0.status == .pending }
            ?? tasks.first { $0.status == .pending }
            ?? tasks.first
        #endif
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(FitrDate.greeting().uppercased())
                    .font(Theme.font(10, .bold))
                    .tracking(2)
                    .foregroundStyle(accent)
                Text(store.isViewingToday ? "Let's move,\n\(firstName)." : FitrDate.fullDate(store.selectedDate))
                    .font(Theme.font(32, .heavy))
                    .foregroundStyle(Theme.text)
                    .lineSpacing(-3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.violet.opacity(0.9), Theme.lime.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(initials)
                        .font(Theme.font(15, .heavy))
                        .foregroundStyle(Theme.ink)
                }
                .frame(width: 48, height: 48)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))

                if let streak = store.streak, streak.current > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                        Text("\(streak.current)")
                            .font(Theme.font(10, .bold))
                    }
                    .foregroundStyle(Theme.coral)
                }
            }
        }
    }

    // MARK: - Week strip

    private var weekStrip: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    Task { await store.shiftSelectedDate(by: -7) }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Theme.surfaceRaised))
                }
                .buttonStyle(.plain)

                Spacer()
                Text(FitrDate.monthYear(store.selectedDate).uppercased())
                    .font(Theme.font(10, .bold))
                    .tracking(1.8)
                    .foregroundStyle(Theme.textTertiary)
                Spacer()

                if !store.isViewingToday {
                    Button("Today") {
                        Task { await store.selectDate(Date()) }
                    }
                    .font(Theme.font(10, .bold))
                    .foregroundStyle(Theme.lime)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.lime.opacity(0.10)))
                }

                Button {
                    Task { await store.shiftSelectedDate(by: 7) }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Theme.surfaceRaised))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 5) {
                ForEach(FitrDate.weekDates(containing: store.selectedDate), id: \.self) { date in
                    dayCell(date)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.surface.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
    }

    private func dayCell(_ date: Date) -> some View {
        let key = FitrDate.key(date)
        let selected = FitrDate.isSameDay(date, store.selectedDate)
        let planDay = store.plan?.days.first { $0.date == key }
        let progress = planDay.map { $0.totalTasks == 0 ? 0 : Double($0.completedTasks) / Double($0.totalTasks) } ?? 0
        let isRest = planDay?.isRestDay ?? false

        return Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            Task { await store.selectDate(date) }
        } label: {
            VStack(spacing: 7) {
                Text(FitrDate.weekday(date))
                    .font(Theme.font(9, .bold))
                    .tracking(0.5)
                    .foregroundStyle(selected ? Theme.ink.opacity(0.65) : Theme.textTertiary)

                ZStack {
                    if selected {
                        Circle().fill(Theme.lime)
                    }
                    Text(FitrDate.dayNumber(date))
                        .font(Theme.font(16, .bold))
                        .foregroundStyle(selected ? Theme.ink : Theme.text)
                }
                .frame(height: 30)

                if isRest {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(selected ? Theme.ink.opacity(0.5) : Theme.sky.opacity(0.7))
                } else {
                    Capsule()
                        .fill(selected ? Theme.ink.opacity(0.22) : Color.white.opacity(0.08))
                        .frame(width: 16, height: 3)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(selected ? Theme.ink : Theme.lime)
                                .frame(width: 16 * progress, height: 3)
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.surfaceRaised)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(FitrDate.fullDate(date))
    }

    // MARK: - Hero

    private func hero(_ bootstrap: Bootstrap) -> some View {
        let today = bootstrap.today
        let progress = today.totalTasks == 0 ? 0 : Double(today.completedTasks) / Double(today.totalTasks)
        let volumeLift = Int(((bootstrap.plan.volumeMultiplier - 1) * 100).rounded())
        let restDay = store.selectedPlanDay?.isRestDay ?? false

        return ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.surfaceRaised,
                            accent.opacity(0.16),
                            Theme.surface,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .fill(accent.opacity(0.22))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: 150, y: -80)
            Circle()
                .strokeBorder(accent.opacity(0.13), lineWidth: 1)
                .frame(width: 260, height: 260)
                .offset(x: 120, y: -60)

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    FitrPill(
                        text: "WEEK \(String(format: "%02d", bootstrap.plan.weekIndex)) · \(bootstrap.plan.focus.uppercased())",
                        icon: "bolt.fill",
                        tint: accent
                    )
                    if restDay {
                        FitrPill(text: "Recovery", icon: "moon.stars.fill", tint: Theme.sky)
                    }
                    Spacer()
                    if volumeLift > 0 {
                        Text("+\(volumeLift)% volume")
                            .font(Theme.font(10, .bold))
                            .foregroundStyle(Theme.lime)
                    }
                }

                HStack(alignment: .center, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(restDay ? "Rest & restore." : "\(today.completedTasks) of \(today.totalTasks) done")
                            .font(Theme.font(25, .heavy))
                            .foregroundStyle(Theme.text)
                            .lineLimit(2)
                        Text(restDay ? "Keep it gentle. The plan adapts." : "\(FitrDate.minutes(today.completedMinutes)) of \(FitrDate.minutes(today.totalMinutes)) moved")
                            .font(Theme.font(13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    ZStack {
                        ProgressRing(progress: progress, lineWidth: 9, tint: accent)
                            .frame(width: 82, height: 82)
                        VStack(spacing: 0) {
                            Text("\(Int(progress * 100))")
                                .font(Theme.font(24, .heavy))
                                .foregroundStyle(Theme.text)
                                .contentTransition(.numericText())
                            Text("%")
                                .font(Theme.font(9, .bold))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }

                HStack(spacing: 8) {
                    heroStat(icon: "flame.fill", value: "\(bootstrap.streak.current)", label: "day streak", tint: Theme.coral)
                    heroStat(icon: "clock.fill", value: FitrDate.minutes(today.totalMinutes), label: "planned", tint: Theme.sky)
                    heroStat(icon: "calendar", value: "\(bootstrap.plan.summary.completedTasks)/\(bootstrap.plan.summary.totalTasks)", label: "this week", tint: Theme.violet)
                }
            }
            .padding(20)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    private func heroStat(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(Theme.font(13, .bold))
                    .foregroundStyle(Theme.text)
                Text(label)
                    .font(Theme.font(9))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }

    // MARK: - Timeline

    private func timeline(_ bootstrap: Bootstrap) -> some View {
        VStack(spacing: 18) {
            SectionHeading("Your rhythm", subtitle: FitrDate.relativeLabel(bootstrap.today.date)) {
                Text("\(bootstrap.today.completedTasks)/\(bootstrap.today.totalTasks)")
                    .font(Theme.mono(12, .bold))
                    .foregroundStyle(Theme.textSecondary)
            }

            ForEach(bootstrap.today.timeRegions.filter { !$0.tasks.isEmpty }) { group in
                TimeRegionSection(group: group, onSelect: { selectedTask = $0 })
            }

            if bootstrap.today.timeRegions.allSatisfy({ $0.tasks.isEmpty }) {
                EmptyPanel(
                    icon: "moon.stars.fill",
                    title: "Nothing scheduled",
                    message: "This window is wide open. Choose a gentle reset or simply rest.",
                    actionTitle: "Browse catalogue"
                )
            }

            if store.selectedPlanDay?.isRestDay == true {
                HStack(spacing: 12) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(Theme.mint)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.mint.opacity(0.1)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recovery is part of the plan")
                            .font(Theme.font(13, .semibold))
                            .foregroundStyle(Theme.text)
                        Text("Keep today easy. Tomorrow's volume steps up again.")
                            .font(Theme.font(11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.mint.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Theme.mint.opacity(0.15), lineWidth: 1)
                        )
                )
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(Theme.lime)
                .scaleEffect(1.2)
            Text("Syncing your rhythm…")
                .font(Theme.font(13))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var offlineState: some View {
        EmptyPanel(
            icon: "server.rack",
            title: "No plan yet",
            message: "Start the Fitr server and pull to refresh. The address is in You → Connection.",
            actionTitle: "Try again"
        ) {
            Task { await store.refresh(date: store.selectedDate) }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 13))
                .foregroundStyle(accent.opacity(0.7))
            Text(store.selectedPlanDay?.isRestDay == true ? "Rest is where adaptation happens." : "Small, precise work compounds.")
                .font(Theme.font(12, .medium))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var firstName: String {
        let name = store.user?.name ?? "Athlete"
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    private var initials: String {
        let name = store.user?.name ?? "A"
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "A" : String(letters)
    }
}

struct TimeRegionSection: View {
    let group: TimeRegionGroup
    let onSelect: (TrainingTask) -> Void
    @Environment(AppStore.self) private var store

    private var accent: Color {
        Theme.color(hex: group.tasks.first?.exercise.topic.accent ?? "#C9FB4B")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: group.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.name)
                        .font(Theme.font(14, .bold))
                        .foregroundStyle(Theme.text)
                    Text(group.hint)
                        .font(Theme.font(10))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 8) {
                    Text(FitrDate.minutes(group.totalMinutes))
                        .font(Theme.font(10, .medium))
                        .foregroundStyle(Theme.textTertiary)
                    Text("\(group.completed)/\(group.tasks.count)")
                        .font(Theme.mono(10, .bold))
                        .foregroundStyle(group.completed == group.tasks.count ? Theme.lime : Theme.textSecondary)
                }
            }
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(group.tasks) { task in
                    TaskRow(task: task, onSelect: { onSelect(task) })
                }
            }
        }
    }
}

struct TaskRow: View {
    let task: TrainingTask
    let onSelect: () -> Void
    @Environment(AppStore.self) private var store

    private var accent: Color { Theme.color(hex: task.exercise.topic.accent) }
    private var isDone: Bool { task.status == .done }
    private var isSkipped: Bool { task.status == .skipped }

    var body: some View {
        HStack(spacing: 12) {
            ExerciseThumbnail(exercise: task.exercise, size: 58, isActive: !isDone && !isSkipped)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.exercise.name)
                    .font(Theme.font(14, .semibold))
                    .foregroundStyle(isDone ? Theme.textSecondary : Theme.text)
                    .strikethrough(isDone, color: Theme.textTertiary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(task.targetNote)
                        .font(Theme.font(11, .medium))
                        .foregroundStyle(isSkipped ? Theme.coral.opacity(0.8) : accent)
                    Text("·")
                        .foregroundStyle(Theme.textTertiary)
                    Text(FitrDate.minutes(task.durationMinutes))
                        .font(Theme.font(11))
                        .foregroundStyle(Theme.textTertiary)
                }
                if isDone, let effort = task.effort {
                    Text("Effort \(effort)/10")
                        .font(Theme.font(9, .medium))
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            Spacer(minLength: 2)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task { await store.quickToggle(task) }
            } label: {
                ZStack {
                    Circle()
                        .fill(statusBackground)
                        .frame(width: 34, height: 34)
                        .overlay(Circle().strokeBorder(statusBorder, lineWidth: 1.4))
                    Image(systemName: statusIcon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(statusForeground)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDone ? "Mark \(task.exercise.name) as not done" : "Complete \(task.exercise.name)")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.surface.opacity(isDone ? 0.45 : 0.86))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(isDone ? Theme.lime.opacity(0.16) : Theme.stroke, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .contextMenu {
            if isDone {
                Button { Task { await store.reset(task) } } label: {
                    Label("Mark as not done", systemImage: "arrow.uturn.backward")
                }
            } else {
                Button { Task { await store.skip(task) } } label: {
                    Label("Skip for today", systemImage: "forward.fill")
                }
            }
            Button { onSelect() } label: {
                Label("Open details", systemImage: "arrow.up.right")
            }
        }
        .opacity(isSkipped ? 0.6 : 1)
    }

    private var statusBackground: Color {
        if isDone { return Theme.lime }
        if isSkipped { return Theme.coral.opacity(0.12) }
        return Color.white.opacity(0.04)
    }

    private var statusBorder: Color {
        if isDone { return .clear }
        if isSkipped { return Theme.coral.opacity(0.4) }
        return Color.white.opacity(0.18)
    }

    private var statusIcon: String {
        if isDone { return "checkmark" }
        if isSkipped { return "minus" }
        return "circle"
    }

    private var statusForeground: Color {
        if isDone { return Theme.ink }
        if isSkipped { return Theme.coral }
        return Theme.textTertiary.opacity(0.5)
    }
}
