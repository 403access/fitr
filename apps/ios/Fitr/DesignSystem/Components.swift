import SwiftUI

struct FitrBackground: View {
    var accent: Color = Theme.lime

    var body: some View {
        ZStack {
            Theme.ink
            LinearGradient(
                colors: [Theme.inkSoft, Theme.ink, Theme.ink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Theme.violet.opacity(0.16))
                .frame(width: 420, height: 420)
                .blur(radius: 140)
                .offset(x: 160, y: -280)
            Circle()
                .fill(accent.opacity(0.10))
                .frame(width: 360, height: 360)
                .blur(radius: 150)
                .offset(x: -180, y: 320)
        }
        .ignoresSafeArea()
    }
}

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 10
    var tint: Color = Theme.lime
    var track: Color = Color.white.opacity(0.08)
    var showGlow = true

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    AngularGradient(
                        colors: [tint.opacity(0.55), tint, tint.opacity(0.75)],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: showGlow ? tint.opacity(0.55) : .clear, radius: showGlow ? lineWidth * 0.8 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.85), value: clamped)
        }
    }
}

struct FitrPill: View {
    let text: String
    var icon: String?
    var tint: Color = Theme.textSecondary
    var filled = false

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(Theme.font(11, .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(filled ? Theme.ink : tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(filled ? tint : tint.opacity(0.10))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(tint.opacity(filled ? 0 : 0.18), lineWidth: 1)
                )
        )
    }
}

struct DeltaBadge: View {
    let value: Double?
    var suffix = ""
    var compact = false

    private var positive: Bool { (value ?? 0) > 0 }
    private var neutral: Bool { value == nil || abs(value ?? 0) < 0.05 }
    private var tint: Color { neutral ? Theme.textSecondary : positive ? Theme.lime : Theme.coral }
    private var icon: String {
        if neutral { return "minus" }
        return positive ? "arrow.up.right" : "arrow.down.right"
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: compact ? 8 : 10, weight: .bold))
            Text(value == nil ? "new" : "\(FitrDate.delta(value))\(suffix)")
                .font(Theme.font(compact ? 10 : 12, .bold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 4)
        .background(Capsule().fill(tint.opacity(0.12)))
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String?
    var trailing: AnyView?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = nil
    }

    init<T: View>(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> T) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.font(20, .bold))
                    .foregroundStyle(Theme.text)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.font(13))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            if let trailing { trailing }
        }
    }
}

struct MetricTile: View {
    let value: String
    let label: String
    var icon: String?
    var tint: Color = Theme.lime
    var delta: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(tint)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(tint.opacity(0.12)))
                }
                Spacer()
                if let delta { DeltaBadge(value: delta, compact: true) }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(Theme.font(24, .bold))
                    .foregroundStyle(Theme.text)
                    .contentTransition(.numericText())
                Text(label)
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
}

struct FitrPrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.lime
    var filled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(16, .bold))
            .foregroundStyle(filled ? Theme.ink : Theme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(filled ? tint : Theme.surfaceRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(filled ? .clear : Theme.strokeStrong, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct ErrorBanner: View {
    let message: String
    var retry: (() -> Void)?
    var dismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.coral)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Text("Connection needs attention")
                    .font(Theme.font(13, .bold))
                    .foregroundStyle(Theme.text)
                Text(message)
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let retry {
                    Button("Try again", action: retry)
                        .font(Theme.font(12, .bold))
                        .foregroundStyle(Theme.lime)
                }
            }
            Spacer(minLength: 0)
            if let dismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
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
}

struct EmptyPanel: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.lime)
                .frame(width: 54, height: 54)
                .background(Circle().fill(Theme.lime.opacity(0.10)))
            Text(title)
                .font(Theme.font(17, .bold))
                .foregroundStyle(Theme.text)
            Text(message)
                .font(Theme.font(13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(Theme.font(13, .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Theme.lime))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Theme.surface.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
