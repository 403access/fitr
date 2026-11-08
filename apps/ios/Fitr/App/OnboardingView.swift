import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppSettings.self) private var settings

    @State private var step = 0
    @State private var name = ""
    @State private var goal: GoalOption = .balanced
    @State private var daysPerWeek = 5.0
    @State private var sessionMinutes = 45.0
    @State private var serverURL = ""
    @State private var connectionState: ConnectionState = .idle
    @State private var isFinishing = false

    private let titles = ["Welcome", "Your focus", "Your rhythm", "Your server"]

    var body: some View {
        ZStack {
            FitrBackground(accent: goalColor)
            VStack(spacing: 0) {
                header
                TabView(selection: $step) {
                    welcome.tag(0)
                    focus.tag(1)
                    rhythm.tag(2)
                    connect.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: step)
                footer
            }
        }
        .onAppear { serverURL = settings.serverURLString }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(goalColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: goalColor.opacity(0.8), radius: 6)
                Text("FITR")
                    .font(Theme.font(14, .heavy))
                    .tracking(3)
                    .foregroundStyle(Theme.text)
            }
            Spacer()
            if step < 3 {
                Button("Skip") { settings.hasOnboarded = true }
                    .font(Theme.font(13, .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private var footer: some View {
        VStack(spacing: 18) {
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? goalColor : Color.white.opacity(0.15))
                        .frame(width: index == step ? 22 : 6, height: 6)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: step)
                }
            }

            HStack(spacing: 12) {
                if step > 0 {
                    Button {
                        withAnimation { step -= 1 }
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.text)
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
                }

                Button {
                    advance()
                } label: {
                    HStack(spacing: 8) {
                        if isFinishing {
                            ProgressView()
                                .tint(Theme.ink)
                        } else {
                            Text(step == 3 ? "Start training" : "Continue")
                            Image(systemName: step == 3 ? "bolt.fill" : "arrow.right")
                        }
                    }
                }
                .buttonStyle(FitrPrimaryButtonStyle(tint: goalColor))
                .disabled(isFinishing)
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 18)
        .padding(.top, 8)
    }

    // MARK: - Steps

    private var welcome: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 26) {
                ZStack {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Theme.violet.opacity(0.34), Theme.lime.opacity(0.10), Theme.surface],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    AnimatedExerciseFigure(animation: "warrior", accent: Theme.lime)
                        .padding(18)
                    VStack {
                        Spacer()
                        HStack {
                            FitrPill(text: "Self-coached", icon: "sparkles", tint: Theme.lime, filled: true)
                            Spacer()
                        }
                        .padding(18)
                    }
                }
                .frame(height: 310)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )

                VStack(spacing: 12) {
                    Text("Train on\nyour rhythm.")
                        .font(Theme.font(40, .heavy))
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(-5)
                    Text("A catalogue of beautifully animated movement, a day plan that flows from wake to sleep, and progress you can actually prove.")
                        .font(Theme.font(15))
                        .foregroundStyle(Theme.textSecondary)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("WHAT SHOULD WE CALL YOU?")
                        .font(Theme.font(10, .bold))
                        .tracking(1.6)
                        .foregroundStyle(Theme.textTertiary)
                    TextField("Your name", text: $name)
                        .font(Theme.font(22, .bold))
                        .foregroundStyle(Theme.text)
                        .textInputAutocapitalization(.words)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Theme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(Theme.stroke, lineWidth: 1)
                                )
                        )
                }
                .padding(.bottom, 10)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
        }
    }

    private var focus: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                stepTitle(
                    eyebrow: "STEP 1 OF 3",
                    title: "What are we\nbuilding?",
                    body: "Your choice shapes the morning and afternoon blocks. Everything else stays balanced."
                )

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(GoalOption.allCases) { option in
                        goalCard(option)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }

    private func goalCard(_ option: GoalOption) -> some View {
        let selected = goal == option
        let accent = Theme.accent(for: option == .balanced ? "strength" : option.rawValue)
        return Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { goal = option }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: option.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selected ? Theme.ink : accent)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(selected ? accent : accent.opacity(0.12))
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.title)
                        .font(Theme.font(16, .bold))
                        .foregroundStyle(Theme.text)
                    Text(option.blurb)
                        .font(Theme.font(11))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(selected ? accent.opacity(0.13) : Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(selected ? accent.opacity(0.7) : Theme.stroke, lineWidth: selected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var rhythm: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                stepTitle(
                    eyebrow: "STEP 2 OF 3",
                    title: "Build your\nweekly rhythm",
                    body: "Days and minutes tune the plan. Volume still climbs every week — this is just your starting dose."
                )

                rhythmCard(
                    icon: "calendar",
                    title: "Training days",
                    value: "\(Int(daysPerWeek))",
                    suffix: "per week",
                    caption: daysPerWeek >= 6 ? "High frequency — keep recovery intentional." : "Balanced frequency with real rest days."
                ) {
                    Slider(value: $daysPerWeek, in: 2...7, step: 1)
                        .tint(Theme.lime)
                }

                rhythmCard(
                    icon: "timer",
                    title: "Daily session",
                    value: "\(Int(sessionMinutes))",
                    suffix: "minutes",
                    caption: "Across six time regions: wake, morning, midday, afternoon, evening and before sleep."
                ) {
                    Slider(value: $sessionMinutes, in: 15...90, step: 5)
                        .tint(Theme.violet)
                }

                HStack(spacing: 10) {
                    FitrPill(text: "\(Int(daysPerWeek)) training days", icon: "checkmark", tint: Theme.lime)
                    FitrPill(text: "\(7 - Int(daysPerWeek)) recovery days", icon: "moon", tint: Theme.sky)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }

    private func rhythmCard(
        icon: String,
        title: String,
        value: String,
        suffix: String,
        caption: String,
        @ViewBuilder control: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.lime)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.lime.opacity(0.1)))
                Text(title)
                    .font(Theme.font(15, .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value)
                    .font(Theme.font(46, .heavy))
                    .foregroundStyle(Theme.text)
                    .contentTransition(.numericText())
                Text(suffix)
                    .font(Theme.font(14, .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
            control()
            Text(caption)
                .font(Theme.font(12))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
    }

    private var connect: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                stepTitle(
                    eyebrow: "STEP 3 OF 3",
                    title: "Connect your\nBun server",
                    body: "Fitr keeps your catalogue, plans and history in SQLite behind a small TypeScript API. Point the app at it — localhost works in the simulator."
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("SERVER URL")
                        .font(Theme.font(10, .bold))
                        .tracking(1.6)
                        .foregroundStyle(Theme.textTertiary)
                    TextField("http://localhost:8787", text: $serverURL)
                        .font(Theme.mono(14, .medium))
                        .foregroundStyle(Theme.text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .padding(15)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Theme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(Theme.stroke, lineWidth: 1)
                                )
                        )

                    HStack(spacing: 10) {
                        Button {
                            testConnection()
                        } label: {
                            HStack(spacing: 6) {
                                if connectionState == .testing {
                                    ProgressView().controlSize(.small).tint(Theme.text)
                                } else {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                }
                                Text("Test connection")
                            }
                            .font(Theme.font(12, .bold))
                            .foregroundStyle(Theme.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Theme.surfaceRaised))
                        }
                        .buttonStyle(.plain)

                        switch connectionState {
                        case .idle:
                            EmptyView()
                        case .testing:
                            Text("Reaching server…").font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                        case .success:
                            FitrPill(text: "Connected", icon: "checkmark.circle.fill", tint: Theme.lime)
                        case .failure:
                            FitrPill(text: "No response", icon: "exclamationmark.triangle.fill", tint: Theme.coral)
                        }
                        Spacer()
                    }

                    Text("Tip: run `bun run dev:server` in the repository. On a physical iPhone, use your Mac's LAN IP instead of localhost.")
                        .font(Theme.font(11))
                        .foregroundStyle(Theme.textTertiary)
                        .lineSpacing(2)
                }

                VStack(alignment: .leading, spacing: 12) {
                    summaryRow(icon: "person.fill", label: "Name", value: name.isEmpty ? "Athlete" : name)
                    summaryRow(icon: goal.icon, label: "Focus", value: goal.title)
                    summaryRow(icon: "calendar", label: "Rhythm", value: "\(Int(daysPerWeek)) days · \(Int(sessionMinutes)) min")
                    summaryRow(icon: "server.rack", label: "Server", value: settings.serverURL?.host ?? "Not set")
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(Theme.stroke, lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 22)
            Text(label)
                .font(Theme.font(13))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(Theme.font(13, .semibold))
                .foregroundStyle(Theme.text)
        }
    }

    private func stepTitle(eyebrow: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow)
                .font(Theme.font(10, .bold))
                .tracking(2)
                .foregroundStyle(goalColor)
            Text(title)
                .font(Theme.font(36, .heavy))
                .foregroundStyle(Theme.text)
                .lineSpacing(-4)
            Text(body)
                .font(Theme.font(14))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
        }
    }

    private var goalColor: Color {
        switch goal {
        case .balanced: return Theme.lime
        case .strength: return Theme.lime
        case .endurance: return Theme.pink
        case .mobility: return Theme.mint
        case .recovery: return Theme.sky
        }
    }

    // MARK: - Actions

    private func advance() {
        if step < 3 {
            withAnimation { step += 1 }
            return
        }
        finish()
    }

    private func finish() {
        isFinishing = true
        Task {
            settings.serverURLString = serverURL
            await store.reconnect(serverURL: serverURL)
            _ = await store.saveProfile(
                ProfilePatch(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Athlete" : name,
                    goal: goal.rawValue,
                    experience: nil,
                    daysPerWeek: Int(daysPerWeek),
                    sessionMinutes: Int(sessionMinutes),
                    equipment: nil
                )
            )
            settings.hasOnboarded = true
            isFinishing = false
        }
    }

    private func testConnection() {
        guard let url = URL(string: serverURL), url.host != nil else {
            connectionState = .failure
            return
        }
        connectionState = .testing
        Task {
            let client = APIClient(baseURL: url)
            let ok = await client.health()
            await MainActor.run {
                connectionState = ok ? .success : .failure
            }
        }
    }

    private enum ConnectionState {
        case idle, testing, success, failure
    }
}
