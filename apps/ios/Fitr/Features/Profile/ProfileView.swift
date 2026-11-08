import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL

    @Binding var drawerOpen: Bool

    @State private var section: ProfileSection = .profile
    @State private var name = ""
    @State private var goal: GoalOption = .balanced
    @State private var experience: ExperienceOption = .intermediate
    @State private var daysPerWeek = 5.0
    @State private var sessionMinutes = 45.0
    @State private var equipment: Set<String> = []
    @State private var serverURL = ""
    @State private var connection: ConnectionState = .idle
    @State private var hydratedFor: String?
    @State private var dragOffset: CGFloat = 0

    private let drawerWidth: CGFloat = 304

    var body: some View {
        ZStack(alignment: .leading) {
            content
                .disabled(drawerOpen)
                .accessibilityHidden(drawerOpen)
                .scaleEffect(drawerOpen ? 0.97 : 1, anchor: .trailing)
                .animation(.spring(response: 0.42, dampingFraction: 0.86), value: drawerOpen)

            if drawerOpen {
                scrim
                drawer
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: drawerOpen)
        .onAppear { hydrate() }
    }

    private var content: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Color.clear
                        .frame(height: 0)
                        .id("top")

                    header
                    if let message = store.errorMessage, store.isOffline {
                        ErrorBanner(message: message) {
                            Task { await store.reconnect(serverURL: serverURL) }
                        } dismiss: {
                            store.dismissError()
                        }
                    }
                    sectionContent
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: section) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        Group {
            switch section {
            case .profile:
                VStack(alignment: .leading, spacing: 20) {
                    identityCard
                    focusCard
                    saveBar
                }
            case .training:
                VStack(alignment: .leading, spacing: 20) {
                    rhythmCard
                    equipmentCard
                    saveBar
                }
            case .connection:
                connectionCard
            case .program:
                programCard
            case .about:
                aboutCard
            }
        }
        .id(section)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            menuButton
            VStack(alignment: .leading, spacing: 6) {
                Text("YOUR SYSTEM")
                    .font(Theme.font(10, .bold))
                    .tracking(2)
                    .foregroundStyle(goalColor)
                Text("You")
                    .font(Theme.font(34, .heavy))
                    .foregroundStyle(Theme.text)
                Text(section.subtitle)
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            avatar(size: 54)
        }
    }

    private var menuButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                drawerOpen = true
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.surface))
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open menu")
        .padding(.top, 4)
    }

    private func avatar(size: CGFloat) -> some View {
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
                .font(Theme.font(size * 0.38, .heavy))
                .foregroundStyle(Theme.ink)
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
    }

    // MARK: - Drawer

    private var scrim: some View {
        Color.black.opacity(0.55)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { closeDrawer() }
            .transition(.opacity)
    }

    private var drawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            drawerHeader

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    drawerGroup("PERSONAL", items: [.profile, .training])
                    drawerGroup("SYSTEM", items: [.connection, .program, .about])
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }

            drawerFooter
        }
        .frame(width: drawerWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            UnevenRoundedRectangle(
                bottomTrailingRadius: 34,
                topTrailingRadius: 34,
                style: .continuous
            )
            .fill(Theme.inkSoft)
            .overlay(
                UnevenRoundedRectangle(
                    bottomTrailingRadius: 34,
                    topTrailingRadius: 34,
                    style: .continuous
                )
                .strokeBorder(Theme.strokeStrong, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 30, x: 18, y: 0)
            .ignoresSafeArea()
        }
        .offset(x: dragOffset)
        .gesture(closeDrag)
        .accessibilityAddTraits(.isModal)
    }

    private var drawerHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("MENU")
                    .font(Theme.font(10, .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Button {
                    closeDrawer()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close menu")
            }

            HStack(spacing: 12) {
                avatar(size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name.isEmpty ? "Athlete" : name)
                        .font(Theme.font(20, .heavy))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text("\(goal.title) · \(experience.title)")
                        .font(Theme.font(11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                FitrPill(text: "\(Int(daysPerWeek)) days", icon: "calendar", tint: Theme.mint)
                FitrPill(text: "\(Int(sessionMinutes)) min", icon: "clock.fill", tint: Theme.violet)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    private func drawerGroup(_ title: String, items: [ProfileSection]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.font(9, .bold))
                .tracking(1.4)
                .foregroundStyle(Theme.textTertiary)
                .padding(.leading, 10)
            ForEach(items) { item in
                drawerRow(item)
            }
        }
    }

    private func drawerRow(_ item: ProfileSection) -> some View {
        let selected = section == item
        return Button {
            select(item)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selected ? Theme.ink : item.tint)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(selected ? item.tint : item.tint.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(Theme.font(14, .semibold))
                        .foregroundStyle(Theme.text)
                    Text(item.caption)
                        .font(Theme.font(10))
                        .foregroundStyle(selected ? Theme.textSecondary : Theme.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(item.tint)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? item.tint.opacity(0.12) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(selected ? item.tint.opacity(0.28) : .clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var drawerFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(Theme.stroke)
                .frame(height: 1)
            HStack {
                FitrPill(
                    text: store.isOffline ? "Offline" : "Connected",
                    icon: store.isOffline ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                    tint: store.isOffline ? Theme.coral : Theme.lime
                )
                Spacer()
                Text("v0.1.0")
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    private var closeDrag: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = min(0, value.translation.width)
            }
            .onEnded { value in
                if value.translation.width < -70 || value.predictedEndTranslation.width < -140 {
                    closeDrawer()
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func select(_ item: ProfileSection) {
        guard item != section else {
            closeDrawer()
            return
        }
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.snappy(duration: 0.24)) {
            section = item
            drawerOpen = false
        }
        dragOffset = 0
    }

    private func closeDrawer() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            drawerOpen = false
        }
        dragOffset = 0
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

private enum ProfileSection: String, CaseIterable, Identifiable {
    case profile, training, connection, program, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile: return "Profile"
        case .training: return "Training"
        case .connection: return "Connection"
        case .program: return "Program"
        case .about: return "About Fitr"
        }
    }

    var caption: String {
        switch self {
        case .profile: return "Name, focus and experience"
        case .training: return "Rhythm, sessions and equipment"
        case .connection: return "Server, health checks and offline"
        case .program: return "Progression and weekly targets"
        case .about: return "Docs, links and version"
        }
    }

    var subtitle: String {
        switch self {
        case .profile: return "Identity, training focus and experience."
        case .training: return "Weekly rhythm, session length and equipment."
        case .connection: return "Server connection, health checks and offline mode."
        case .program: return "The progression engine and this week's targets."
        case .about: return "How Fitr is built, plus docs and links."
        }
    }

    var icon: String {
        switch self {
        case .profile: return "person.fill"
        case .training: return "waveform.path.ecg"
        case .connection: return "server.rack"
        case .program: return "level.fill"
        case .about: return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .profile: return Theme.violet
        case .training: return Theme.mint
        case .connection: return Theme.sky
        case .program: return Theme.lime
        case .about: return Theme.coral
        }
    }
}
