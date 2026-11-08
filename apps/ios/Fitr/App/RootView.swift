import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var tab: AppTab
    @State private var profileDrawerOpen = false

    init() {
        var initial: AppTab = .today
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["FITR_TAB"],
           let parsed = AppTab(rawValue: raw) {
            initial = parsed
        }
        #endif
        _tab = State(initialValue: initial)
        #if DEBUG
        if ProcessInfo.processInfo.environment["FITR_DRAWER"] == "1" {
            _profileDrawerOpen = State(initialValue: true)
        }
        #endif
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if settings.hasOnboarded {
                main
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: settings.hasOnboarded)
        .task { await store.start() }
    }

    private var main: some View {
        ZStack(alignment: .bottom) {
            FitrBackground()
            Group {
                switch tab {
                case .today: TodayView()
                case .catalogue: CatalogueView()
                case .progress: TrainingProgressView()
                case .health: HealthView()
                case .profile: ProfileView(drawerOpen: $profileDrawerOpen)
                }
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 78) }

            LinearGradient(
                colors: [.clear, Theme.ink.opacity(0.75), Theme.ink],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 130)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)
            .opacity(profileDrawerOpen ? 0 : 1)

            if !profileDrawerOpen {
                FitrTabBar(selection: $tab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let toast = store.toast {
                ToastBanner(text: toast)
                    .padding(.bottom, 92)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(3)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: store.toast)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: profileDrawerOpen)
    }
}

struct FitrTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    guard selection != tab else { return }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                        selection = tab
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .semibold))
                        if selection == tab {
                            Text(tab.title)
                                .font(Theme.font(12, .bold))
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                    .foregroundStyle(selection == tab ? Theme.ink : Theme.textSecondary)
                    .padding(.horizontal, selection == tab ? 16 : 14)
                    .frame(height: 44)
                    .background {
                        if selection == tab {
                            Capsule(style: .continuous)
                                .fill(Theme.lime)
                                .matchedGeometryEffect(id: "tab", in: namespace)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(6)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.surface.opacity(0.92))
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .overlay(Capsule(style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 20, y: 12)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }
}

struct ToastBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.lime)
            Text(text)
                .font(Theme.font(13, .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.surfaceRaised)
                .overlay(Capsule(style: .continuous).strokeBorder(Theme.strokeStrong, lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
        )
        .padding(.horizontal, 30)
    }
}
