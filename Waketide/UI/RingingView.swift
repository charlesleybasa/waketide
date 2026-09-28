import SwiftUI

/// What people see when they open Waketide from a ringing alarm. The system alert itself is drawn by iOS.
struct RingingView: View {
    let alarm: WakeAlarm
    @EnvironmentObject private var store: AlarmStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragX: CGFloat = 0
    @State private var nudge = false

    private let handle: CGFloat = 64

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AuroraBackground(night: true)
                ripples
                    .position(x: geo.size.width / 2, y: geo.size.height * 330 / 844)
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.ui(16, .medium))
                            .foregroundStyle(.white.opacity(0.78))
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(alarm.timeText)
                                .font(.waketide(132, .heavy))
                                .tracking(-6.6)
                                .monospacedDigit()
                            if !alarm.meridiem.isEmpty {
                                Text(alarm.meridiem)
                                    .font(.waketide(30, .bold))
                            }
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(.white)
                        .shadow(color: Color(hex: 0x8C78FF).opacity(0.6), radius: 20, y: 8)
                        .padding(.top, 14)
                        Text(alarm.label)
                            .font(.waketide(26))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.top, 10)
                    }
                    .accessibilityElement(children: .combine)
                    .padding(.top, 40)
                    Spacer()
                    snoozeButton
                    slideToStop
                        .padding(.top, 12)
                        .padding(.bottom, 34)
                }
                .padding(.horizontal, 16)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { if !reduceMotion { nudge = true } }
    }

    private var ripples: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let p = (t / 4.8 + Double(i) / 3.0).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .stroke(Color(hex: 0xB4AAFF).opacity(0.5 * 1.8 * (1 - p)), lineWidth: 2)
                        .frame(width: 200, height: 200)
                        .scaleEffect(0.6 + 2.8 * p)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var snoozeButton: some View {
        Button {
            Feedback.press()
            store.snoozeRinging()
        } label: {
            HStack(spacing: 10) {
                IconGlyph(icon: .moon, size: 22)
                Text("Snooze \(alarm.snoozeMinutes) min")
            }
            .font(.ui(17, .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(DarkGlass(shape: Capsule()))
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle(scale: 0.97))
    }

    private var slideToStop: some View {
        GeometryReader { geo in
            let maxX = max(1, geo.size.width - handle - 12)
            ZStack(alignment: .leading) {
                DarkGlass(shape: Capsule())
                ShimmerText(text: "Slide to stop", paused: reduceMotion)
                    .opacity(max(0.15, 1 - Double(dragX / maxX)))
                    .frame(maxWidth: .infinity)
                    .padding(.leading, 56)
                IconGlyph(icon: .arrowRight, size: 28)
                    .foregroundStyle(.white)
                    .frame(width: handle, height: handle)
                    .background {
                        Circle().fill(WaketideTheme.coralGradient)
                            .overlay(Circle().strokeBorder(LinearGradient(colors: [Color.white.opacity(0.6), .clear], startPoint: .top, endPoint: .center), lineWidth: 2))
                            .shadow(color: Color(hex: 0xFF5F7A).opacity(0.55), radius: 11, y: 8)
                    }
                    .padding(.leading, 6)
                    .offset(x: dragX == 0 && nudge ? 14 : dragX)
                    .animation(dragX == 0 && !reduceMotion ? .easeInOut(duration: 1.3).repeatForever(autoreverses: true) : nil, value: nudge)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                nudge = false
                                let clamped = min(max(0, value.translation.width), maxX)
                                if Int(clamped / 24) != Int(dragX / 24) { Feedback.tick() }
                                dragX = clamped
                            }
                            .onEnded { _ in
                                if dragX > maxX * 0.85 {
                                    withAnimation(.spring) { dragX = maxX }
                                    Feedback.saved()
                                    store.stopRinging()
                                } else {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { dragX = 0 }
                                    if !reduceMotion { nudge = true }
                                }
                            }
                    )
            }
        }
        .frame(height: 76)
        .accessibilityRepresentation {
            Button("Stop alarm") { store.stopRinging() }
        }
    }
}

/// Glass on the night background (`.dg`).
private struct DarkGlass<S: InsettableShape>: View {
    let shape: S

    var body: some View {
        shape.fill(.ultraThinMaterial)
            .overlay(shape.fill(WaketideTheme.cssGradient(135, colors: [Color.white.opacity(0.2), Color.white.opacity(0.06)])))
            .overlay(shape.strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
            .overlay(shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.4), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.15)), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 17, y: 14)
            .environment(\.colorScheme, .dark)
    }
}

/// "Slide to stop" with a light band passing over it (`.trk span`).
private struct ShimmerText: View {
    let text: String
    let paused: Bool

    var body: some View {
        TimelineView(.animation(paused: paused)) { context in
            let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.6) / 2.6
            Text(text)
                .font(.ui(17, .bold))
                .foregroundStyle(.white.opacity(0.55))
                .overlay {
                    GeometryReader { geo in
                        LinearGradient(colors: [.clear, .white, .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * 0.6)
                            .offset(x: -geo.size.width * 0.6 + (geo.size.width * 1.6) * t)
                    }
                    .mask(Text(text).font(.ui(17, .bold)))
                }
        }
    }
}
