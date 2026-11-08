import SwiftUI

struct ExercisePlayerView: View {
    let task: TrainingTask
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    @State private var actualReps: Int
    @State private var actualLoad: Double
    @State private var actualHold: Int
    @State private var effort = 7
    @State private var completedSets = 0
    @State private var timerRunning = false
    @State private var remainingHold: Int
    @State private var isSubmitting = false

    init(task: TrainingTask) {
        self.task = task
        _actualReps = State(initialValue: task.actualReps ?? task.reps ?? 0)
        _actualLoad = State(initialValue: task.actualLoadKg ?? task.loadKg ?? 0)
        _actualHold = State(initialValue: task.actualHoldSeconds ?? task.holdSeconds ?? 0)
        _remainingHold = State(initialValue: task.holdSeconds ?? 0)
        _effort = State(initialValue: task.effort ?? 7)
        _completedSets = State(initialValue: task.status == .done ? task.sets : 0)
    }

    private var accent: Color { Theme.color(hex: task.exercise.topic.accent) }
    private var isTimed: Bool { task.holdSeconds != nil }
    private var isWeighted: Bool { task.loadKg != nil }
    private var isLongForm: Bool { (task.holdSeconds ?? 0) > 240 }

    var body: some View {
        ZStack {
            FitrBackground(accent: accent)
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    prescription
                    if isTimed, !isLongForm { timerCard }
                    if isTimed, isLongForm { durationCard }
                    if isWeighted { loadCard }
                    if !isTimed || isWeighted { repsCard }
                    setsCard
                    effortCard
                    if !task.exercise.cues.isEmpty { cuesCard }
                    instructionsCard
                    musclesCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            completeBar
        }
        .task(id: timerRunning) {
            guard timerRunning else { return }
            while timerRunning && remainingHold > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                if timerRunning && remainingHold > 0 { remainingHold -= 1 }
            }
            if remainingHold == 0 && timerRunning {
                timerRunning = false
                completedSets = min(task.sets, completedSets + 1)
                actualHold = task.holdSeconds ?? actualHold
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.28), Theme.surface, Theme.inkSoft],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
            AnimatedExerciseFigure(animation: task.exercise.animation, accent: accent)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 118)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        FitrPill(text: task.exercise.topic.name, icon: task.exercise.topic.icon, tint: accent)
                        if task.exercise.type.name != task.exercise.topic.name {
                            FitrPill(text: task.exercise.type.name, tint: Theme.textSecondary)
                        }
                    }
                    Text(task.exercise.name)
                        .font(Theme.font(28, .heavy))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                    Text(task.exercise.summary)
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                        .padding(.trailing, 40)
                }
                Spacer()
            }
            .padding(20)

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.text)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.black.opacity(0.28)))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(14)
        }
        .frame(height: 360)
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    // MARK: - Cards

    private var prescription: some View {
        HStack(spacing: 8) {
            rxTile(icon: "square.stack.3d.up.fill", value: "\(task.sets)", label: "sets", tint: accent)
            if let reps = task.reps {
                rxTile(icon: "repeat", value: "\(reps)", label: "reps", tint: Theme.sky)
            }
            if let hold = task.holdSeconds {
                rxTile(icon: "timer", value: hold >= 60 ? "\(hold / 60)m" : "\(hold)s", label: "hold", tint: Theme.violet)
            }
            if let load = task.loadKg {
                rxTile(icon: "scalemass.fill", value: FitrDate.weight(load), label: "load", tint: Theme.coral)
            }
            rxTile(icon: "pause.fill", value: "\(task.restSeconds)s", label: "rest", tint: Theme.textSecondary)
        }
    }

    private func rxTile(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(Theme.font(14, .bold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(Theme.font(9))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
    }

    private var timerCard: some View {
        HStack(spacing: 20) {
            ZStack {
                ProgressRing(
                    progress: task.holdSeconds.map { $0 == 0 ? 0 : 1 - Double(remainingHold) / Double($0) } ?? 0,
                    lineWidth: 8,
                    tint: accent
                )
                .frame(width: 110, height: 110)
                VStack(spacing: 0) {
                    Text(timeString(remainingHold))
                        .font(Theme.mono(23, .bold))
                        .foregroundStyle(Theme.text)
                        .monospacedDigit()
                    Text("remaining")
                        .font(Theme.font(9))
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Hold the shape")
                    .font(Theme.font(17, .bold))
                    .foregroundStyle(Theme.text)
                Text("Breathe slowly. Tap the ring when you begin — it counts you down and logs the set.")
                    .font(Theme.font(11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(2)
                HStack(spacing: 8) {
                    Button {
                        if remainingHold == 0 { remainingHold = task.holdSeconds ?? 0 }
                        timerRunning.toggle()
                    } label: {
                        Label(timerRunning ? "Pause" : "Start", systemImage: timerRunning ? "pause.fill" : "play.fill")
                            .font(Theme.font(12, .bold))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(accent))
                    }
                    .buttonStyle(.plain)

                    Button {
                        timerRunning = false
                        remainingHold = task.holdSeconds ?? 0
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Theme.surfaceRaised))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .fitrCard()
    }

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundStyle(accent)
                Text("Session duration")
                    .font(Theme.font(16, .bold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("\(actualHold / 60) min")
                    .font(Theme.mono(16, .bold))
                    .foregroundStyle(accent)
            }
            Stepper("Minutes completed", value: $actualHold, in: 0...7200, step: 60)
                .font(Theme.font(12))
                .foregroundStyle(Theme.textSecondary)
                .tint(accent)
            Text("Log the time you actually moved. The plan uses it for your volume trend.")
                .font(Theme.font(10))
                .foregroundStyle(Theme.textTertiary)
        }
        .fitrCard()
    }

    private var loadCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle(icon: "scalemass.fill", title: "Load", tint: Theme.coral)
            HStack {
                Text(FitrDate.weight(actualLoad))
                    .font(Theme.font(28, .heavy))
                    .foregroundStyle(Theme.text)
                Spacer()
                stepperButton(system: "minus") {
                    actualLoad = max(0, actualLoad - 2.5)
                }
                stepperButton(system: "plus") {
                    actualLoad += 2.5
                }
            }
            Text("Target: \(task.targetNote)")
                .font(Theme.font(11))
                .foregroundStyle(Theme.textTertiary)
        }
        .fitrCard()
    }

    private var repsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle(icon: "repeat", title: "Reps completed", tint: Theme.sky)
            HStack {
                Text("\(actualReps)")
                    .font(Theme.font(28, .heavy))
                    .foregroundStyle(Theme.text)
                Text("reps")
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                stepperButton(system: "minus") {
                    actualReps = max(0, actualReps - 1)
                }
                stepperButton(system: "plus") {
                    actualReps += 1
                }
            }
        }
        .fitrCard()
    }

    private var setsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                cardTitle(icon: "square.stack.3d.up.fill", title: "Sets", tint: accent)
                Spacer()
                Text("\(completedSets) of \(task.sets)")
                    .font(Theme.mono(11, .bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 10) {
                ForEach(0..<task.sets, id: \.self) { index in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        completedSets = completedSets == index + 1 ? index : index + 1
                    } label: {
                        ZStack {
                            Circle()
                                .fill(index < completedSets ? accent : Theme.surfaceRaised)
                                .frame(width: 42, height: 42)
                                .overlay(
                                    Circle().strokeBorder(
                                        index < completedSets ? .clear : Theme.strokeStrong,
                                        lineWidth: 1
                                    )
                                )
                            Text("\(index + 1)")
                                .font(Theme.font(13, .bold))
                                .foregroundStyle(index < completedSets ? Theme.ink : Theme.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            Text("Tap each set as you finish it. Completion is optional — effort is what makes the plan adapt.")
                .font(Theme.font(10))
                .foregroundStyle(Theme.textTertiary)
                .lineSpacing(2)
        }
        .fitrCard()
    }

    private var effortCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                cardTitle(icon: "gauge.with.dots.needle.67percent", title: "Effort", tint: Theme.violet)
                Spacer()
                Text(effortLabel)
                    .font(Theme.font(11, .bold))
                    .foregroundStyle(effortColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(effortColor.opacity(0.12)))
            }
            HStack(spacing: 5) {
                ForEach(1...10, id: \.self) { value in
                    Button {
                        effort = value
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(value <= effort ? effortColor.opacity(0.35 + Double(value) * 0.06) : Color.white.opacity(0.07))
                            .frame(maxWidth: .infinity)
                            .frame(height: value == effort ? 30 : 22)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("How hard did that feel? 1 is a walk, 10 is all-out. Under 7 lets the next week push a little harder.")
                .font(Theme.font(10))
                .foregroundStyle(Theme.textTertiary)
                .lineSpacing(2)
        }
        .fitrCard()
    }

    private var cuesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle(icon: "target", title: "Keys to the shape", tint: Theme.mint)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(task.exercise.cues, id: \.self) { cue in
                    FitrPill(text: cue, tint: Theme.mint)
                }
            }
        }
        .fitrCard()
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle(icon: "list.number", title: "How to do it", tint: Theme.textSecondary)
            VStack(spacing: 12) {
                ForEach(Array(task.exercise.instructions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(Theme.mono(11, .bold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(accent))
                        Text(step)
                            .font(Theme.font(12))
                            .foregroundStyle(Theme.textSecondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if !task.exercise.breathing.isEmpty {
                Divider().overlay(Theme.stroke)
                HStack(spacing: 8) {
                    Image(systemName: "wind")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.sky)
                    Text(task.exercise.breathing)
                        .font(Theme.font(11))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .fitrCard()
    }

    private var musclesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle(icon: "figure.stand", title: "Muscles", tint: Theme.coral)
            if !task.exercise.primaryMuscles.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PRIMARY")
                        .font(Theme.font(9, .bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.textTertiary)
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(task.exercise.primaryMuscles) { muscle in
                            FitrPill(text: muscle.name, tint: Theme.coral)
                        }
                    }
                }
            }
            if !task.exercise.secondaryMuscles.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SUPPORTING")
                        .font(Theme.font(9, .bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.textTertiary)
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(task.exercise.secondaryMuscles) { muscle in
                            FitrPill(text: muscle.name, tint: Theme.textSecondary)
                        }
                    }
                }
            }
            if !task.exercise.equipment.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.textTertiary)
                    Text(task.exercise.equipment.joined(separator: " · "))
                        .font(Theme.font(10))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .fitrCard()
    }

    // MARK: - Bottom bar

    private var completeBar: some View {
        HStack(spacing: 10) {
            Button {
                Task {
                    await store.skip(task)
                    dismiss()
                }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(Theme.surfaceRaised)
                            .overlay(
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .strokeBorder(Theme.stroke, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip exercise")

            Button {
                submit()
            } label: {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView().tint(Theme.ink)
                    } else {
                        Text(task.status == .done ? "Update log" : "Complete exercise")
                        Image(systemName: "checkmark")
                    }
                }
            }
            .buttonStyle(FitrPrimaryButtonStyle(tint: accent))
            .disabled(isSubmitting)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.stroke).frame(height: 1)
        }
    }

    // MARK: - Helpers

    private func submit() {
        isSubmitting = true
        Task {
            let success = await store.complete(
                task,
                actualReps: isTimed ? nil : actualReps,
                actualHoldSeconds: isTimed ? actualHold : nil,
                actualLoadKg: isWeighted ? actualLoad : nil,
                effort: effort
            )
            isSubmitting = false
            if success { dismiss() }
        }
    }

    private func cardTitle(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(Theme.font(15, .bold))
                .foregroundStyle(Theme.text)
        }
    }

    private func stepperButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.text)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Theme.surfaceRaised))
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func timeString(_ seconds: Int) -> String {
        let value = max(0, seconds)
        return String(format: "%d:%02d", value / 60, value % 60)
    }

    private var effortLabel: String {
        switch effort {
        case 1...3: return "Easy"
        case 4...6: return "Moderate"
        case 7...8: return "Hard"
        default: return "All-out"
        }
    }

    private var effortColor: Color {
        switch effort {
        case 1...3: return Theme.mint
        case 4...6: return Theme.lime
        case 7...8: return Theme.coral
        default: return Theme.pink
        }
    }
}
