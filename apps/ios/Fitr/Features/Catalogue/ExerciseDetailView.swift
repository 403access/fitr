import SwiftUI

struct ExerciseDetailView: View {
    let exercise: Exercise
    @Environment(\.dismiss) private var dismiss

    private var accent: Color { Theme.color(hex: exercise.topic.accent) }

    var body: some View {
        ZStack {
            FitrBackground(accent: accent)
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    stats
                    instructions
                    cues
                    benefits
                    muscles
                    details
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.32), Theme.surface, Theme.inkSoft],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )

            AnimatedExerciseFigure(animation: exercise.animation, accent: accent)
                .padding(.horizontal, 24)
                .padding(.bottom, 80)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    FitrPill(text: exercise.topic.name, icon: exercise.topic.icon, tint: accent)
                    if exercise.type.name != exercise.topic.name {
                        FitrPill(text: exercise.type.name, tint: Theme.textSecondary)
                    }
                }
                Text(exercise.name)
                    .font(Theme.font(30, .heavy))
                    .foregroundStyle(Theme.text)
                Text(exercise.summary)
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(2)
                    .lineLimit(3)
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
                            .background(Circle().fill(Color.black.opacity(0.3)))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(14)
        }
        .frame(height: 430)
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    private var stats: some View {
        HStack(spacing: 8) {
            statTile(value: "\(exercise.prescription.sets)", label: "sets", tint: accent)
            if let reps = exercise.prescription.reps {
                statTile(value: "\(reps)", label: "reps", tint: Theme.sky)
            }
            if let hold = exercise.prescription.holdSeconds {
                statTile(value: hold >= 60 ? "\(hold / 60)m" : "\(hold)s", label: "hold", tint: Theme.violet)
            }
            if let load = exercise.prescription.loadKg {
                statTile(value: FitrDate.weight(load), label: "base load", tint: Theme.coral)
            }
            VStack(spacing: 5) {
                HStack(spacing: 3) {
                    ForEach(1...5, id: \.self) { level in
                        Circle()
                            .fill(level <= exercise.difficulty ? accent : Color.white.opacity(0.1))
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 14)
                Text("level \(exercise.difficulty)")
                    .font(Theme.font(9))
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    )
            )
        }
    }

    private func statTile(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(Theme.font(15, .bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(Theme.font(9))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
    }

    private var instructions: some View {
        detailCard(icon: "list.number", title: "How to do it", tint: Theme.textSecondary) {
            VStack(spacing: 13) {
                ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(Theme.mono(11, .bold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 25, height: 25)
                            .background(Circle().fill(accent))
                        Text(step)
                            .font(Theme.font(12))
                            .foregroundStyle(Theme.textSecondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var cues: some View {
        detailCard(icon: "target", title: "Keys to the shape", tint: Theme.mint) {
            FlowLayout(spacing: 7, lineSpacing: 7) {
                ForEach(exercise.cues, id: \.self) { cue in
                    FitrPill(text: cue, tint: Theme.mint)
                }
            }
        }
    }

    private var benefits: some View {
        detailCard(icon: "chart.line.uptrend.xyaxis", title: "Why it works", tint: Theme.lime) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(exercise.benefits, id: \.self) { benefit in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.lime.opacity(0.8))
                            .padding(.top, 1)
                        Text(benefit)
                            .font(Theme.font(12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
    }

    private var muscles: some View {
        detailCard(icon: "figure.stand", title: "Muscles & regions", tint: Theme.coral) {
            VStack(alignment: .leading, spacing: 14) {
                if !exercise.primaryMuscles.isEmpty {
                    muscleGroup(title: "PRIMARY", muscles: exercise.primaryMuscles, tint: Theme.coral)
                }
                if !exercise.secondaryMuscles.isEmpty {
                    muscleGroup(title: "AUXILIARY", muscles: exercise.secondaryMuscles, tint: Theme.textSecondary)
                }
                if !exercise.regions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("BODY REGIONS")
                            .font(Theme.font(9, .bold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.textTertiary)
                        FlowLayout(spacing: 6, lineSpacing: 6) {
                            ForEach(exercise.regions) { region in
                                FitrPill(text: region.name, tint: Theme.mint)
                            }
                        }
                    }
                }
            }
        }
    }

    private func muscleGroup(title: String, muscles: [NamedRef], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.font(9, .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textTertiary)
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(muscles) { muscle in
                    FitrPill(text: muscle.name, tint: tint)
                }
            }
        }
    }

    private var details: some View {
        detailCard(icon: "info.circle", title: "Details", tint: Theme.textSecondary) {
            VStack(spacing: 10) {
                detailRow(label: "Equipment", value: exercise.equipment.isEmpty ? "Bodyweight only" : exercise.equipment.joined(separator: ", "))
                Divider().overlay(Theme.stroke)
                detailRow(label: "Breathing", value: exercise.breathing)
                Divider().overlay(Theme.stroke)
                detailRow(label: "Rest", value: "\(exercise.prescription.restSeconds)s between sets")
                Divider().overlay(Theme.stroke)
                detailRow(label: "Animation", value: exercise.animation)
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(Theme.font(11, .medium))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 78, alignment: .leading)
            Text(value)
                .font(Theme.font(12))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func detailCard<Content: View>(
        icon: String,
        title: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(Theme.font(15, .bold))
                    .foregroundStyle(Theme.text)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fitrCard()
    }
}
