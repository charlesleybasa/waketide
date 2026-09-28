import AlarmKit
import SwiftUI
import UIKit

/// Data that travels with every AlarmKit alarm or timer so the Live Activity
/// (Lock Screen and Dynamic Island) can show it without asking the app.
struct WaketideMetadata: AlarmMetadata {
    var label: String
    var isTimer: Bool

    init(label: String, isTimer: Bool = false) {
        self.label = label
        self.isTimer = isTimer
    }
}

/// Design tokens from the Waketide design canvas. Light values are the canvas's exact colours;
/// each has a night value for the dusk aurora, so every screen adapts without per-view checks.
enum WaketideTheme {
    // Brand
    static let indigo = adaptive(light: 0x5B52E0, dark: 0x8A83FA)
    static let violet = adaptive(light: 0x8A86F8, dark: 0xA29DFF)
    static let mint = adaptive(light: 0x8FE8D8, dark: 0x4FBFAE)
    static let peach = adaptive(light: 0xFFC7A0, dark: 0xE89A70)
    static let coral = adaptive(light: 0xFF5E7A, dark: 0xFF6F88)

    // Text
    /// Titles, times, primary text.
    static let ink = adaptive(light: 0x1C1A33, dark: 0xF1EEFF)
    /// Labels and secondary lines.
    static let inkSoft = adaptive(light: 0x4A4868, dark: 0xB4B0D6)
    /// Eyebrows, hour labels, field captions.
    static let eyebrow = adaptive(light: 0x55536F, dark: 0xA9A5CC)
    /// Small weekday names in the day strip.
    static let dayInk = adaptive(light: 0x3C3A5C, dark: 0xC9C5E8)
    /// Icons inside round glass buttons.
    static let iconInk = adaptive(light: 0x38366A, dark: 0xDCD9F7)
    /// Idle tab bar items.
    static let tabIdle = adaptive(light: 0x4A4870, dark: 0xB4B0D6)
    /// Active tab, counts, picker values.
    static let accentInk = adaptive(light: 0x3A34C4, dark: 0xB1ACFF)
    /// Text on light glass pills.
    static let pillInk = adaptive(light: 0x2A2860, dark: 0xE6E3FF)
    static let mintInk = adaptive(light: 0x0D6B5C, dark: 0x7FE3D1)
    static let orangeInk = adaptive(light: 0xA04A1A, dark: 0xFFB58E)

    // Surfaces
    /// The colour under the aurora.
    static let ground = adaptive(light: 0xF1ECF7, dark: 0x0D0B1E)
    /// Solid fill for small markers that sit on glass (e.g. an off alarm's rail dot).
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x2A2650, lightAlpha: 0.9)
    /// The Plans "now" line.
    static let nowLine = adaptive(light: 0xE8557A, dark: 0xFF6F8E)
    static let nowInk = adaptive(light: 0xB02A52, dark: 0xFF9AB2)
    /// Island and Lock Screen accent on black.
    static let islandLilac = Color(uiColor: rgb(0xB4B0FF))

    /// Fixed indigo for AlarmKit presentations. iOS draws those on its own material and stores
    /// the colour with the alarm, so it must not depend on the app's appearance.
    static let brandIndigo = Color(uiColor: rgb(0x5B52E0))

    // Gradients (CSS angles from the canvas)
    /// Selected day, selected weekday pill, user chat bubble.
    static let selectedGradient = cssGradient(160, [(0x7D7CF5, 0), (0x5B52E0, 1)])
    /// Plus button, primary buttons, main timer control.
    static let brandGradient = cssGradient(150, [(0x8A86F8, 0), (0x5B4FE0, 0.6), (0x7A52E6, 1)])
    static let toggleGradient = cssGradient(90, [(0x6F6CF0, 0), (0x9A7CF6, 1)])
    static let coralGradient = cssGradient(150, [(0xFF9A7A, 0), (0xFF5F7A, 1)])

    static func hex(_ value: UInt32, _ alpha: Double = 1) -> Color {
        Color(uiColor: rgb(value, alpha: CGFloat(alpha)))
    }

    /// A linear gradient using a CSS angle (0° points up, 90° points right).
    static func cssGradient(_ degrees: Double, _ stops: [(UInt32, Double)]) -> LinearGradient {
        let r = degrees * .pi / 180
        let dx = sin(r) / 2, dy = -cos(r) / 2
        return LinearGradient(
            stops: stops.map { Gradient.Stop(color: hex($0.0), location: $0.1) },
            startPoint: UnitPoint(x: 0.5 - dx, y: 0.5 - dy),
            endPoint: UnitPoint(x: 0.5 + dx, y: 0.5 + dy)
        )
    }

    static func cssGradient(_ degrees: Double, colors: [Color]) -> LinearGradient {
        let r = degrees * .pi / 180
        let dx = sin(r) / 2, dy = -cos(r) / 2
        return LinearGradient(colors: colors, startPoint: UnitPoint(x: 0.5 - dx, y: 0.5 - dy), endPoint: UnitPoint(x: 0.5 + dx, y: 0.5 + dy))
    }

    private static func adaptive(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? rgb(dark) : rgb(light, alpha: lightAlpha)
        })
    }

    private static func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

// MARK: - Typography

extension Font {
    /// Bricolage Grotesque, the design's display face (titles, times, numbers).
    /// Scales with Dynamic Type unless `fixed` (used where a layout can't grow, like the tab bar).
    static func waketide(_ size: CGFloat, _ weight: Font.Weight = .bold, fixed: Bool = false) -> Font {
        let name: String
        switch weight {
        case .heavy, .black: name = "BricolageGrotesque-ExtraBold"
        case .bold, .semibold: name = "BricolageGrotesque-Bold"
        default: name = "BricolageGrotesque-Medium"
        }
        return fixed ? .custom(name, fixedSize: size) : .custom(name, size: size, relativeTo: textStyle(for: size))
    }

    /// DM Sans, the design's text face (labels, body, buttons).
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .medium, fixed: Bool = false) -> Font {
        let name: String
        switch weight {
        case .bold, .semibold, .heavy, .black: name = "DMSans-Bold"
        case .medium: name = "DMSans-Medium"
        default: name = "DMSans-Regular"
        }
        return fixed ? .custom(name, fixedSize: size) : .custom(name, size: size, relativeTo: textStyle(for: size))
    }

    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 30...: return .largeTitle
        case 22..<30: return .title
        case 19..<22: return .title3
        case 16..<19: return .body
        case 14..<16: return .subheadline
        case 12..<14: return .footnote
        default: return .caption
        }
    }
}
