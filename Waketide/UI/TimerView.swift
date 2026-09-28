import SwiftUI

// MARK: - Liquid Vessel

/// The glass vessel from the design (`.vessel`): liquid that drains as time passes. The liquid is two
/// large, slowly turning rounded squares whose top edges read as waves.
struct LiquidVessel: View {
    let fraction: Double
    let timeText: String
    let caption: String
    let a11y: String
    var size: CGFloat = 272
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let level = min(max(fraction, 0), 1)
        let top = 0.08 + (1 - level) * 0.92
        let lightText = top < 0.55
        let dark = colorScheme == .dark
        ZStack {
            Circle()
                .fill(WaketideTheme.cssGradient(160, colors: dark
                    ? [Color.white.opacity(0.14), Color.white.opacity(0.04)]
                    : [Color.white.opacity(0.7), Color.white.opacity(0.25)]))
                .background(Circle().fill(.ultraThinMaterial))
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let wave = size * 560 / 272
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: wave * 0.40, style: .continuous)
                        .fill(Color(hex: 0x8FE8D8).opacity(0.55))
                        .frame(width: wave, height: wave)
                        .rotationEffect(.degrees(-(t / 15 * 360).truncatingRemainder(dividingBy: 360)))
                        .offset(y: size * (top + 0.02))
                    RoundedRectangle(cornerRadius: wave * 0.42, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0x6F6CF0), Color(hex: 0x4B3FD6)], startPoint: .top, endPoint: .bottom))
                        .opacity(0.95)
                        .frame(width: wave, height: wave)
                        .rotationEffect(.degrees((t / 11 * 360).truncatingRemainder(dividingBy: 360)))
                        .offset(y: size * top)
                }
                .frame(width: size, height: size, alignment: .top)
            }
            .clipShape(Circle())
            Ellipse()
                .fill(LinearGradient(colors: [Color.white.opacity(0.7), Color.white.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: 120, height: 56)
                .rotationEffect(.degrees(-24))
                .offset(x: 36 + 60 - size / 2, y: 22 + 28 - size / 2)
                .allowsHitTesting(false)
            VStack(spacing: 6) {
                Text(timeText)
                    .font(.waketide(68, .heavy))
                    .tracking(-2.04)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(caption.uppercased())
                    .font(.ui(14, .bold))
                    .tracking(0.84)
                    .lineLimit(1)
            }
            .foregroundStyle(lightText ? Color.white : WaketideTheme.ink)
            .shadow(color: lightText ? Color(hex: 0x1E146E).opacity(0.45) : .clear, radius: 6, y: 2)
            .padding(.horizontal, 28)
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(Color.white.opacity(dark ? 0.18 : 0.85), lineWidth: 1))
        .outlineShadow(Circle(), color: dark ? Color.black.opacity(0.4) : Color(hex: 0x503CB4).opacity(0.25), radius: 25, y: 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Mini liquid ring (for timer cards)

private struct MiniRing: View {
    let fraction: Double
    let size: CGFloat = 52
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let level = min(max(fraction, 0), 1)
        let top = 0.08 + (1 - level) * 0.92
        ZStack {
            Circle().fill(Color.white.opacity(0.25))
            TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let wave = size * 560 / 272
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: wave * 0.40, style: .continuous)
                        .fill(Color(hex: 0x8FE8D8).opacity(0.7))
                        .frame(width: wave, height: wave)
                        .rotationEffect(.degrees(-(t / 15 * 360).truncatingRemainder(dividingBy: 360)))
                        .offset(y: size * (top + 0.02))
                    RoundedRectangle(cornerRadius: wave * 0.42, style: .continuous)
                        .fill(Color(hex: 0x6F6CF0))
                        .frame(width: wave, height: wave)
                        .rotationEffect(.degrees((t / 11 * 360).truncatingRemainder(dividingBy: 360)))
                        .offset(y: size * top)
                }
                .frame(width: size, height: size, alignment: .top)
            }
            .clipShape(Circle())
            Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Timer card (compact running timer)

private struct TimerCard: View {
    let timer: RunningTimer
    let onPause: () -> Void
    let onResume: () -> Void
    let onAddMinute: () -> Void
    let onCancel: () -> Void
    let onExpand: () -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.25)) { ctx in
            let remaining = timer.remaining(at: ctx.date)
            let finished = timer.isFinished(at: ctx.date)
            let fraction = timer.total > 0 ? remaining / timer.total : 0

            VStack(spacing: 0) {
                // Top row: ring + label + time
                HStack(spacing: 14) {
                    Button(action: onExpand) {
                        MiniRing(fraction: finished ? 0 : fraction)
                    }
                    .buttonStyle(PressScaleStyle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(timer.label)
                            .font(.ui(15, .bold))
                            .foregroundStyle(WaketideTheme.ink)
                            .lineLimit(1)
                        Text(finished ? "Time's up!" : (timer.isPaused ? "Paused" : "Remaining"))
                            .font(.ui(12, .medium))
                            .foregroundStyle(finished ? Color(hex: 0xE8557A) : WaketideTheme.inkSoft)
                    }

                    Spacer(minLength: 4)

                    Text(DateText.clock(remaining))
                        .font(.waketide(26, .heavy))
                        .tracking(-1)
                        .monospacedDigit()
                        .foregroundStyle(finished ? Color(hex: 0xE8557A) : WaketideTheme.ink)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                        .accessibilityLabel("\(DateText.countdown(remaining)) remaining")
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, finished ? 16 : 12)

                // Controls row
                if !finished {
                    Divider()
                        .background(Color.white.opacity(0.4))
                        .padding(.horizontal, 16)

                    HStack(spacing: 0) {
                        // Pause / Resume
                        cardButton(
                            icon: timer.isPaused ? .play : .pause,
                            label: timer.isPaused ? "Resume" : "Pause"
                        ) {
                            timer.isPaused ? onResume() : onPause()
                        }

                        Divider()
                            .frame(height: 28)
                            .background(Color.white.opacity(0.4))

                        // +1 min
                        cardTextButton(label: "+1 min", a11y: "Add one minute") {
                            onAddMinute()
                        }

                        Divider()
                            .frame(height: 28)
                            .background(Color.white.opacity(0.4))

                        // Cancel
                        cardButton(icon: .close, label: "Cancel") {
                            onCancel()
                        }
                        .foregroundStyle(Color(hex: 0xE8557A))
                    }
                    .frame(height: 44)
                } else {
                    // Done button
                    Button {
                        onCancel()
                    } label: {
                        HStack(spacing: 6) {
                            IconGlyph(icon: .check, size: 14, stroke: 2.6)
                            Text("Done").font(.ui(14, .bold))
                        }
                        .foregroundStyle(WaketideTheme.mintInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(PressScaleStyle())
                }
            }
            .glassCard(24)
            .shadow(color: finished ? Color(hex: 0xE8557A).opacity(0.2) : Color.clear, radius: 12, y: 4)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: finished)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: timer.isPaused)
        }
    }

    private func cardButton(icon: WTIcon, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            IconGlyph(icon: icon, size: 16)
                .foregroundStyle(WaketideTheme.iconInk)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(label)
    }

    private func cardTextButton(label: String, a11y: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.ui(13, .bold))
                .foregroundStyle(WaketideTheme.accentInk)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(a11y)
    }
}

// MARK: - Expanded single timer view (big vessel)

private struct ExpandedTimerView: View {
    let timer: RunningTimer
    let onPause: () -> Void
    let onResume: () -> Void
    let onAddMinute: () -> Void
    let onCancel: () -> Void
    let onDone: () -> Void
    let onCollapse: () -> Void

    private let presets: [(String, Int)] = [("1 min", 60), ("5 min", 300), ("10 min", 600), ("25 min", 1500)]

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.2)) { ctx in
            let remaining = timer.remaining(at: ctx.date)
            let finished = timer.isFinished(at: ctx.date)
            let fraction = timer.total > 0 ? remaining / timer.total : 0

            VStack(spacing: 20) {
                // Collapse handle
                Button(action: onCollapse) {
                    HStack(spacing: 6) {
                        IconGlyph(icon: .chevronLeft, size: 14)
                        Text("All timers").font(.ui(13, .bold))
                    }
                    .foregroundStyle(WaketideTheme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PressScaleStyle())

                LiquidVessel(
                    fraction: finished ? 0 : fraction,
                    timeText: DateText.clock(remaining),
                    caption: finished ? "Time's up" : (timer.isPaused ? timer.label + " · Paused" : timer.label),
                    a11y: finished ? "Time is up" : "\(DateText.countdown(remaining)) remaining, \(timer.label)"
                )

                if finished {
                    CTAButton(title: "Done", icon: .check) {
                        Feedback.saved()
                        onDone()
                    }
                } else {
                    // Preset quick-add chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(presets, id: \.1) { title, secs in
                                GlassPill(title: "+\(title)") {
                                    Feedback.tick()
                                    onAddMinute() // reuse but call with the specific seconds
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }

                    // Main controls
                    HStack(spacing: 24) {
                        roundControl(label: "Cancel timer", action: {
                            Feedback.delete()
                            onCancel()
                        }) {
                            IconGlyph(icon: .close, size: 26)
                        }

                        Button {
                            Feedback.press()
                            if timer.isPaused { onResume() } else { onPause() }
                        } label: {
                            IconGlyph(icon: timer.isPaused ? .play : .pause, size: 34)
                                .foregroundStyle(.white)
                                .frame(width: 88, height: 88)
                                .background {
                                    Circle().fill(WaketideTheme.brandGradient)
                                        .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
                                        .outlineShadow(Circle(), color: Color(hex: 0x5B52E0).opacity(0.5), radius: 15, y: 14)
                                }
                                .contentShape(Circle())
                        }
                        .buttonStyle(PressScaleStyle())
                        .accessibilityLabel(timer.isPaused ? "Resume timer" : "Pause timer")

                        roundControl(label: "Add one minute", action: {
                            Feedback.tick()
                            onAddMinute()
                        }) {
                            Text("+1").font(.ui(15, .bold))
                        }
                    }
                }
            }
        }
    }

    private func roundControl<Content: View>(label: String, action: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        Button(action: action) {
            content()
                .foregroundStyle(WaketideTheme.iconInk)
                .frame(width: 68, height: 68)
                .background(ControlSurface(shape: Circle()))
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(label)
    }
}

// MARK: - Timer Setup sheet

private struct TimerSetupSheet: View {
    @Binding var isPresented: Bool
    let onStart: (String, TimeInterval) -> Void

    @State private var hours = 0
    @State private var minutes = 5
    @State private var seconds = 0
    @State private var label = ""
    @State private var labelHistory: [String] = []

    private let presets: [(String, String, Int)] = [
        ("5 min", "Focus break", 300),
        ("10 min", "Quick break", 600),
        ("25 min", "Pomodoro", 1500),
        ("45 min", "Work block", 2700),
        ("1 hr", "Deep focus", 3600),
    ]

    private var duration: TimeInterval { TimeInterval(hours * 3600 + minutes * 60 + seconds) }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(WaketideTheme.inkSoft.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 20) {
                    // Title
                    HStack {
                        Text("New Timer")
                            .font(.waketide(28, .heavy))
                            .foregroundStyle(WaketideTheme.ink)
                        Spacer()
                        IconButton(icon: .close, label: "Cancel") { isPresented = false }
                    }
                    .padding(.horizontal, 20)

                    // Vessel preview
                    LiquidVessel(
                        fraction: 0.7,
                        timeText: DateText.clock(duration),
                        caption: label.isEmpty ? "Timer" : label,
                        a11y: "Timer set for \(DateText.countdown(duration))"
                    )

                    // Preset chips
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quick Start")
                            .font(.ui(12, .bold))
                            .foregroundStyle(WaketideTheme.eyebrow)
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                Spacer().frame(width: 10)
                                ForEach(presets, id: \.2) { time, name, secs in
                                    Button {
                                        Feedback.tick()
                                        hours = secs / 3600
                                        minutes = (secs % 3600) / 60
                                        seconds = secs % 60
                                        if label.isEmpty { label = name }
                                    } label: {
                                        VStack(spacing: 2) {
                                            Text(time)
                                                .font(.ui(14, .bold))
                                            Text(name)
                                                .font(.ui(11, .medium))
                                                .opacity(0.7)
                                        }
                                        .foregroundStyle(WaketideTheme.ink)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.7), lineWidth: 1))
                                    }
                                    .buttonStyle(PressScaleStyle())
                                }
                                Spacer().frame(width: 10)
                            }
                        }
                    }

                    // Wheel picker
                    ZStack {
                        WheelLens()
                        HStack(spacing: 0) {
                            WheelPicker(items: Array(0..<24), selection: $hours, label: "Hours", width: 100, height: 160, fontSize: 30) { "\($0) h" }
                            WheelPicker(items: Array(0..<60), selection: $minutes, label: "Minutes", width: 110, height: 160, fontSize: 30) { "\($0) min" }
                            WheelPicker(items: Array(0..<60), selection: $seconds, label: "Seconds", width: 100, height: 160, fontSize: 30) { "\($0) s" }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .glassCard(30)
                    .padding(.horizontal, 20)

                    // Label field
                    GlassRow {
                        Text("Label")
                            .font(.ui(13, .bold))
                            .foregroundStyle(WaketideTheme.eyebrow)
                            .frame(width: 54, alignment: .leading)
                        TextField("", text: $label, prompt: Text("Timer").foregroundStyle(WaketideTheme.inkSoft))
                            .font(.ui(16, .medium))
                            .foregroundStyle(WaketideTheme.ink)
                            .submitLabel(.done)
                    }
                    .padding(.horizontal, 20)

                    // Start button
                    CTAButton(title: "Start Timer", icon: .play) {
                        Feedback.saved()
                        onStart(label.isEmpty ? "Timer" : label, duration)
                        isPresented = false
                    }
                    .disabled(duration < 1)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(AuroraBackground().ignoresSafeArea())
    }
}

// MARK: - Main TimerView

struct TimerView: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var router: Router
    @State private var expandedID: UUID? = nil
    @State private var showSetup = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScreenHeader(title: "Timer") {
                    HStack(spacing: 6) {
                        IconButton(icon: .sparkle, label: "Ask Waketide", size: 22) { router.showAI = true }
                        if !store.timers.isEmpty {
                            IconButton(icon: .plus, label: "New timer") { showSetup = true }
                        }
                    }
                }

                if store.timers.isEmpty {
                    emptySetup
                } else if let id = expandedID, let t = store.timers.first(where: { $0.id == id }) {
                    expandedView(t)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    timerList
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                Text("Keeps counting on the Lock Screen and Dynamic Island")
                    .font(.ui(13, .medium))
                    .foregroundStyle(WaketideTheme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 2)
        }
        .contentMargins(.bottom, tabBarClearance, for: .scrollContent)
        .scrollIndicators(.hidden)
        .background(AuroraBackground())
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: expandedID)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: store.timers.count)
        .onChange(of: router.selectedTab) { _, tab in if tab == .timer { router.focusDay = nil } }
        .onChange(of: store.timers.map(\.id)) { _, ids in
            // If the expanded timer was removed, collapse
            if let id = expandedID, !ids.contains(id) { expandedID = nil }
        }
        .sheet(isPresented: $showSetup) {
            TimerSetupSheet(isPresented: $showSetup) { label, duration in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    let t = store.startTimer(label: label, duration: duration)
                    if store.timers.count == 1 { expandedID = t?.id }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
    }

    // MARK: Empty / Setup

    private var emptySetup: some View {
        VStack(spacing: 20) {
            // Static vessel preview driven by a local state
            EmptyTimerSetupPreview(onStart: { label, duration in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    let t = store.startTimer(label: label, duration: duration)
                    expandedID = t?.id
                }
            })
        }
    }

    // MARK: Timer list

    private var timerList: some View {
        VStack(spacing: 12) {
            ForEach(store.timers) { t in
                TimerCard(
                    timer: t,
                    onPause: { Feedback.tick(); store.pauseTimer(id: t.id) },
                    onResume: { Feedback.tick(); store.resumeTimer(id: t.id) },
                    onAddMinute: { Feedback.tick(); store.addToTimer(id: t.id, seconds: 60) },
                    onCancel: {
                        Feedback.delete()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            store.cancelTimer(id: t.id)
                        }
                    },
                    onExpand: {
                        Feedback.tick()
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { expandedID = t.id }
                    }
                )
                .transition(.scale(scale: 0.94).combined(with: .opacity))
            }

            // Add another timer button
            Button {
                Feedback.tick()
                showSetup = true
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(WaketideTheme.accentInk.opacity(0.12))
                            .frame(width: 40, height: 40)
                        IconGlyph(icon: .plus, size: 18)
                            .foregroundStyle(WaketideTheme.accentInk)
                    }
                    Text("Add another timer")
                        .font(.ui(15, .bold))
                        .foregroundStyle(WaketideTheme.accentInk)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 64)
                .glassCard(20)
            }
            .buttonStyle(PressScaleStyle())
        }
    }

    // MARK: Expanded single timer

    private func expandedView(_ t: RunningTimer) -> some View {
        ExpandedTimerView(
            timer: t,
            onPause: { Feedback.tick(); store.pauseTimer(id: t.id) },
            onResume: { Feedback.tick(); store.resumeTimer(id: t.id) },
            onAddMinute: { Feedback.tick(); store.addToTimer(id: t.id, seconds: 60) },
            onCancel: {
                Feedback.delete()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    store.cancelTimer(id: t.id)
                    expandedID = nil
                }
            },
            onDone: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    store.cancelTimer(id: t.id)
                    expandedID = nil
                }
            },
            onCollapse: {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { expandedID = nil }
            }
        )
    }
}

// MARK: - Empty state with inline picker

private struct EmptyTimerSetupPreview: View {
    let onStart: (String, TimeInterval) -> Void

    @State private var hours = 0
    @State private var minutes = 5
    @State private var seconds = 0
    @State private var label = ""

    private let presets: [(String, Int)] = [("1 min", 60), ("5 min", 300), ("10 min", 600), ("25 min", 1500)]

    private var duration: TimeInterval { TimeInterval(hours * 3600 + minutes * 60 + seconds) }

    var body: some View {
        VStack(spacing: 20) {
            LiquidVessel(
                fraction: 0.7,
                timeText: DateText.clock(duration),
                caption: label.isEmpty ? "Timer" : label,
                a11y: "Timer set for \(DateText.countdown(duration))"
            )

            // Presets
            HStack(spacing: 8) {
                ForEach(presets, id: \.1) { title, secs in
                    GlassPill(title: title, selected: Int(duration) == secs) {
                        Feedback.tick()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            hours = secs / 3600
                            minutes = (secs % 3600) / 60
                            seconds = secs % 60
                        }
                    }
                }
            }

            // Wheel picker
            ZStack {
                WheelLens()
                HStack(spacing: 0) {
                    WheelPicker(items: Array(0..<24), selection: $hours, label: "Hours", width: 100, height: 160, fontSize: 30) { "\($0) h" }
                    WheelPicker(items: Array(0..<60), selection: $minutes, label: "Minutes", width: 110, height: 160, fontSize: 30) { "\($0) min" }
                    WheelPicker(items: Array(0..<60), selection: $seconds, label: "Seconds", width: 100, height: 160, fontSize: 30) { "\($0) s" }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .glassCard(30)

            GlassRow {
                Text("Label")
                    .font(.ui(13, .bold))
                    .foregroundStyle(WaketideTheme.eyebrow)
                    .frame(width: 54, alignment: .leading)
                TextField("", text: $label, prompt: Text("Timer").foregroundStyle(WaketideTheme.inkSoft))
                    .font(.ui(16, .medium))
                    .foregroundStyle(WaketideTheme.ink)
                    .submitLabel(.done)
            }

            CTAButton(title: "Start Timer", icon: .play) {
                Feedback.saved()
                onStart(label.isEmpty ? "Timer" : label, duration)
            }
            .disabled(duration < 1)
        }
    }
}
