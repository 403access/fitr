import SwiftUI

struct CatalogueView: View {
    @Environment(AppStore.self) private var store

    @State private var search = ""
    @State private var topic: String?
    @State private var type: String?
    @State private var region: String?
    @State private var muscle: String?
    @State private var difficulty: Int?
    @State private var showFilters = false
    @State private var selectedExercise: Exercise?

    private var exercises: [Exercise] { store.exercises }

    private var filtered: [Exercise] {
        exercises.filter { exercise in
            if let topic, exercise.topic.id != topic { return false }
            if let type, exercise.type.id != type { return false }
            if let region, !exercise.regions.contains(where: { $0.id == region }) { return false }
            if let muscle, !(exercise.primaryMuscles + exercise.secondaryMuscles).contains(where: { $0.id == muscle }) { return false }
            if let difficulty, exercise.difficulty != difficulty { return false }
            if !search.isEmpty {
                let needle = search.lowercased()
                let haystack = [
                    exercise.name,
                    exercise.summary,
                    exercise.topic.name,
                    exercise.type.name,
                    exercise.primaryMuscles.map(\.name).joined(separator: " "),
                ].joined(separator: " ").lowercased()
                if !haystack.contains(needle) { return false }
            }
            return true
        }
    }

    private var activeFilterCount: Int {
        [type != nil, region != nil, muscle != nil, difficulty != nil].filter { $0 }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                searchField
                topicRow
                filterSummary
                results
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showFilters) {
            ExerciseFilterSheet(
                type: $type,
                region: $region,
                muscle: $muscle,
                difficulty: $difficulty
            )
            .environment(store)
            .presentationDetents([.large])
            .presentationCornerRadius(34)
            .presentationBackground(Theme.ink)
        }
        .sheet(item: $selectedExercise) { exercise in
            ExerciseDetailView(exercise: exercise)
                .presentationDetents([.large])
                .presentationCornerRadius(34)
                .presentationBackground(Theme.ink)
        }
        .onAppear { openDebugDetailIfNeeded() }
    }

    private func openDebugDetailIfNeeded() {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["FITR_EXERCISE"] == "1",
              selectedExercise == nil else { return }
        selectedExercise = exercises.first { $0.slug == "barbell-back-squat" } ?? exercises.first
        #endif
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("MOVEMENT LIBRARY")
                    .font(Theme.font(10, .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.lime)
                Text("Explore")
                    .font(Theme.font(34, .heavy))
                    .foregroundStyle(Theme.text)
                Text("\(exercises.count) exercises · \(store.facets.topics.count) disciplines")
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button {
                showFilters = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.surface))
                        .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
                    if activeFilterCount > 0 {
                        Text("\(activeFilterCount)")
                            .font(Theme.font(8, .heavy))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Theme.lime))
                            .offset(x: 4, y: -4)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
            TextField("Search exercise, muscle, focus…", text: $search)
                .font(Theme.font(14))
                .foregroundStyle(Theme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
    }

    private var topicRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                topicChip(id: nil, name: "All", icon: "square.grid.2x2.fill", tint: Theme.lime, count: exercises.count)
                ForEach(store.facets.topics) { facet in
                    topicChip(
                        id: facet.id,
                        name: facet.name,
                        icon: facet.icon,
                        tint: Theme.color(hex: facet.accent),
                        count: facet.count
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func topicChip(id: String?, name: String, icon: String, tint: Color, count: Int) -> some View {
        let selected = topic == id
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                topic = id
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(name)
                    .font(Theme.font(12, .semibold))
                Text("\(count)")
                    .font(Theme.mono(9, .bold))
                    .opacity(0.6)
            }
            .foregroundStyle(selected ? Theme.ink : Theme.textSecondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? tint : Theme.surface)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(selected ? .clear : Theme.stroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var filterSummary: some View {
        HStack {
            Text("\(filtered.count) \(filtered.count == 1 ? "exercise" : "exercises")")
                .font(Theme.font(11, .medium))
                .foregroundStyle(Theme.textTertiary)
            Spacer()
            if activeFilterCount > 0 || topic != nil {
                Button("Clear all") {
                    withAnimation {
                        topic = nil
                        type = nil
                        region = nil
                        muscle = nil
                        difficulty = nil
                        search = ""
                    }
                }
                .font(Theme.font(11, .semibold))
                .foregroundStyle(Theme.lime)
            }
        }
    }

    private var results: some View {
        Group {
            if filtered.isEmpty {
                EmptyPanel(
                    icon: "magnifyingglass",
                    title: "No matches",
                    message: "Try a broader search or clear a filter. The whole catalogue is available offline.",
                    actionTitle: "Reset filters"
                ) {
                    topic = nil
                    type = nil
                    region = nil
                    muscle = nil
                    difficulty = nil
                    search = ""
                }
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(filtered) { exercise in
                        ExerciseCard(exercise: exercise) { selectedExercise = exercise }
                    }
                }
            }
        }
    }
}

struct ExerciseCard: View {
    let exercise: Exercise
    let action: () -> Void

    private var accent: Color { Theme.color(hex: exercise.topic.accent) }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.22), Theme.surface, Theme.surfaceRaised],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    AnimatedExerciseFigure(animation: exercise.animation, accent: accent, showsChrome: false)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
                .frame(height: 124)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(accent)
                            .frame(width: 5, height: 5)
                        Text(exercise.topic.name.uppercased())
                            .font(Theme.font(8, .bold))
                            .tracking(0.8)
                            .foregroundStyle(accent)
                    }
                    Text(exercise.name)
                        .font(Theme.font(13, .bold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 5) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 8))
                        Text(exercise.primaryMuscles.prefix(2).map(\.name).joined(separator: " · "))
                            .lineLimit(1)
                    }
                    .font(Theme.font(9, .medium))
                    .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 11)
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.surface.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct ExerciseFilterSheet: View {
    @Binding var type: String?
    @Binding var region: String?
    @Binding var muscle: String?
    @Binding var difficulty: Int?
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            FitrBackground(accent: Theme.violet)
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("FILTERS")
                                .font(Theme.font(10, .bold))
                                .tracking(2)
                                .foregroundStyle(Theme.violet)
                            Text("Shape the search")
                                .font(Theme.font(28, .heavy))
                                .foregroundStyle(Theme.text)
                        }
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.text)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Theme.surface))
                        }
                        .buttonStyle(.plain)
                    }

                    filterGroup(title: "TYPE", options: store.facets.types.map { ($0.id, $0.name, $0.count) }, selection: $type, tint: Theme.violet)
                    filterGroup(title: "REGION", options: store.facets.regions.map { ($0.id, $0.name, $0.count) }, selection: $region, tint: Theme.mint)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("PRIMARY OR AUXILIARY MUSCLE")
                            .font(Theme.font(10, .bold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.textTertiary)
                        FlowLayout(spacing: 7, lineSpacing: 7) {
                            ForEach(store.facets.muscles) { option in
                                choiceChip(
                                    title: option.name,
                                    count: option.count,
                                    selected: muscle == option.id,
                                    tint: Theme.coral
                                ) {
                                    muscle = muscle == option.id ? nil : option.id
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("DIFFICULTY")
                            .font(Theme.font(10, .bold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.textTertiary)
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { value in
                                choiceChip(
                                    title: "\(value)",
                                    count: nil,
                                    selected: difficulty == value,
                                    tint: Theme.lime
                                ) {
                                    difficulty = difficulty == value ? nil : value
                                }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button("Clear") {
                            type = nil
                            region = nil
                            muscle = nil
                            difficulty = nil
                        }
                        .buttonStyle(FitrPrimaryButtonStyle(tint: Theme.lime, filled: false))

                        Button("Show results") { dismiss() }
                            .buttonStyle(FitrPrimaryButtonStyle(tint: Theme.lime))
                    }
                    .padding(.top, 6)
                }
                .padding(22)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func filterGroup(
        title: String,
        options: [(String, String, Int)],
        selection: Binding<String?>,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.font(10, .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textTertiary)
            FlowLayout(spacing: 7, lineSpacing: 7) {
                ForEach(options, id: \.0) { option in
                    choiceChip(
                        title: option.1,
                        count: option.2,
                        selected: selection.wrappedValue == option.0,
                        tint: tint
                    ) {
                        selection.wrappedValue = selection.wrappedValue == option.0 ? nil : option.0
                    }
                }
            }
        }
    }

    private func choiceChip(title: String, count: Int?, selected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.snappy(duration: 0.2)) { action() }
        } label: {
            HStack(spacing: 5) {
                Text(title)
                    .font(Theme.font(11, .semibold))
                if let count {
                    Text("\(count)")
                        .font(Theme.mono(8, .bold))
                        .opacity(0.55)
                }
            }
            .foregroundStyle(selected ? Theme.ink : Theme.textSecondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? tint : Theme.surface)
                    .overlay(Capsule(style: .continuous).strokeBorder(selected ? .clear : Theme.stroke, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}
