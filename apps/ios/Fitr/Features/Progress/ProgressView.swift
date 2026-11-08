import SwiftUI
import Charts

struct TrainingProgressView: View {
    @Environment(AppStore.self) private var store
    @State private var hasLoaded = false

    private var summary: ProgressSummary? { store.progress }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let message = store.progressError, summary == nil {
                    ErrorBanner(message: message) {
                        Task { await store.loadProgress(period: store.progressPeriod, anchor: store.progressAnchor, force: true) }
                    }
                }
                periodPicker
                rangeNavigator

                if store.isLoadingProgress && summary == nil {
                    loading
                } else if let summary {
                    if summary.totals.scheduled == 0 && summary.totals.completed == 0 {
                        EmptyPanel(
                            icon: "chart.bar.xaxis",
                            title: "No history yet",
                            message: "Complete a task and your trend starts here. Day, week, month and year views all stay in sync."
                        )
                    } else {
                        hero(summary)
                        metrics(summary)
                        trendChart(summary)
                        if store.progressPeriod == .month {
                            monthCalendar(summary)
                        }
                        improvementSection(summary)
                        muscleSection(summary)
                        streakCard(summary)
                    }
                } else {
                    loading
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await store.loadProgress(period: store.progressPeriod, anchor: store.progressAnchor, force: true)
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            await store.loadProgress(period: store.progressPeriod, anchor: store.progressAnchor)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("PROOF OF WORK")
                    .font(Theme.font(10, .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.violet)
                Text("Progress")
                    .font(Theme.font(34, .heavy))
                    .foregroundStyle(Theme.text)
                Text("Consistency now, capacity later.")
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if let plan = store.plan {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("W\(String(format: "%02d", plan.weekIndex))")
                        .font(Theme.mono(16, .bold))
                        .foregroundStyle(Theme.lime)
                    Text("+\(Int(((plan.volumeMultiplier - 1) * 100).rounded()))% vol")
                        .font(Theme.font(9, .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.lime.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Theme.lime.opacity(0.16), lineWidth: 1)
                        )
                )
            }
        }
    }

    private var periodPicker: some View {
        HStack(spacing: 4) {
            ForEach(TrainingPeriod.allCases) { period in
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    Task { await store.loadProgress(period: period, anchor: store.progressAnchor) }
                } label: {
                    Text(period.title)
                        .font(Theme.font(11, .bold))
                        .foregroundStyle(store.progressPeriod == period ? Theme.ink : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if store.progressPeriod == period {
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

    private var rangeNavigator: some View {
        HStack {
            Button {
                Task { await store.shiftProgress(by: -1) }
            } label: {
                navButton("chevron.left")
            }
            .buttonStyle(.plain)

            Spacer()
            VStack(spacing: 2) {
                Text(rangeLabel.uppercased())
                    .font(Theme.font(10, .bold))
                    .tracking(1.3)
                    .foregroundStyle(Theme.text)
                Text(vsLabel)
                    .font(Theme.font(9))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()

            if !FitrDate.isSameDay(store.progressAnchor, Date()) {
                Button("Now") {
                    Task { await store.loadProgress(period: store.progressPeriod, anchor: Date()) }
                }
                .font(Theme.font(10, .bold))
                .foregroundStyle(Theme.violet)
            }

            Button {
                Task { await store.shiftProgress(by: 1) }
            } label: {
                navButton("chevron.right")
            }
            .buttonStyle(.plain)
        }
    }

    private func navButton(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Theme.textSecondary)
            .frame(width: 30, height: 30)
            .background(Circle().fill(Theme.surface))
            .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
    }

    // MARK: - Hero

    private func hero(_ summary: ProgressSummary) -> some View {
        let adherence = Double(summary.totals.adherence) / 100
        return ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.violet.opacity(0.24), Theme.surface, Theme.inkSoft],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .fill(Theme.violet.opacity(0.2))
                .frame(width: 190, height: 190)
                .blur(radius: 60)
                .offset(x: 140, y: -60)

            HStack(spacing: 20) {
                ZStack {
                    ProgressRing(progress: adherence, lineWidth: 10, tint: Theme.violet)
                        .frame(width: 108, height: 108)
                    VStack(spacing: 0) {
                        Text("\(summary.totals.adherence)%")
                            .font(Theme.font(26, .heavy))
                            .foregroundStyle(Theme.text)
                        Text("consistent")
                            .font(Theme.font(8, .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(summary.totals.completed) tasks completed")
                        .font(Theme.font(20, .heavy))
                        .foregroundStyle(Theme.text)
                    Text("\(FitrDate.minutes(summary.totals.minutes)) of quality movement")
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.textSecondary)
                    HStack(spacing: 8) {
                        DeltaBadge(value: summary.deltas.minutesPct)
                        Text("vs previous")
                            .font(Theme.font(9))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.coral)
                        Text("\(summary.streak.current) day streak · best \(summary.streak.best)")
                            .font(Theme.font(9, .medium))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    private func metrics(_ summary: ProgressSummary) -> some View {
        HStack(spacing: 10) {
            MetricTile(
                value: "\(summary.totals.completed)/\(summary.totals.scheduled)",
                label: "tasks done",
                icon: "checkmark.circle.fill",
                tint: Theme.lime,
                delta: summary.deltas.completedPct
            )
            MetricTile(
                value: FitrDate.number(summary.totals.volumeKg),
                label: "kg volume",
                icon: "scalemass.fill",
                tint: Theme.coral,
                delta: summary.deltas.volumePct
            )
            MetricTile(
                value: "\(summary.totals.sessions)",
                label: "active days",
                icon: "figure.walk",
                tint: Theme.sky,
                delta: summary.deltas.sessionsPct
            )
        }
    }

    // MARK: - Chart

    private struct ChartPoint: Identifiable {
        let id: String
        let label: String
        let value: Double
        let completed: Int
        let scheduled: Int
    }

    private func chartPoints(_ summary: ProgressSummary) -> [ChartPoint] {
        if store.progressPeriod == .year {
            var buckets: [String: (label: String, minutes: Double, completed: Int, scheduled: Int)] = [:]
            for day in summary.days {
                let monthKey = String(day.date.prefix(7))
                let monthLabel = FitrDate.date(day.date).formatted(.dateTime.month(.abbreviated))
                var bucket = buckets[monthKey] ?? (monthLabel, 0, 0, 0)
                bucket.minutes += day.minutes
                bucket.completed += day.completed
                bucket.scheduled += day.scheduled
                buckets[monthKey] = bucket
            }
            return buckets.keys.sorted().compactMap { key in
                guard let bucket = buckets[key] else { return nil }
                return ChartPoint(id: key, label: bucket.label, value: bucket.minutes, completed: bucket.completed, scheduled: bucket.scheduled)
            }
        }

        return summary.days.map { day in
            let label: String
            switch store.progressPeriod {
            case .day:
                label = "Today"
            case .week:
                label = FitrDate.weekday(FitrDate.date(day.date))
            default:
                label = String(FitrDate.calendar.component(.day, from: FitrDate.date(day.date)))
            }
            return ChartPoint(
                id: day.date,
                label: label,
                value: day.minutes,
                completed: day.completed,
                scheduled: day.scheduled
            )
        }
    }

    private func trendChart(_ summary: ProgressSummary) -> some View {
        let points = chartPoints(summary)
        let maxValue = max(points.map(\.value).max() ?? 1, 20)
        let showEvery = store.progressPeriod == .month ? 5 : 1

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeading("Training load", subtitle: store.progressPeriod == .year ? "Monthly minutes" : "Minutes per day")
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(Theme.violet).frame(width: 6, height: 6)
                    Text("minutes")
                        .font(Theme.font(9))
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            Chart(points) { point in
                BarMark(
                    x: .value("Period", point.label),
                    y: .value("Minutes", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.violet, Theme.violet.opacity(0.25)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(4)
                if point.scheduled > 0 {
                    RuleMark(
                        x: .value("Period", point.label),
                        yStart: .value("Base", 0),
                        yEnd: .value("Target", 0)
                    )
                    .opacity(0)
                }
            }
            .chartYScale(domain: 0...maxValue)
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
                AxisMarks(values: .automatic(desiredCount: store.progressPeriod == .month ? 6 : 12)) { value in
                    AxisValueLabel {
                        if let label = value.as(String.self),
                           let index = points.firstIndex(where: { $0.label == label }),
                           index % showEvery == 0 {
                            Text(label)
                                .font(Theme.font(8, .medium))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            .frame(height: 170)

            HStack(spacing: 14) {
                chartLegendDot(color: Theme.violet, text: "completed minutes")
                chartLegendDot(color: Theme.textTertiary.opacity(0.5), text: "\(summary.totals.scheduled) scheduled")
                Spacer()
            }
        }
        .fitrCard()
    }

    private func chartLegendDot(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(text)
                .font(Theme.font(8))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: - Calendar

    private func monthCalendar(_ summary: ProgressSummary) -> some View {
        MonthHeatmap(anchor: store.progressAnchor, days: summary.days) { date in
            Task { await store.loadProgress(period: .day, anchor: date) }
        }
        .fitrCard()
    }

    // MARK: - Improvements

    private func improvementSection(_ summary: ProgressSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading("Proof of progress", subtitle: "Best effort vs the period before") {
                if !summary.improvements.isEmpty {
                    FitrPill(text: "\(summary.improvements.count) tracked", icon: "arrow.up.right", tint: Theme.lime)
                }
            }

            if summary.improvements.isEmpty && summary.prs.isEmpty {
                Text("Finish a few sessions in this period and your strength, rep and hold records will appear here.")
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(3)
                    .fitrCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(summary.improvements.prefix(5).enumerated()), id: \.element.id) { index, item in
                        ImprovementRow(item: item)
                        if index < min(summary.improvements.count, 5) - 1 {
                            Divider().overlay(Theme.stroke)
                        }
                    }
                }
                .fitrCard(padding: 4)

                if !summary.prs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.lime)
                            Text("Personal bests this period")
                                .font(Theme.font(12, .bold))
                                .foregroundStyle(Theme.text)
                            Spacer()
                        }
                        ForEach(summary.prs.prefix(4)) { record in
                            HStack(spacing: 10) {
                                Text(record.name)
                                    .font(Theme.font(11))
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(FitrDate.number(record.value)) \(record.unit)")
                                    .font(Theme.mono(10, .bold))
                                    .foregroundStyle(Theme.text)
                                if record.deltaPct != nil {
                                    DeltaBadge(value: record.deltaPct, compact: true)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Theme.lime.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Theme.lime.opacity(0.12), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    // MARK: - Muscles

    private func muscleSection(_ summary: ProgressSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading("Muscle balance", subtitle: "Share of primary work")
            if summary.muscles.isEmpty {
                EmptyPanel(icon: "figure.stand", title: "No muscle data yet", message: "Log a strength or mobility session to see your balance.")
            } else {
                VStack(spacing: 11) {
                    ForEach(summary.muscles.prefix(7)) { muscle in
                        HStack(spacing: 12) {
                            Text(muscle.name)
                                .font(Theme.font(12, .medium))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 92, alignment: .leading)
                                .lineLimit(1)
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.05))
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Theme.violet, Theme.lime],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(6, geometry.size.width * min(muscle.share / 40, 1)))
                                }
                            }
                            .frame(height: 8)
                            Text("\(Int(muscle.share.rounded()))%")
                                .font(Theme.mono(9, .semibold))
                                .foregroundStyle(Theme.textTertiary)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
                .fitrCard()
            }
        }
    }

    private func streakCard(_ summary: ProgressSummary) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.coral.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "flame.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.coral)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(summary.streak.current) days in a row")
                    .font(Theme.font(17, .bold))
                    .foregroundStyle(Theme.text)
                Text("Best streak: \(summary.streak.best) days. Show up, even briefly.")
                    .font(Theme.font(11))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .fitrCard()
    }

    // MARK: - Helpers

    private var loading: some View {
        VStack(spacing: 12) {
            ProgressView().tint(Theme.violet)
            Text("Reading your history…")
                .font(Theme.font(12))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var rangeLabel: String {
        guard let summary else {
            return store.progressPeriod.title
        }
        let start = FitrDate.date(summary.range.start)
        let end = FitrDate.date(summary.range.end)
        switch store.progressPeriod {
        case .day:
            return FitrDate.fullDate(start)
        case .week:
            return "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
        case .month:
            return FitrDate.monthYear(start)
        case .year:
            return start.formatted(.dateTime.year())
        }
    }

    private var vsLabel: String {
        guard let summary else { return "" }
        let start = FitrDate.date(summary.previousRange.start)
        let end = FitrDate.date(summary.previousRange.end)
        switch store.progressPeriod {
        case .day:
            return "vs \(FitrDate.shortDate(summary.previousRange.start))"
        case .week, .month:
            return "vs \(FitrDate.shortDate(summary.previousRange.start)) – \(FitrDate.shortDate(summary.previousRange.end))"
        case .year:
            return "vs \(start.formatted(.dateTime.year())) – \(end.formatted(.dateTime.year()))"
        }
    }
}

struct ImprovementRow: View {
    let item: ExerciseImprovement

    private var tint: Color {
        switch item.kind {
        case "load": return Theme.coral
        case "hold": return Theme.violet
        default: return Theme.sky
        }
    }

    private var icon: String {
        switch item.kind {
        case "load": return "scalemass.fill"
        case "hold": return "timer"
        default: return "repeat"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(Circle().fill(tint.opacity(0.1)))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(Theme.font(12, .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text("\(FitrDate.number(item.current)) \(item.unit)")
                    .font(Theme.font(9))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            DeltaBadge(value: item.deltaPct)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct MonthHeatmap: View {
    let anchor: Date
    let days: [ProgressDay]
    let onSelect: (Date) -> Void

    private let calendar = FitrDate.calendar

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: anchor)) ?? anchor
    }

    private var dayCount: Int {
        calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    }

    private var leadingBlanks: Int {
        let weekday = calendar.component(.weekday, from: monthStart) // Sunday = 1
        return (weekday + 5) % 7
    }

    private var lookup: [String: ProgressDay] {
        Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeading("Calendar", subtitle: FitrDate.monthYear(anchor))
                Spacer()
                HStack(spacing: 8) {
                    legend(color: Theme.lime, label: "done")
                    legend(color: Theme.coral.opacity(0.6), label: "partial")
                    legend(color: Color.white.opacity(0.08), label: "rest")
                }
            }

            HStack(spacing: 0) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { symbol in
                    Text(symbol)
                        .font(Theme.font(8, .bold))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 34)
                }
                ForEach(1...dayCount, id: \.self) { day in
                    cell(day: day)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 9))
                Text("Tap a day to open its detail")
                    .font(Theme.font(9))
                Spacer()
            }
            .foregroundStyle(Theme.textTertiary)
        }
    }

    private func cell(day: Int) -> some View {
        let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart
        let key = FitrDate.key(date)
        let record = lookup[key]
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > Date()

        let fill: Color
        if isFuture {
            fill = Color.white.opacity(0.02)
        } else if let record, record.status == .done {
            fill = Theme.lime.opacity(0.25 + min(Double(record.completed) * 0.08, 0.55))
        } else if let record, record.status == .partial {
            fill = Theme.coral.opacity(0.18)
        } else if let record, record.status == .missed {
            fill = Theme.coral.opacity(0.07)
        } else {
            fill = Color.white.opacity(0.04)
        }

        return Button {
            guard !isFuture else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            onSelect(date)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(isToday ? Theme.lime : Theme.stroke, lineWidth: isToday ? 1.2 : 0.5)
                    )
                Text("\(day)")
                    .font(Theme.font(10, .semibold))
                    .foregroundStyle(isToday ? Theme.lime : Theme.textSecondary)
            }
            .frame(height: 34)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(Theme.font(8))
                .foregroundStyle(Theme.textTertiary)
        }
    }
}
