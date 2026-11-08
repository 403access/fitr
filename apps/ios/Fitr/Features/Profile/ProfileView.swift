import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL

    @State private var name = ""
    @State private var goal: GoalOption = .balanced
    @State private var experience: ExperienceOption = .intermediate
    @State private var daysPerWeek = 5.0
    @State private var sessionMinutes = 45.0
    @State private var equipment: Set<String> = []
    @State private var serverURL = ""
    @State private var connection: ConnectionState = .idle
    @State private var hydratedFor: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let message = store.errorMessage, store.isOffline {
                    ErrorBanner(message: message) {
                        Task { await store.reconnect(serverURL: serverURL) }
                    } dismiss: {
                        store.dismissError()
                    }
                }
                identityCard
                focusCard
                rhythmCard
                equipmentCard
                saveBar
                connectionCard
                programCard
                aboutCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onAppear { hydrate() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("YOUR SYSTEM")
                    .font(Theme.font(10, .bold))
                    .tracking(2)
                    .foregroundStyle(goalColor)
                Text("You")
                    .font(Theme.font(34, .heavy))
                    .foregroundStyle(Theme.text)
                Text("Coaching, connection and the plan engine.")
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [goalColor.opacity(0.9), Theme.violet.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(initials)
                    .font(Theme.font(22, .heavy))
                    .foregroundStyle(Theme.ink)
            }
            .frame(width: 58, height: 58)
            .overlay(Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
        }
    }

    // MARK: - Cards

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(icon: "person.fill", title: "Identity", tint: goalColor)
            TextField("Your name", text: $name)
                .font(Theme.font(24, .heavy))
                .foregroundStyle(Theme.text)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.inkSoft)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Theme.stroke, lineWidth: 1)
                        )
                )
            HStack {
                FitrPill(text: "\(goal.title) focus", icon: goal.icon, tint: goalColor)
                FitrPill(text: experience.title, icon: "chart.bar.fill", tint: Theme.textSecondary)
                Spacer()
            }
            Text("This name is local to your Fitr account and appears in the app only.")
                .font(Theme.font(10))
                .foregroundStyle(Theme.textTertiary)
        }
        .fitrCard()
    }

    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(icon: "scope", title: "Training focus", tint: Theme.violet)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(GoalOption.allCases) { option in
                    let selected = goal == option
                    let tint = Theme.accent(for: option == .balanced ? "strength" : option.rawValue)
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { goal = option }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: option.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(option.title)
                                .font(Theme.font(12, .semibold))
                            Spacer()
                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                            }
                        }
                        .foregroundStyle(selected ? Theme.ink : Theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selected ? tint : Theme.inkSoft)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(selected ? .clear : Theme.stroke, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("EXPERIENCE")
                    .font(Theme.font(9, .bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textTertiary)
                HStack(spacing: 4) {
                    ForEach(ExperienceOption.allCases) { option in
                        Button {
                            withAnimation(.snappy(duration: 0.2)) { experience = option }
                        } label: {
                            Text(option.title)
                                .font(Theme.font(11, .semibold))
                                .foregroundStyle(experience == option ? Theme.ink : Theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background {
                                    if experience == option {
                                        Capsule().fill(Theme.violet)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(Capsule().fill(Theme.inkSoft))
            }
        }
        .fitrCard()
    }

    private var rhythmCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            cardHeader(icon: "waveform.path.ecg", title: "Weekly rhythm", tint: Theme.mint)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Int(daysPerWeek))")
                        .font(Theme.font(36, .heavy))
                        .foregroundStyle(Theme.text)
                    Text("training days / week")
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(7 - Int(daysPerWeek)) rest")
                        .font(Theme.font(10, .medium))
                        .foregroundStyle(Theme.sky)
                }
                Slider(value: $daysPerWeek, in: 2...7, step: 1)
                    .tint(Theme.mint)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Int(sessionMinutes))")
                        .font(Theme.font(36, .heavy))
                        .foregroundStyle(Theme.text)
                    Text("minutes / day")
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                }
                Slider(value: $sessionMinutes, in: 15...90, step: 5)
                    .tint(Theme.violet)
            }

            Text("Changes shape the next week's plan. Your current week stays intact so the progression stays honest.")
                .font(Theme.font(10))
                .foregroundStyle(Theme.textTertiary)
                .lineSpacing(2)
        }
        .fitrCard()
    }

    private var equipmentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(icon: "wrench.and.screwdriver.fill", title: "Available equipment", tint: Theme.coral)
            Text("Selected equipment unlocks matching exercises. Leave everything off to train with a full gym.")
                .font(Theme.font(10))
                .foregroundStyle(Theme.textTertiary)
                .lineSpacing(2)
            FlowLayout(spacing: 7, lineSpacing: 7) {
                ForEach(AppSettings.equipmentOptions, id: \.self) { option in
                    let selected = equipment.contains(option)
                    Button {
                        if selected { equipment.remove(option) } else { equipment.insert(option) }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        HStack(spacing: 5) {
                            if selected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            Text(option)
                                .font(Theme.font(11, .semibold))
                        }
                        .foregroundStyle(selected ? Theme.ink : Theme.textSecondary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selected ? Theme.coral : Theme.inkSoft)
                                .overlay(Capsule().strokeBorder(selected ? .clear : Theme.stroke, lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .fitrCard()
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                cardHeader(icon: "server.rack", title: "Connection", tint: Theme.sky)
                Spacer()
                connectionPill
            }
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                TextField("http://localhost:8787", text: $serverURL)
                    .font(Theme.mono(12, .medium))
                    .foregroundStyle(Theme.text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.inkSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    )
            )
            HStack(spacing: 10) {
                Button {
                    reconnect()
                } label: {
                    Label("Reconnect", systemImage: "arrow.triangle.2.circlepath")
                        .font(Theme.font(12, .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Theme.sky))
                }
                .buttonStyle(.plain)

                Button {
                    testConnection()
                } label: {
                    Label("Test", systemImage: "antenna.radiowaves.left.and.right")
                        .font(Theme.font(12, .semibold))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Theme.inkSoft))
                }
                .buttonStyle(.plain)
                .disabled(connection == .testing)
                Spacer()
            }
            Text("The server stores your plan and history in SQLite. Use your Mac's LAN IP when testing on a physical iPhone.")
                .font(Theme.font(10))
                .foregroundStyle(Theme.textTertiary)
                .lineSpacing(2)
        }
        .fitrCard()
    }

    private var programCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(icon: "level.fill", title: "Program", tint: Theme.lime)
            if let plan = store.plan {
                HStack(spacing: 10) {
                    programStat(value: "\(plan.weekIndex)", label: "week")
                    programStat(value: plan.focus, label: "phase")
                    programStat(value: "+\(Int(((plan.volumeMultiplier - 1) * 100).rounded()))%", label: "volume")
                    programStat(value: "+\(Int(((plan.intensityMultiplier - 1) * 100).rounded()))%", label: "load")
                }
                Text("Every completed week raises the target. If you finish all sets at effort 7 or below, the engine adds load or reps the following week.")
                    .font(Theme.font(10))
                    .foregroundStyle(Theme.textTertiary)
                    .lineSpacing(2)
            } else {
                Text("Connect to the server to load your program.")
                    .font(Theme.font(11))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .fitrCard()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(icon: "info.circle.fill", title: "About Fitr", tint: Theme.violet)
            Text("Built with SwiftUI, a Bun + TypeScript API and SQLite. Every exercise illustration is a live Canvas animation — no video assets.")
                .font(Theme.font(11))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2)
            HStack(spacing: 8) {
                FitrPill(text: "iOS 18+", icon: "iphone", tint: Theme.textSecondary)
                FitrPill(text: "v0.1.0", icon: "tag", tint: Theme.textSecondary)
                FitrPill(text: "Offline catalogue", icon: "arrow.down.circle", tint: Theme.mint)
            }
            Button {
                openURL(AppConfig.docsURL)
            } label: {
                HStack {
                    Image(systemName: "book.closed.fill")
                    Text("Product, tech & roadmap docs")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(Theme.font(12, .semibold))
                .foregroundStyle(Theme.text)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.inkSoft)
                )
            }
            .buttonStyle(.plain)

            Button {
                openURL(AppConfig.websiteURL)
            } label: {
                HStack {
                    Image(systemName: "safari.fill")
                    Text("Marketing site")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(Theme.font(12, .semibold))
                .foregroundStyle(Theme.text)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.inkSoft)
                )
            }
            .buttonStyle(.plain)

            Button {
                settings.hasOnboarded = false
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Replay introduction")
                    Spacer()
                }
                .font(Theme.font(12, .semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(12)
            }
            .buttonStyle(.plain)
        }
        .fitrCard()
    }

    // MARK: - Save bar

    private var saveBar: some View {
        Button {
            save()
        } label: {
            HStack(spacing: 8) {
                if store.isSavingProfile {
                    ProgressView().tint(Theme.ink)
                } else {
                    Text("Save changes")
                    Image(systemName: "checkmark")
                }
            }
        }
        .buttonStyle(FitrPrimaryButtonStyle(tint: goalColor))
        .disabled(store.isSavingProfile)
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

    private func programStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.font(13, .bold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(Theme.font(9))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Theme.inkSoft)
        )
    }

    private var connectionPill: some View {
        Group {
            if connection == .testing {
                FitrPill(text: "Testing", icon: "ellipsis", tint: Theme.textSecondary)
            } else if store.isOffline {
                FitrPill(text: "Offline", icon: "exclamationmark.triangle.fill", tint: Theme.coral)
            } else {
                FitrPill(text: "Connected", icon: "checkmark.circle.fill", tint: Theme.lime)
            }
        }
    }

    private var goalColor: Color {
        Theme.accent(for: goal == .balanced ? "strength" : goal.rawValue)
    }

    private var initials: String {
        let parts = (name.isEmpty ? "Athlete" : name).split(separator: " ").prefix(2)
        return parts.compactMap(\.first).map(String.init).joined()
    }

    private func hydrate() {
        guard let user = store.user, hydratedFor != user.id else { return }
        name = user.name
        goal = GoalOption(rawValue: user.goal) ?? .balanced
        experience = ExperienceOption(rawValue: user.experience) ?? .intermediate
        daysPerWeek = Double(user.daysPerWeek)
        sessionMinutes = Double(user.sessionMinutes)
        equipment = Set(user.equipment)
        serverURL = settings.serverURLString
        hydratedFor = user.id
    }

    private func save() {
        let patch = ProfilePatch(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            goal: goal.rawValue,
            experience: experience.rawValue,
            daysPerWeek: Int(daysPerWeek),
            sessionMinutes: Int(sessionMinutes),
            equipment: equipment.sorted()
        )
        Task {
            _ = await store.saveProfile(patch)
        }
    }

    private func reconnect() {
        Task {
            connection = .testing
            await store.reconnect(serverURL: serverURL)
            connection = store.isOffline ? .failure : .success
        }
    }

    private func testConnection() {
        guard let url = URL(string: serverURL), url.host != nil else {
            connection = .failure
            return
        }
        connection = .testing
        Task {
            let client = APIClient(baseURL: url)
            let ok = await client.health()
            connection = ok ? .success : .failure
        }
    }

    private enum ConnectionState {
        case idle, testing, success, failure
    }
}
