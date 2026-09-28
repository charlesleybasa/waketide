import SwiftUI

/// A snapping wheel from the design's time picker: the centred value is large, neighbours shrink
/// and fade (`.wv.d0/.d1/.d2`), and each detent ticks.
struct WheelPicker<Value: Hashable>: View {
    let items: [Value]
    @Binding var selection: Value
    let label: String
    var width: CGFloat = 84
    var height: CGFloat = 196
    var fontSize: CGFloat = 38
    let text: (Value) -> String

    @State private var scrolled: Value?
    private let rowHeight: CGFloat = 38

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(items, id: \.self) { item in
                    Text(text(item))
                        .font(.waketide(fontSize, .bold, fixed: true))
                        .monospacedDigit()
                        .foregroundStyle(WaketideTheme.ink)
                        .frame(width: width, height: rowHeight)
                        .visualEffect { content, proxy in
                            let viewport = proxy.bounds(of: .scrollView)?.height ?? height
                            let mid = proxy.frame(in: .scrollView).midY
                            let d = abs(mid - viewport / 2) / rowHeight
                            let scale = d <= 1 ? 1 - 0.37 * d : max(0.4, 0.63 - 0.16 * (d - 1))
                            let alpha = d <= 1 ? 1 - 0.45 * d : max(0, 0.55 - 0.27 * (d - 1))
                            return content.scaleEffect(scale).opacity(alpha)
                        }
                        .id(item)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrolled, anchor: .center)
        .contentMargins(.vertical, (height - rowHeight) / 2, for: .scrollContent)
        .frame(width: width, height: height)
        .onAppear { scrolled = selection }
        .onChange(of: scrolled) { _, value in
            if let value, value != selection {
                selection = value
                Feedback.tick()
            }
        }
        .onChange(of: selection) { _, value in
            if scrolled != value { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { scrolled = value } }
        }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(text(selection))
        .accessibilityAdjustableAction { direction in
            guard let i = items.firstIndex(of: selection) else { return }
            switch direction {
            case .increment: if i + 1 < items.count { selection = items[i + 1] }
            case .decrement: if i > 0 { selection = items[i - 1] }
            @unknown default: break
            }
        }
    }
}

/// The glass lens behind the centred row (`.lens`).
struct WheelLens: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        Capsule()
            .fill(LinearGradient(colors: dark ? [Color.white.opacity(0.16), Color.white.opacity(0.06)]
                                              : [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(Capsule().strokeBorder(Color.white.opacity(dark ? 0.22 : 0.95), lineWidth: 1))
            .outlineShadow(Capsule(), color: Color(hex: 0x5B52E0).opacity(dark ? 0.35 : 0.25), radius: 9, y: 6)
            .frame(height: 48)
            .padding(.horizontal, 14)
            .accessibilityHidden(true)
    }
}
