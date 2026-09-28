import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Appearance override. `system` follows the iPhone's Light/Dark setting.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "waketide.appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Aurora

/// Four soft blobs drifting behind every screen, as on the design canvas (positions are in its
/// 390×844 frame and scale with the screen). `night` is the ringing palette.
struct AuroraBackground: View {
    var night = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    private struct Blob {
        let x, y, size: CGFloat
        let color: UInt32
        let opacity: Double
        let duration: Double
    }

    private var ground: Color {
        night ? Color(hex: 0x0C0A1F) : WaketideTheme.ground
    }

    private var blobs: [Blob] {
        if night {
            return [
                Blob(x: -80, y: -60, size: 340, color: 0x4A3FD8, opacity: 0.75, duration: 17),
                Blob(x: 180, y: 180, size: 300, color: 0x8B4FE0, opacity: 0.55, duration: 21),
                Blob(x: -40, y: 560, size: 320, color: 0xFF7A6B, opacity: 0.42, duration: 19),
                Blob(x: 210, y: 640, size: 240, color: 0x2BC5B4, opacity: 0.35, duration: 23)
            ]
        }
        if colorScheme == .dark {
            return [
                Blob(x: -70, y: -60, size: 320, color: 0x3B32B8, opacity: 0.62, duration: 16),
                Blob(x: 190, y: 110, size: 260, color: 0x0F6F62, opacity: 0.45, duration: 19),
                Blob(x: -50, y: 500, size: 330, color: 0x7A4230, opacity: 0.5, duration: 22),
                Blob(x: 200, y: 620, size: 260, color: 0x6B2A66, opacity: 0.45, duration: 18)
            ]
        }
        return [
            Blob(x: -70, y: -60, size: 320, color: 0x9C9DF8, opacity: 0.85, duration: 16),
            Blob(x: 190, y: 110, size: 260, color: 0x8FE8D8, opacity: 0.7, duration: 19),
            Blob(x: -50, y: 500, size: 330, color: 0xFFC7A0, opacity: 0.8, duration: 22),
            Blob(x: 200, y: 620, size: 260, color: 0xF7B0DA, opacity: 0.6, duration: 18)
        ]
    }

    var body: some View {
        GeometryReader { geo in
            let sx = geo.size.width / 390
            let sy = geo.size.height / 844
            ZStack(alignment: .topLeading) {
                ground
                ForEach(Array(blobs.enumerated()), id: \.offset) { _, b in
                    Circle()
                        .fill(Color(hex: b.color))
                        .opacity(b.opacity)
                        .frame(width: b.size * sx, height: b.size * sx)
                        .blur(radius: 46 * sx)
                        .scaleEffect(drift ? 1.12 : 1)
                        .offset(x: b.x * sx + (drift ? 26 : 0), y: b.y * sy + (drift ? -34 : 0))
                        .animation(reduceMotion ? nil : .easeInOut(duration: b.duration).repeatForever(autoreverses: true), value: drift)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onAppear { if !reduceMotion { drift = true } }
    }
}

// MARK: - Glass

/// The canvas's glass: a frosted, white-edged surface with a soft indigo shadow.
struct WaketideGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let dark = colorScheme == .dark
        content.background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(WaketideTheme.cssGradient(135, colors: dark
                    ? [Color.white.opacity(0.13), Color.white.opacity(0.04)]
                    : [Color.white.opacity(0.66), Color.white.opacity(0.3)]))
                shape.strokeBorder(Color.white.opacity(dark ? 0.16 : 0.78), lineWidth: 1)
                shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(dark ? 0.25 : 0.95), .clear],
                                                  startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.12)),
                                   lineWidth: 1)
            }
            .outlineShadow(shape, color: dark ? Color.black.opacity(0.35) : Color(hex: 0x503CA0).opacity(0.14), radius: 15, y: 10)
        }
    }
}

/// Shadow that follows the shape's outline, independent of how translucent the fill is.
private struct OutlineShadow<S: Shape>: View {
    let shape: S
    let color: Color
    let radius: CGFloat
    let y: CGFloat

    var body: some View {
        shape.fill(Color.black)
            .shadow(color: color, radius: radius, y: y)
            .mask(Rectangle().padding(-80).overlay(shape.fill(Color.black).blendMode(.destinationOut)).compositingGroup())
    }
}

extension View {
    /// A glass card with continuous rounded corners.
    func glassCard(_ radius: CGFloat = 28) -> some View {
        modifier(WaketideGlass(shape: RoundedRectangle(cornerRadius: radius, style: .continuous)))
    }

    func glassCapsule() -> some View {
        modifier(WaketideGlass(shape: Capsule()))
    }

    /// Outline shadow for translucent fills (CSS box-shadow behaviour).
    func outlineShadow<S: Shape>(_ shape: S, color: Color, radius: CGFloat, y: CGFloat) -> some View {
        background(OutlineShadow(shape: shape, color: color, radius: radius, y: y))
    }
}

// MARK: - Buttons

/// Press feedback from the canvas: shrink, then spring back with a little overshoot.
struct PressScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// Fill and edge of the canvas's small glass controls (`.ib`, `.pill`, `.dp`).
struct ControlSurface<S: InsettableShape>: View {
    let shape: S
    var fill: Double = 0.55
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        shape.fill(Color.white.opacity(dark ? 0.09 : fill))
            .overlay(shape.strokeBorder(Color.white.opacity(dark ? 0.16 : 0.85), lineWidth: 1))
            .overlay(shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(dark ? 0.22 : 1), .clear],
                                                       startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.15)), lineWidth: 1))
            .outlineShadow(shape, color: dark ? Color.black.opacity(0.3) : Color(hex: 0x503CA0).opacity(0.12), radius: 6, y: 4)
    }
}

/// 44 pt round glass button (`.ib`).
struct IconButton: View {
    let icon: WTIcon
    let label: String
    var size: CGFloat = 20
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            IconGlyph(icon: icon, size: size)
                .foregroundStyle(prominent ? Color.white : WaketideTheme.iconInk)
                .frame(width: 44, height: 44)
                .background {
                    if prominent {
                        Circle().fill(WaketideTheme.brandGradient)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
                    } else {
                        ControlSurface(shape: Circle())
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(label)
    }
}

/// Capsule glass pill (`.pill`), used for presets and suggestions.
struct GlassPill: View {
    let title: String
    var icon: WTIcon? = nil
    var selected = false
    var height: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { IconGlyph(icon: icon, size: 18) }
                Text(title)
            }
            .font(.ui(14, .bold))
            .foregroundStyle(selected ? Color.white : WaketideTheme.pillInk)
            .padding(.horizontal, 18)
            .frame(minHeight: height)
            .background {
                if selected {
                    Capsule().fill(WaketideTheme.selectedGradient)
                        .outlineShadow(Capsule(), color: Color(hex: 0x5B52E0).opacity(0.4), radius: 8, y: 6)
                } else {
                    ControlSurface(shape: Capsule())
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle(scale: 0.95))
    }
}

/// Primary call to action (`.cta`): brand gradient with a light sweep passing over it.
struct CTAButton: View {
    let title: String
    var icon: WTIcon? = nil
    var height: CGFloat = 60
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { IconGlyph(icon: icon, size: 22, stroke: 2.2) }
                Text(title)
            }
            .font(.ui(17, .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: height)
            .background {
                Capsule().fill(WaketideTheme.brandGradient)
                    .overlay {
                        if !reduceMotion && isEnabled {
                            TimelineView(.animation) { context in
                                GeometryReader { geo in
                                    let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.6) / 3.6
                                    let p = min(1, t / 0.55)
                                    let x = -80 + p * (geo.size.width * 1.1 + 80)
                                    LinearGradient(colors: [.clear, Color.white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                                        .frame(width: 60)
                                        .scaleEffect(y: 2.0)
                                        .rotationEffect(.degrees(10))
                                        .offset(x: x)
                                }
                            }
                            .clipShape(Capsule())
                            .allowsHitTesting(false)
                        }
                    }
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
                    .outlineShadow(Capsule(), color: Color(hex: 0x5B52E0).opacity(0.45), radius: 15, y: 14)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle(scale: 0.97))
        .opacity(isEnabled ? 1 : 0.5)
    }
}

/// The canvas's switch (`.tog`): a 56×32 track and a knob that springs across.
struct WaketideToggle: View {
    @Binding var isOn: Bool
    let label: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? AnyShapeStyle(WaketideTheme.toggleGradient)
                               : AnyShapeStyle(Color(hex: 0x6E6C96).opacity(colorScheme == .dark ? 0.45 : 0.3)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.85), lineWidth: 1))
                Circle()
                    .fill(Color.white)
                    .shadow(color: Color(hex: 0x281E64).opacity(0.35), radius: 3, y: 2)
                    .frame(width: 26, height: 26)
                    .padding(3)
            }
            .frame(width: 56, height: 32)
            .padding(8)
            .contentShape(Rectangle())
            .padding(-8)
            .animation(.spring(response: 0.45, dampingFraction: 0.6), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(label, isOn: $isOn)
        }
    }
}

// MARK: - Layout pieces

/// Screen title and its trailing buttons, as on every canvas screen.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.waketide(34, .heavy))
                .tracking(-0.68)
                .foregroundStyle(WaketideTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            trailing()
        }
        .frame(minHeight: 48)
    }
}

struct SectionEyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.ui(12, .bold))
            .tracking(0.96)
            .foregroundStyle(WaketideTheme.eyebrow)
    }
}

/// A 56 pt glass row with a caption on the left (`.row`).
struct GlassRow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 10, content: content)
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .glassCard(24)
    }
}

/// Appearance override, as a round glass button with a menu.
struct AppearanceMenu: View {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    var body: some View {
        Menu {
            Picker("Appearance", selection: $appearance) {
                ForEach(AppAppearance.allCases) { option in
                    Label(option.title, systemImage: option.systemImage).tag(option)
                }
            }
        } label: {
            IconGlyph(icon: .appearance, size: 20)
                .foregroundStyle(WaketideTheme.iconInk)
                .frame(width: 44, height: 44)
                .background(ControlSurface(shape: Circle()))
        }
        .accessibilityLabel("Appearance")
        .accessibilityValue(appearance.title)
    }
}
