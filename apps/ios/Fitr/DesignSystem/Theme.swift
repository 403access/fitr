import SwiftUI

enum Theme {
    // Canvas
    static let ink = Color(hex: 0x08090C)
    static let inkSoft = Color(hex: 0x0C0E13)
    static let surface = Color(hex: 0x13151C)
    static let surfaceRaised = Color(hex: 0x191C25)
    static let stroke = Color.white.opacity(0.08)
    static let strokeStrong = Color.white.opacity(0.14)

    // Accents
    static let lime = Color(hex: 0xC9FB4B)
    static let violet = Color(hex: 0x9B7BFF)
    static let coral = Color(hex: 0xFF8A66)
    static let sky = Color(hex: 0x77B7FF)
    static let pink = Color(hex: 0xFF6B9A)
    static let mint = Color(hex: 0x6FE7DD)

    // Type
    static let text = Color.white
    static let textSecondary = Color.white.opacity(0.64)
    static let textTertiary = Color.white.opacity(0.38)

    static func accent(for topicID: String?) -> Color {
        switch topicID {
        case "strength": return lime
        case "endurance": return pink
        case "yoga": return violet
        case "mobility": return mint
        case "calisthenics": return coral
        case "cardio": return pink
        case "recovery": return sky
        default: return lime
        }
    }

    static func color(hex: String) -> Color {
        var value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if value.count == 3 { value = value.map { "\($0)\($0)" }.joined() }
        var int: UInt64 = 0
        Scanner(string: value).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension View {
    func fitrCard(padding: CGFloat = 18, radius: CGFloat = 26) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.surface.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    )
            )
    }

    func fitrGlass(radius: CGFloat = 26) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
    }

    func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
