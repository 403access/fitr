import Charts
import SwiftUI

struct HealthView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var section: HealthSection = .overview
    @State private var range: HealthRange = .month
    @State private var metric: HealthMetric = .steps
    @State private var workoutCategory: HealthWorkoutCategory?
    @State private var workoutSource: String?

    private var health: HealthStore { store.health }
    private var snapshot: HealthSnapshot? { health.snapshot }
    private var analysis: HealthAnalysis? { health.analysis }

    init() {
        var initial: HealthSection = .overview
#if DEBUG
        if let raw = ProcessInfo.processInfo.environment["FITR_HEALTH_SECTION"],
           let parsed = HealthSection(rawValue: raw) {
            initial = parsed
        }
#endif
        _section = State(initialValue: initial)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if let message = health.errorMessage {
                    healthErrorBanner(message)
                }

                if !health.isAvailable {
                    unavailablePanel
                } else if !health.hasRequestedAccess {
                    connectCard
                } else {
                    sectionPicker

                    switch section {
                    case .overview:
                        overviewSection
                    case .trends:
                        trendsSection
                    case .workouts:
                        workoutsExplorer
                    case .sources:
                        sourcesExplorer
                    case .routes:
                        HealthRoutesSection(range: $range)
                    }
                }

                privacyFooter
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await health.refreshIfConnected()
            if section == .routes {
                await health.loadRoutes(range: range, force: true)
            } else if section != .overview {
                await health.loadAnalysis(range: range, force: true)
            }
        }
        .task {
            await health.refreshIfConnected()
            if section == .routes {
                await health.loadRoutes(range: range)
            } else if section != .overview {
                await health.loadAnalysis(range: range)
            }
        }
        .onChange(of: section) { _, newValue in
            guard newValue != .overview, health.hasRequestedAccess else { return }
            if newValue == .routes {
                Task { await health.loadRoutes(range: range) }
            } else {
                Task { await health.loadAnalysis(range: range) }
            }
        }
        .onChange(of: range) { _, newValue in
            workoutSource = nil
            guard section != .overview, health.hasRequestedAccess else { return }
            if section == .routes {
                Task { await health.loadRoutes(range: newValue) }
            } else {
                Task { await health.loadAnalysis(range: newValue) }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await health.refreshIfConnected() }
        }
    }

    @ViewBuilder
    private var overviewSection: some View {
        if health.isLoading && snapshot == nil {
            loadingState
        } else if let snapshot, snapshot.hasAnyData {
            activityHero(snapshot)
            metricsGrid(snapshot)
            weeklyChart(snapshot)
            workoutsSection(snapshot)
            sourcesSection(snapshot)
            exportCard
        } else {
            emptyHealthState
            exportCard
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("BODY SIGNAL")
                    .font(Theme.font(10, .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.coral)
                Text("Health")
                    .font(Theme.font(34, .heavy))
                    .foregroundStyle(Theme.text)
                Text("Your watch, ring and apps — one honest picture.")
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                FitrPill(
                    text: health.permissionLabel,
                    icon: health.isConnected ? "heart.fill" : "heart.slash.fill",
                    tint: health.isConnected ? Theme.coral : Theme.textSecondary
                )
                Button {
                    Task { await health.refreshIfConnected() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Theme.surface))
                        .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh health data")
                .disabled(!health.isConnected || health.isLoading)
            }
        }
    }

    // MARK: - Sections

    private enum HealthSection: String, CaseIterable, Identifiable {
        case overview
        case trends
        case workouts
        case routes
        case sources

        var id: String { rawValue }

        var title: String {
            switch self {
            case .overview: return "Overview"
            case .trends: return "Trends"
            case .workouts: return "Workouts"
            case .routes: return "Routes"
            case .sources: return "Sources"
            }
        }
    }

    private var sectionPicker: some View {
        HStack(spacing: 4) {
            ForEach(HealthSection.allCases) { item in
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.snappy(duration: 0.2)) { section = item }
                } label: {
                    Text(item.title)
                        .font(Theme.font(10, .bold))
                        .foregroundStyle(section == item ? Theme.ink : Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if section == item {
                                Capsule().fill(Theme.coral)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
    }

    private var rangePicker: some View {
        HStack(spacing: 4) {
            ForEach(HealthRange.allCases) { item in
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.snappy(duration: 0.2)) { range = item }
                } label: {
                    Text(item.title)
                        .font(Theme.font(10, .bold))
                        .foregroundStyle(range == item ? Theme.ink : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if range == item {
                                Capsule().fill(Theme.violet)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
    }

    // MARK: - Connect

    private var connectCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.coral.opacity(0.12))
                        .frame(width: 54, height: 54)
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bring your body into view")
                        .font(Theme.font(20, .heavy))
                        .foregroundStyle(Theme.text)
                    Text("One permission sheet, then your data stays here.")
                        .font(Theme.font(11))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }

            Text("Fitr reads steps, workouts, sleep, heart rate, HRV, energy and body weight from Apple Health. Anything your Watch, ring or training app writes to Health shows up automatically.")
                .font(Theme.font(13))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)

            FlowLayout(spacing: 7, lineSpacing: 7) {
                sourcePill("Apple Watch", icon: "applewatch")
                sourcePill("Oura", icon: "circle.hexagongrid.fill")
                sourcePill("Whoop", icon: "waveform.path.ecg")
                sourcePill("Garmin", icon: "location.north.circle.fill")
                sourcePill("Strava", icon: "figure.outdoor.cycle")
                sourcePill("Nike Run Club", icon: "figure.run")
            }

            VStack(alignment: .leading, spacing: 10) {
                permissionRow("Read-only until you choose to share", icon: "eye.fill")
                permissionRow("Health data never reaches your Fitr server", icon: "lock.fill")
                permissionRow("You pick every category in the Health sheet", icon: "checklist")
            }

            Button {
                Task { await health.requestAccess() }
            } label: {
                HStack(spacing: 8) {
                    if health.isLoading {
                        ProgressView().tint(Theme.ink)
                    } else {
                        Image(systemName: "heart.fill")
                        Text("Connect Apple Health")
                    }
                }
            }
            .buttonStyle(FitrPrimaryButtonStyle(tint: Theme.coral))
            .disabled(health.isLoading)

            Button {
                openHealthApp()
            } label: {
                Label("Open Health to review permissions", systemImage: "arrow.up.right")
                    .font(Theme.font(11, .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .fitrCard(padding: 20)
    }

    private func permissionRow(_ text: String, icon: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.mint)
                .frame(width: 18)
            Text(text)
                .font(Theme.font(11, .medium))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
        }
    }

    private func sourcePill(_ name: String, icon: String) -> some View {
        FitrPill(text: name, icon: icon, tint: Theme.textSecondary)
    }

    // MARK: - Hero

    private func activityHero(_ snapshot: HealthSnapshot) -> some View {
        let move = min((snapshot.activeEnergyKcal ?? 0) / 500, 1)
        let exercise = min((snapshot.exerciseMinutes ?? 0) / 30, 1)
        let stand = min((snapshot.standHours ?? 0) / 12, 1)

        return ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.coral.opacity(0.22), Theme.surface, Theme.inkSoft],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .fill(Theme.coral.opacity(0.20))
                .frame(width: 190, height: 190)
                .blur(radius: 60)
                .offset(x: 140, y: -70)

            VStack(spacing: 18) {
                HStack(spacing: 22) {
                    ZStack {
                        ProgressRing(progress: move, lineWidth: 11, tint: Theme.coral)
                            .frame(width: 124, height: 124)
                        ProgressRing(progress: exercise, lineWidth: 9, tint: Theme.lime)
                            .frame(width: 92, height: 92)
                        ProgressRing(progress: stand, lineWidth: 7, tint: Theme.sky)
                            .frame(width: 62, height: 62)
                        VStack(spacing: 0) {
                            Text(HealthFormatting.energy(snapshot.activeEnergyKcal))
                                .font(Theme.font(20, .heavy))
                                .foregroundStyle(Theme.text)
                            Text("kcal")
                                .font(Theme.font(8, .bold))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 11) {
                        ringLegend(
                            title: "Move",
                            value: "\(HealthFormatting.energy(snapshot.activeEnergyKcal)) / 500 kcal",
                            tint: Theme.coral
                        )
                        ringLegend(
                            title: "Exercise",
                            value: "\(HealthFormatting.minutes(snapshot.exerciseMinutes)) / 30 min",
                            tint: Theme.lime
                        )
                        ringLegend(
                            title: "Stand",
                            value: "\(HealthFormatting.minutes(snapshot.standHours)) / 12 h",
                            tint: Theme.sky
                        )
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    heroStat(
                        icon: "figure.walk",
                        value: HealthFormatting.steps(snapshot.steps),
                        label: "steps",
                        tint: Theme.lime
                    )
                    heroStat(
                        icon: "moon.stars.fill",
                        value: HealthFormatting.sleep(snapshot.sleepMinutes),
                        label: "sleep",
                        tint: Theme.violet
                    )
                    heroStat(
                        icon: "heart.fill",
                        value: HealthFormatting.heartRate(snapshot.restingHeartRate),
                        label: "resting bpm",
                        tint: Theme.coral
                    )
                }
            }
            .padding(20)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    private func ringLegend(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Theme.font(11, .bold))
                    .foregroundStyle(Theme.text)
                Text(value)
                    .font(Theme.font(9))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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

    // MARK: - Metrics

    private func metricsGrid(_ snapshot: HealthSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading("Today's detail", subtitle: "From every source writing to Health")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                metric(icon: "figure.walk.motion", title: "Distance", value: HealthFormatting.distance(snapshot.distanceMeters), unit: "km", tint: Theme.sky)
                metric(icon: "figure.stairs", title: "Flights", value: snapshot.flightsClimbed.map { "\(Int($0.rounded()))" } ?? "—", unit: "floors", tint: Theme.mint)
                metric(icon: "brain.head.profile", title: "Mindful", value: HealthFormatting.minutes(snapshot.mindfulMinutes), unit: "min", tint: Theme.violet)
                metric(icon: "scalemass.fill", title: "Weight", value: HealthFormatting.weight(snapshot.weightKg), unit: "", tint: Theme.coral)
                metric(icon: "waveform.path.ecg", title: "HRV", value: HealthFormatting.hrv(snapshot.heartRateVariability), unit: "ms", tint: Theme.lime)
                metric(icon: "heart.text.square.fill", title: "Heart rate", value: HealthFormatting.heartRate(snapshot.heartRate), unit: "bpm", tint: Theme.pink)
            }
        }
    }

    private func metric(icon: String, title: String, value: String, unit: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(tint.opacity(0.12)))
                Spacer()
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(Theme.font(22, .bold))
                        .foregroundStyle(Theme.text)
                        .contentTransition(.numericText())
                    if !unit.isEmpty {
                        Text(unit)
                            .font(Theme.font(9, .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                Text(title)
                    .font(Theme.font(11, .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.surface.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
    }

    // MARK: - Chart

    private func weeklyChart(_ snapshot: HealthSnapshot) -> some View {
        let points = snapshot.weekly
        let maxSteps = max(points.map(\.steps).max() ?? 0, 1_000)
        let total = points.reduce(0) { $0 + $1.steps }
        let average = points.isEmpty ? 0 : total / Double(points.count)

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeading("Seven-day steps", subtitle: "Moving average \(Int(average.rounded())) / day")
                Spacer()
                FitrPill(text: FitrDate.number(total), icon: "figure.walk", tint: Theme.lime)
            }

            Chart(points) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Steps", point.steps)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.lime, Theme.lime.opacity(0.22)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(4)
            }
            .chartYScale(domain: 0...(maxSteps * 1.12))
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(Theme.stroke)
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text(FitrDate.number(number))
                                .font(Theme.font(8))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.weekday(.narrow)))
                                .font(Theme.font(8, .medium))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            .frame(height: 160)

            HStack(spacing: 14) {
                chartLegend(color: Theme.lime, text: "steps")
                chartLegend(color: Theme.violet, text: "\(Int(points.reduce(0) { $0 + $1.exerciseMinutes }.rounded())) exercise min")
                Spacer()
            }
        }
        .fitrCard()
    }

    private func chartLegend(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(text)
                .font(Theme.font(8))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: - Workouts

    private func workoutsSection(_ snapshot: HealthSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading("Recent workouts", subtitle: "Apple Health and every app that feeds it") {
                if !snapshot.workouts.isEmpty {
                    FitrPill(text: "\(snapshot.workouts.count)", icon: "figure.run", tint: Theme.coral)
                }
            }

            if snapshot.workouts.isEmpty {
                Text("No workouts in the last two weeks. Start a session or connect a training app that writes to Health.")
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(3)
                    .fitrCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(snapshot.workouts.enumerated()), id: \.element.id) { index, workout in
                        workoutRow(workout)
                        if index < snapshot.workouts.count - 1 {
                            Divider().overlay(Theme.stroke)
                        }
                    }
                }
                .fitrCard(padding: 4)
            }
        }
    }

    private func workoutRow(_ workout: HealthWorkout) -> some View {
        HStack(spacing: 12) {
            Image(systemName: workout.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.coral)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.coral.opacity(0.10)))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(workout.activityName)
                        .font(Theme.font(12, .semibold))
                        .foregroundStyle(Theme.text)
                    if workout.isFromFitr {
                        Text("FITR")
                            .font(Theme.font(7, .heavy))
                            .tracking(0.8)
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.lime))
                    }
                }
                Text("\(workout.sourceName) · \(HealthFormatting.relativeDay(workout.start))")
                    .font(Theme.font(9))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 3) {
                Text(FitrDate.minutes(workout.durationMinutes))
                    .font(Theme.mono(9, .bold))
                    .foregroundStyle(Theme.text)
                if let energy = workout.energyKcal {
                    Text("\(Int(energy.rounded())) kcal")
                        .font(Theme.font(8))
                        .foregroundStyle(Theme.textTertiary)
                } else if let distance = workout.distanceMeters {
                    Text("\(HealthFormatting.distance(distance)) km")
                        .font(Theme.font(8))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Sources

    private func sourcesSection(_ snapshot: HealthSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading("Connected sources", subtitle: "Apps and devices writing to Health")
            if snapshot.sources.isEmpty {
                Text("Source names appear once Apple Health shares step samples with Fitr.")
                    .font(Theme.font(11))
                    .foregroundStyle(Theme.textTertiary)
                    .lineSpacing(2)
            } else {
                FlowLayout(spacing: 7, lineSpacing: 7) {
                    ForEach(snapshot.sources) { source in
                        FitrPill(text: source.name, icon: "app.badge.checkmark", tint: Theme.mint)
                    }
                }
            }
        }
        .fitrCard()
    }

    // MARK: - Trends

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            rangePicker
            metricPicker

            if health.isLoadingAnalysis && analysis == nil {
                analysisLoading
            } else if let analysis {
                trendSummary(analysis)
                trendChart(analysis)
                workoutMix(analysis)
            } else {
                EmptyPanel(
                    icon: "chart.xyaxis.line",
                    title: "No trend data yet",
                    message: "Connect Apple Health and choose a range to build your trends.",
                    actionTitle: "Refresh"
                ) {
                    Task { await health.loadAnalysis(range: range, force: true) }
                }
            }
        }
    }

    private var metricPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(HealthMetric.allCases) { item in
                    let selected = metric == item
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.snappy(duration: 0.2)) { metric = item }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 10, weight: .semibold))
                            Text(item.shortTitle)
                                .font(Theme.font(10, .semibold))
                        }
                        .foregroundStyle(selected ? Theme.ink : Theme.textSecondary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selected ? metricTint(item) : Theme.inkSoft)
                                .overlay(
                                    Capsule().strokeBorder(selected ? .clear : Theme.stroke, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func trendSummary(_ analysis: HealthAnalysis) -> some View {
        let summary = analysis.summary(for: metric)
        let primary = summary.total
        let primaryLabel = metric.aggregation == .sum ? "total" : "average"

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 9) {
                    Image(systemName: metric.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(metricTint(metric))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(metricTint(metric).opacity(0.12)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(metric.title)
                            .font(Theme.font(15, .bold))
                            .foregroundStyle(Theme.text)
                        Text(analysis.range.subtitle)
                            .font(Theme.font(9))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                Spacer()
                if analysis.range == .day {
                    FitrPill(text: "today", icon: "sun.max.fill", tint: Theme.textSecondary)
                } else {
                    DeltaBadge(value: summary.changePct)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(metric.format(primary))
                    .font(Theme.font(36, .heavy))
                    .foregroundStyle(Theme.text)
                    .contentTransition(.numericText())
                Text(primaryLabel)
                    .font(Theme.font(11, .semibold))
                    .foregroundStyle(Theme.textTertiary)
                if metric != .sleep, metric != .weight {
                    Text(metric.unit)
                        .font(Theme.font(10, .medium))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
            }

            HStack(spacing: 9) {
                trendStat("Daily avg", value: metric.format(summary.average))
                trendStat("Best", value: metric.format(summary.best))
                trendStat("Latest", value: metric.format(summary.latest))
            }
        }
        .fitrCard()
    }

    private func trendStat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(Theme.mono(11, .bold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(Theme.font(8))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Theme.inkSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
    }

    private func trendChart(_ analysis: HealthAnalysis) -> some View {
        let points = analysis.points(for: metric)
        if points.isEmpty {
            return AnyView(
                EmptyPanel(
                    icon: metric.icon,
                    title: "No \(metric.title.lowercased()) data",
                    message: "Apple Health has nothing for this metric in the selected range."
                )
            )
        }

        let values = points.map(\.value)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let average = values.reduce(0, +) / Double(values.count)
        let lower = metricUsesZeroBaseline(metric) ? 0 : max(0, minValue * 0.9)
        let upper = max(maxValue * 1.15, lower + 1)
        let tint = metricTint(metric)

        return AnyView(
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionHeading("Daily pattern", subtitle: metric.title)
                    Spacer()
                    FitrPill(text: "avg \(metric.format(average))", icon: metric.icon, tint: tint)
                }

                Chart {
                    ForEach(points) { point in
                        if analysis.range == .day || analysis.range == .week {
                            BarMark(
                                x: .value("Day", point.date, unit: .day),
                                y: .value(metric.title, point.value),
                                width: analysis.range == .day ? .fixed(54) : .automatic
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [tint, tint.opacity(0.22)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(4)
                        } else {
                            AreaMark(
                                x: .value("Day", point.date),
                                y: .value(metric.title, point.value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [tint.opacity(0.26), tint.opacity(0.01)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)

                            LineMark(
                                x: .value("Day", point.date),
                                y: .value(metric.title, point.value)
                            )
                            .foregroundStyle(tint)
                            .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)
                        }
                    }

                    RuleMark(y: .value("Average", average))
                        .foregroundStyle(Theme.textTertiary.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .chartYScale(domain: lower...upper)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine().foregroundStyle(Theme.stroke)
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text(axisLabel(number, metric: metric))
                                    .font(Theme.font(8))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(chartDateLabel(date, range: analysis.range))
                                    .font(Theme.font(8, .medium))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
                .frame(height: 190)

                HStack(spacing: 14) {
                    chartLegend(color: tint, text: metric.title.lowercased())
                    chartLegend(color: Theme.textTertiary.opacity(0.6), text: "average")
                    Spacer()
                    Text("\(points.count) days with data")
                        .font(Theme.font(8))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .fitrCard()
        )
    }

    private func workoutMix(_ analysis: HealthAnalysis) -> some View {
        let groups = HealthWorkoutCategory.allCases.compactMap { category -> (HealthWorkoutCategory, Double)? in
            let minutes = analysis.workouts
                .filter { $0.category == category }
                .reduce(0) { $0 + $1.durationMinutes }
            return minutes > 0 ? (category, minutes) : nil
        }

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeading("Workout mix", subtitle: "Minutes by type in this range")

            if groups.isEmpty {
                Text("No workouts in this range. Your cardio, strength, yoga and mobility sessions will be grouped here.")
                    .font(Theme.font(11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(2)
            } else {
                HStack(spacing: 18) {
                    ZStack {
                        Chart(groups, id: \.0) { item in
                            SectorMark(
                                angle: .value("Minutes", item.1),
                                innerRadius: .ratio(0.62),
                                angularInset: 2
                            )
                            .foregroundStyle(categoryTint(item.0))
                            .cornerRadius(4)
                        }
                        .chartLegend(.hidden)
                        .frame(width: 132, height: 132)

                        VStack(spacing: 0) {
                            Text(FitrDate.minutes(groups.reduce(0) { $0 + $1.1 }))
                                .font(Theme.font(17, .heavy))
                                .foregroundStyle(Theme.text)
                            Text("total")
                                .font(Theme.font(8))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(groups, id: \.0) { item in
                            HStack(spacing: 7) {
                                Circle().fill(categoryTint(item.0)).frame(width: 6, height: 6)
                                Text(item.0.title)
                                    .font(Theme.font(10, .medium))
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                                Text(FitrDate.minutes(item.1))
                                    .font(Theme.mono(9, .bold))
                                    .foregroundStyle(Theme.text)
                            }
                        }
                    }
                }
            }
        }
        .fitrCard()
    }

    // MARK: - Workouts explorer

    private var workoutsExplorer: some View {
        VStack(alignment: .leading, spacing: 16) {
            rangePicker
            workoutCategoryPicker
            workoutSourceFilter

            if health.isLoadingAnalysis && analysis == nil {
                analysisLoading
            } else if let analysis {
                workoutStats(analysis)
                workoutChart(analysis)
                filteredWorkoutList(analysis)
            } else {
                EmptyPanel(
                    icon: "figure.run",
                    title: "No workouts yet",
                    message: "Apple Health workouts from every app will appear here."
                )
            }
        }
    }

    private var workoutCategoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                filterChip(
                    title: "All",
                    icon: "square.grid.2x2.fill",
                    selected: workoutCategory == nil,
                    tint: Theme.coral
                ) {
                    workoutCategory = nil
                }
                ForEach(HealthWorkoutCategory.allCases) { category in
                    filterChip(
                        title: category.title,
                        icon: category.icon,
                        selected: workoutCategory == category,
                        tint: categoryTint(category)
                    ) {
                        workoutCategory = workoutCategory == category ? nil : category
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var workoutSourceFilter: some View {
        let sources = analysis?.sources.map(\.name) ?? []
        return Menu {
            Button("All sources") { workoutSource = nil }
            if !sources.isEmpty {
                Divider()
                ForEach(sources, id: \.self) { source in
                    Button(source) { workoutSource = source }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "app.badge.checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.mint)
                Text(workoutSource ?? "All sources")
                    .font(Theme.font(11, .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.inkSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    )
            )
        }
    }

    private func filterChip(
        title: String,
        icon: String,
        selected: Bool,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.snappy(duration: 0.2)) { action() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(title)
                    .font(Theme.font(10, .semibold))
            }
            .foregroundStyle(selected ? Theme.ink : Theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(selected ? tint : Theme.inkSoft)
                    .overlay(Capsule().strokeBorder(selected ? .clear : Theme.stroke, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private func workoutStats(_ analysis: HealthAnalysis) -> some View {
        let filtered = filteredWorkouts
        let minutes = filtered.reduce(0) { $0 + $1.durationMinutes }
        let energy = filtered.reduce(0) { $0 + ($1.energyKcal ?? 0) }
        return HStack(spacing: 8) {
            workoutStat(value: "\(filtered.count)", label: "workouts", tint: Theme.coral)
            workoutStat(value: FitrDate.minutes(minutes), label: "time", tint: Theme.lime)
            workoutStat(value: "\(Int(energy.rounded()))", label: "kcal", tint: Theme.sky)
        }
    }

    private func workoutStat(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(Theme.font(17, .bold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(Theme.font(9))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.surface.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
        .overlay(alignment: .topTrailing) {
            Circle().fill(tint).frame(width: 5, height: 5).padding(9)
        }
    }

    private func workoutChart(_ analysis: HealthAnalysis) -> some View {
        let buckets = workoutBuckets(filteredWorkouts, range: analysis.range)
        let maxMinutes = max(buckets.map(\.minutes).max() ?? 0, 10)
        if buckets.isEmpty {
            return AnyView(EmptyView())
        }
        return AnyView(
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading("Workout minutes", subtitle: analysis.range.subtitle)
                Chart(buckets) { bucket in
                    BarMark(
                        x: .value("Date", bucket.date, unit: chartUnit(for: analysis.range)),
                        y: .value("Minutes", bucket.minutes),
                        width: analysis.range == .day ? .fixed(54) : .automatic
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.coral, Theme.coral.opacity(0.25)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(4)
                }
                .chartYScale(domain: 0...(maxMinutes * 1.15))
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine().foregroundStyle(Theme.stroke)
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text("\(Int(number))")
                                    .font(Theme.font(8))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(chartDateLabel(date, range: analysis.range))
                                    .font(Theme.font(8, .medium))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
                .frame(height: 150)
            }
            .fitrCard()
        )
    }

    private func filteredWorkoutList(_ analysis: HealthAnalysis) -> some View {
        let workouts = filteredWorkouts
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeading("Sessions", subtitle: "\(workouts.count) in this view") {
                if let workoutSource {
                    FitrPill(text: workoutSource, icon: "app.badge.checkmark", tint: Theme.mint)
                }
            }

            if workouts.isEmpty {
                EmptyPanel(
                    icon: "line.3.horizontal.decrease.circle",
                    title: "No matching workouts",
                    message: "Clear the type or source filter to see every session in this range."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                        workoutRow(workout)
                        if index < workouts.count - 1 {
                            Divider().overlay(Theme.stroke)
                        }
                    }
                }
                .fitrCard(padding: 4)
            }
        }
    }

    private var filteredWorkouts: [HealthWorkout] {
        guard let analysis else { return [] }
        var list = analysis.workouts
        if let workoutCategory {
            list = list.filter { $0.category == workoutCategory }
        }
        if let workoutSource {
            list = list.filter { $0.sourceName == workoutSource }
        }
        return list.sorted { $0.start > $1.start }
    }

    // MARK: - Sources explorer

    private var sourcesExplorer: some View {
        VStack(alignment: .leading, spacing: 16) {
            rangePicker

            if health.isLoadingAnalysis && analysis == nil {
                analysisLoading
            } else if let analysis {
                sourceCards(analysis)
                dataTypesCard(analysis)
                fitrAuditCard(analysis)
            } else {
                EmptyPanel(
                    icon: "app.badge.checkmark",
                    title: "No sources yet",
                    message: "Health sources appear after Apple Health shares samples with Fitr."
                )
            }
        }
    }

    private func sourceCards(_ analysis: HealthAnalysis) -> some View {
        let sourceLabel = analysis.sources.count == 1 ? "app or device" : "apps or devices"
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeading("Sources in this range", subtitle: "\(analysis.sources.count) \(sourceLabel)")
            if analysis.sources.isEmpty {
                Text("No source names are available for this range.")
                    .font(Theme.font(11))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(analysis.sources.enumerated()), id: \.element.id) { index, source in
                        let workouts = analysis.workouts(source: source.name)
                        HStack(spacing: 12) {
                            Image(systemName: "app.badge.checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.mint)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Theme.mint.opacity(0.10)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.name)
                                    .font(Theme.font(12, .semibold))
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(1)
                                Text(source.bundleIdentifier ?? "HealthKit source")
                                    .font(Theme.font(8))
                                    .foregroundStyle(Theme.textTertiary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(workouts.count) workouts")
                                    .font(Theme.mono(8, .bold))
                                    .foregroundStyle(Theme.textSecondary)
                                if let latest = workouts.map(\.start).max() {
                                    Text(HealthFormatting.relativeDay(latest))
                                        .font(Theme.font(8))
                                        .foregroundStyle(Theme.textTertiary)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        if index < analysis.sources.count - 1 {
                            Divider().overlay(Theme.stroke)
                        }
                    }
                }
                .fitrCard(padding: 4)
            }
        }
    }

    private func dataTypesCard(_ analysis: HealthAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading("What Fitr reads", subtitle: "Latest value in this range")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(HealthMetric.allCases) { item in
                    let summary = analysis.summary(for: item)
                    HStack(spacing: 8) {
                        Image(systemName: item.icon)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(metricTint(item))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(metricTint(item).opacity(0.12)))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.shortTitle)
                                .font(Theme.font(9, .semibold))
                                .foregroundStyle(Theme.textSecondary)
                            Text(item.format(summary.latest))
                                .font(Theme.mono(9, .bold))
                                .foregroundStyle(summary.latest == nil ? Theme.textTertiary : Theme.text)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(9)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.inkSoft)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Theme.stroke, lineWidth: 1)
                            )
                    )
                }
            }
        }
        .fitrCard()
    }

    private func fitrAuditCard(_ analysis: HealthAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.sky)
                Text("Fitr-authored workouts")
                    .font(Theme.font(14, .bold))
                    .foregroundStyle(Theme.text)
                Spacer()
                FitrPill(
                    text: analysis.fitrWorkoutCount == 0 ? "None in range" : "\(analysis.fitrWorkoutCount) workouts",
                    icon: analysis.fitrWorkoutCount == 0 ? "checkmark.circle.fill" : "heart.fill",
                    tint: analysis.fitrWorkoutCount == 0 ? Theme.mint : Theme.coral
                )
            }
            Text("Fitr has saved \(settings.exportedHealthSessions.count) sessions total on this iPhone. Reading Apple Health never changes it. Fitr only writes a workout when you explicitly save a completed Fitr session, and each day is saved at most once. This audit is scoped to the selected range.")
                .font(Theme.font(10))
                .foregroundStyle(Theme.textTertiary)
                .lineSpacing(2)
        }
        .fitrCard()
    }

    private var analysisLoading: some View {
        VStack(spacing: 12) {
            ProgressView().tint(Theme.violet)
            Text("Building your trends…")
                .font(Theme.font(12))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    // MARK: - Export

    private var exportCard: some View {
        let today = FitrDate.key(Date())
        let day = store.plan?.days.first { $0.date == today }
        let tasks = day?.tasks ?? []
        let completed = tasks.filter { $0.status == .done }.count
        let exported = settings.hasExportedHealthSession(today)
        let canExport = completed > 0 && !exported && health.canWriteWorkouts && !health.isExporting

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                cardHeader(icon: "arrow.up.heart.fill", title: "Train → Health", tint: Theme.mint)
                Spacer()
                if exported {
                    FitrPill(text: "Saved", icon: "checkmark.circle.fill", tint: Theme.mint)
                }
            }

            Text("Save today's completed Fitr session as a workout in Apple Health, so your rings, streaks and other training apps see the work.")
                .font(Theme.font(12))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)

            if !health.canWriteWorkouts {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.coral)
                    Text("Workout write access is off. Allow it in Health → Sharing → Apps → Fitr, then try again.")
                        .font(Theme.font(10))
                        .foregroundStyle(Theme.textTertiary)
                        .lineSpacing(2)
                }
            }

            Toggle(isOn: autoExportBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save automatically")
                        .font(Theme.font(12, .semibold))
                        .foregroundStyle(Theme.text)
                    Text("When every task on a training day is complete.")
                        .font(Theme.font(9))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .tint(Theme.mint)
            .disabled(!health.canWriteWorkouts)

            Button {
                Task { await health.exportSession(date: today, tasks: tasks) }
            } label: {
                HStack(spacing: 8) {
                    if health.isExporting {
                        ProgressView().tint(Theme.ink)
                    } else {
                        Image(systemName: exported ? "checkmark" : "heart.fill")
                        Text(exported ? "Saved to Apple Health" : "Save today's session")
                    }
                }
            }
            .buttonStyle(FitrPrimaryButtonStyle(tint: exported ? Theme.mint : Theme.coral))
            .disabled(!canExport)

            Text("The workout uses your completed minutes and a conservative energy estimate. It carries a Fitr marker so it is never saved twice.")
                .font(Theme.font(9))
                .foregroundStyle(Theme.textTertiary)
                .lineSpacing(2)
        }
        .fitrCard()
    }

    private var autoExportBinding: Binding<Bool> {
        Binding(
            get: { settings.healthAutoExport },
            set: { settings.healthAutoExport = $0 }
        )
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().tint(Theme.coral)
            Text("Reading Apple Health…")
                .font(Theme.font(12))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var unavailablePanel: some View {
        EmptyPanel(
            icon: "heart.slash.fill",
            title: "Apple Health is not available",
            message: "HealthKit needs an iPhone (or iPad) with the Health app. The rest of Fitr keeps working."
        )
    }

    private var emptyHealthState: some View {
        VStack(spacing: 14) {
            EmptyPanel(
                icon: "heart.text.square.fill",
                title: "No health data yet",
                message: "Apple Health has nothing to share for today. Open Health, wear your watch, or check that Fitr is allowed to read the categories you care about.",
                actionTitle: "Refresh"
            ) {
                Task { await health.refresh() }
            }
            Button {
                openHealthApp()
            } label: {
                Label("Open Apple Health", systemImage: "arrow.up.right")
                    .font(Theme.font(11, .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func healthErrorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.coral)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Text("Apple Health needs attention")
                    .font(Theme.font(13, .bold))
                    .foregroundStyle(Theme.text)
                Text(message)
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Button("Try again") {
                        Task { await health.refresh() }
                    }
                    .font(Theme.font(12, .bold))
                    .foregroundStyle(Theme.coral)
                    Button("Health settings") {
                        openHealthApp()
                    }
                    .font(Theme.font(12, .bold))
                    .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Button {
                health.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(6)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.coral.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.coral.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private var privacyFooter: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 10))
                .foregroundStyle(Theme.mint)
                .padding(.top, 1)
            Text("Health data is read on this iPhone and never uploaded to your Fitr server. You can revoke every category at any time in Health.")
                .font(Theme.font(9))
                .foregroundStyle(Theme.textTertiary)
                .lineSpacing(2)
        }
        .padding(.top, 2)
    }

    // MARK: - Helpers

    private func cardHeader(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(Theme.font(15, .bold))
                .foregroundStyle(Theme.text)
        }
    }

    private func openHealthApp() {
        guard let url = URL(string: "x-apple-health://") else { return }
        openURL(url)
    }

    // MARK: - Chart helpers

    private struct WorkoutBucket: Identifiable {
        var id: Date { date }
        let date: Date
        let minutes: Double
    }

    private func metricTint(_ metric: HealthMetric) -> Color {
        switch metric {
        case .steps, .stand: return Theme.lime
        case .activeEnergy, .restingHeartRate, .weight: return Theme.coral
        case .exercise, .heartRate: return Theme.pink
        case .distance: return Theme.sky
        case .sleep, .mindful: return Theme.violet
        case .hrv: return Theme.mint
        }
    }

    private func categoryTint(_ category: HealthWorkoutCategory) -> Color {
        switch category {
        case .strength: return Theme.lime
        case .cardio: return Theme.pink
        case .yoga: return Theme.violet
        case .mobility: return Theme.mint
        case .recovery: return Theme.sky
        case .other: return Theme.coral
        }
    }

    private func metricUsesZeroBaseline(_ metric: HealthMetric) -> Bool {
        switch metric {
        case .steps, .activeEnergy, .exercise, .distance, .sleep, .mindful, .stand:
            return true
        case .restingHeartRate, .heartRate, .hrv, .weight:
            return false
        }
    }

    private func axisLabel(_ value: Double, metric: HealthMetric) -> String {
        switch metric {
        case .steps:
            return FitrDate.number(value)
        case .distance:
            return String(format: "%.1f", value / 1000)
        case .sleep:
            return String(format: "%.1f", value / 60)
        case .weight:
            return String(format: "%.0f", value)
        case .activeEnergy, .exercise, .restingHeartRate, .heartRate, .hrv, .mindful, .stand:
            return "\(Int(value.rounded()))"
        }
    }

    private func chartDateLabel(_ date: Date, range: HealthRange) -> String {
        switch range {
        case .day:
            return "Today"
        case .week:
            return date.formatted(.dateTime.weekday(.abbreviated))
        case .month:
            return date.formatted(.dateTime.day())
        case .quarter:
            return date.formatted(.dateTime.month(.abbreviated).day())
        case .year:
            return date.formatted(.dateTime.month(.abbreviated))
        }
    }

    private func chartUnit(for range: HealthRange) -> Calendar.Component {
        switch range {
        case .day, .week, .month: return .day
        case .quarter: return .weekOfYear
        case .year: return .month
        }
    }

    private func workoutBuckets(_ workouts: [HealthWorkout], range: HealthRange) -> [WorkoutBucket] {
        let component = chartUnit(for: range)
        var buckets: [Date: Double] = [:]
        for workout in workouts {
            let start = FitrDate.calendar.dateInterval(of: component, for: workout.start)?.start ?? workout.start
            buckets[start, default: 0] += workout.durationMinutes
        }
        return buckets
            .map { WorkoutBucket(date: $0.key, minutes: $0.value) }
            .sorted { $0.date < $1.date }
    }
}
