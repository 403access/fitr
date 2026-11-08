import Charts
import SwiftUI

struct HealthView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    private var health: HealthStore { store.health }
    private var snapshot: HealthSnapshot? { health.snapshot }

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
                } else if health.isLoading && snapshot == nil {
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

                privacyFooter
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await health.refreshIfConnected()
        }
        .task {
            await health.refreshIfConnected()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await health.refreshIfConnected() }
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
}
