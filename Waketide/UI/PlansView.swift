import SwiftUI

private struct PlacedAlarm: Identifiable {
    let alarm: WakeAlarm
    let column: Int
    let tint: Int
    var id: UUID { alarm.id }
}

private struct FreeSlot: Identifiable {
    let startMinutes: Int
    let endMinutes: Int
    var id: Int { startMinutes }
}

struct PlansView: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var router: Router
    @State private var selected = Date()

    /// The timeline starts here; anything earlier is summarised in the pill above it.
    private let startHour = 5
    private let hourHeight: CGFloat = 64
    private var calendar: Calendar { .current }

    private var alarmsForDay: [WakeAlarm] { store.alarms(on: selected) }
    private var early: [WakeAlarm] { alarmsForDay.filter { $0.hour < startHour } }
    private var onTimeline: [WakeAlarm] { alarmsForDay.filter { $0.hour >= startHour } }

    private func effectiveMinutes(_ a: WakeAlarm) -> Int { max(a.durationMinutes, 40) }

    /// Greedy column assignment so overlapping plans sit side by side.
    private func place(_ alarms: [WakeAlarm]) -> (placed: [PlacedAlarm], columns: Int) {
        var columnEnds: [Int] = []
        var placed: [PlacedAlarm] = []
        for (index, a) in alarms.sorted(by: { $0.minutesSinceMidnight < $1.minutesSinceMidnight }).enumerated() {
            let start = a.minutesSinceMidnight
            if let idx = columnEnds.firstIndex(where: { $0 <= start }) {
                columnEnds[idx] = start + effectiveMinutes(a)
                placed.append(PlacedAlarm(alarm: a, column: idx, tint: index % 3))
            } else {
                columnEnds.append(start + effectiveMinutes(a))
                placed.append(PlacedAlarm(alarm: a, column: columnEnds.count - 1, tint: index % 3))
            }
        }
        return (placed, max(1, columnEnds.count))
    }

    /// Gaps of two hours or more between plans, offered as "tap to plan".
    private func freeSlots(_ alarms: [WakeAlarm]) -> [FreeSlot] {
        let sorted = alarms.sorted { $0.minutesSinceMidnight < $1.minutesSinceMidnight }
        var slots: [FreeSlot] = []
        var end = -1
        for a in sorted {
            if end >= 0, a.minutesSinceMidnight - end >= 120 {
                slots.append(FreeSlot(startMinutes: end, endMinutes: a.minutesSinceMidnight))
            }
            end = max(end, a.minutesSinceMidnight + effectiveMinutes(a))
        }
        return slots
    }

    private var scrollTargetHour: Int {
        if let first = onTimeline.map(\.hour).min() { return max(startHour, first) }
        if calendar.isDateInToday(selected) { return max(startHour, calendar.component(.hour, from: Date()) - 1) }
        return startHour
    }

    var body: some View {
        VStack(spacing: 12) {
            ScreenHeader(title: "Plans") {
                IconButton(icon: .sparkle, label: "Ask Waketide", size: 22) { router.showAI = true }
            }
            DayStrip(selected: $selected, days: currentWeek()) { day in
                !store.alarms(on: day).isEmpty
            }
            if !early.isEmpty { earlyPill }
            timelineCard
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 100)
        .ignoresSafeArea(edges: .bottom)
        .background(AuroraBackground())
        .onAppear { router.focusDay = selected }
        .onChange(of: selected) { _, day in router.focusDay = day }
        .onChange(of: router.selectedTab) { _, tab in if tab == .plans { router.focusDay = selected } }
    }

    private var earlyPill: some View {
        let first = early[0]
        let more = early.count > 1 ? ", +\(early.count - 1) more" : ""
        return Button { router.edit(first) } label: {
            HStack(spacing: 10) {
                IconGlyph(icon: .moon, size: 18, stroke: 2)
                Text("Before \(hourLabel(startHour)): \(first.label) at \(first.fullTimeText)\(more)")
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .font(.ui(14, .bold))
            .foregroundStyle(WaketideTheme.pillInk)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .glassCapsule()
        }
        .buttonStyle(PressScaleStyle(scale: 0.97))
    }

    private var timelineCard: some View {
        ScrollViewReader { proxy in
            ScrollView {
                timeline
            }
            .scrollIndicators(.hidden)
            .onAppear { proxy.scrollTo("hour-\(scrollTargetHour)", anchor: .top) }
            .onChange(of: selected) { _, _ in
                withAnimation(.easeInOut) { proxy.scrollTo("hour-\(scrollTargetHour)", anchor: .top) }
            }
        }
        .frame(maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .glassCard(30)
    }

    private var timeline: some View {
        let result = place(onTimeline)
        let slots = freeSlots(onTimeline)
        let hours = Array(startHour..<24)
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(hours, id: \.self) { h in
                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(WaketideTheme.hex(0x50468C, 0.16))
                            .frame(height: 1)
                        Text(hourLabel(h))
                            .font(.ui(12, .bold, fixed: true))
                            .foregroundStyle(WaketideTheme.eyebrow)
                            .frame(width: 46, alignment: .leading)
                            .offset(x: 14, y: 6)
                    }
                    .frame(height: hourHeight, alignment: .top)
                    .id("hour-\(h)")
                }
            }
            GeometryReader { geo in
                let left: CGFloat = 72
                let available = max(0, geo.size.width - left - 12)
                let colWidth = available / CGFloat(result.columns)
                ZStack(alignment: .topLeading) {
                    ForEach(slots) { slot in
                        freeBlock(slot)
                            .frame(width: available, height: max(44, y(slot.endMinutes) - y(slot.startMinutes) - 20))
                            .offset(x: left, y: y(slot.startMinutes) + 10)
                    }
                    ForEach(result.placed) { p in
                        planBlock(p)
                            .frame(width: colWidth - (result.columns > 1 ? 6 : 0), height: blockHeight(p.alarm))
                            .offset(x: left + CGFloat(p.column) * colWidth, y: y(p.alarm.minutesSinceMidnight) + 2)
                    }
                    if calendar.isDateInToday(selected) {
                        let now = calendar.component(.hour, from: Date()) * 60 + calendar.component(.minute, from: Date())
                        if now >= startHour * 60 {
                            NowLine()
                                .frame(width: geo.size.width - 60)
                                .offset(x: 60, y: y(now) - 1)
                        }
                    }
                }
            }
        }
        .frame(height: hourHeight * CGFloat(hours.count) + 8)
    }

    private func y(_ minutes: Int) -> CGFloat {
        CGFloat(minutes - startHour * 60) / 60 * hourHeight
    }

    private func blockHeight(_ a: WakeAlarm) -> CGFloat {
        max(44, CGFloat(a.durationMinutes) / 60 * hourHeight - 4)
    }

    private func hourLabel(_ h: Int) -> String {
        if WakeAlarm.uses24HourClock { return String(format: "%02d:00", h) }
        let hour12 = h % 12 == 0 ? 12 : h % 12
        return "\(hour12) \(h < 12 ? "AM" : "PM")"
    }

    private func planBlock(_ p: PlacedAlarm) -> some View {
        let a = p.alarm
        let tint: UInt32 = [0x9A9BF7, 0x8FE8D8, 0xFFC7A0][p.tint]
        let alphas: [(Double, Double)] = [(0.7, 0.32), (0.75, 0.35), (0.8, 0.38)]
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return Button { router.edit(a) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(a.label)
                    .font(.waketide(18))
                    .tracking(-0.18)
                    .foregroundStyle(WaketideTheme.ink)
                    .lineLimit(1)
                Text(a.rangeText)
                    .font(.ui(13, .medium))
                    .foregroundStyle(WaketideTheme.inkSoft)
                    .lineLimit(1)
            }
            .padding(.leading, 14)
            .padding(.trailing, 36)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .topTrailing) {
                IconGlyph(icon: .bell, size: 18)
                    .foregroundStyle(WaketideTheme.accentInk)
                    .padding(.top, 10)
                    .padding(.trailing, 12)
            }
            .background {
                PlanBlockSurface(shape: shape, tint: tint, alphas: alphas[p.tint])
            }
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle(scale: 0.97))
        .opacity(a.isEnabled ? 1 : 0.6)
        .accessibilityLabel(a.accessibilityText)
    }

    private func freeBlock(_ slot: FreeSlot) -> some View {
        let length = slot.endMinutes - slot.startMinutes
        let h = length / 60, m = length % 60
        let text = m == 0 ? "\(h) h" : "\(h) h \(m) min"
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return Button {
            Feedback.tick()
            let start = ((slot.startMinutes + 14) / 15) * 15
            var alarm = WakeAlarm(label: "Plan", hour: (start / 60) % 24, minute: start % 60)
            alarm.date = calendar.startOfDay(for: selected)
            alarm.durationMinutes = 60
            router.edit(alarm)
        } label: {
            HStack(spacing: 8) {
                IconGlyph(icon: .plus, size: 16)
                Text("Open for \(text), tap to plan")
            }
            .font(.ui(13, .bold))
            .foregroundStyle(WaketideTheme.accentInk)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(shape.strokeBorder(Color(hex: 0x5B52E0).opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle(scale: 0.97))
    }
}

/// A plan block: its tint over frosted glass, with the glass edge and shadow.
private struct PlanBlockSurface: View {
    let shape: RoundedRectangle
    let tint: UInt32
    let alphas: (Double, Double)
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        let k = dark ? 0.55 : 1
        shape.fill(.ultraThinMaterial)
            .overlay(shape.fill(WaketideTheme.cssGradient(135, colors: [Color(hex: tint).opacity(alphas.0 * k), Color(hex: tint).opacity(alphas.1 * k)])))
            .overlay(shape.strokeBorder(Color.white.opacity(dark ? 0.18 : 0.78), lineWidth: 1))
            .outlineShadow(shape, color: dark ? Color.black.opacity(0.3) : Color(hex: 0x503CA0).opacity(0.14), radius: 12, y: 8)
    }
}

/// Coral "now" line with a pulsing dot.
private struct NowLine: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(WaketideTheme.nowLine).frame(height: 2)
            Circle()
                .fill(WaketideTheme.nowLine.opacity(pulse ? 0 : 0.45))
                .frame(width: pulse ? 36 : 12, height: pulse ? 36 : 12)
                .offset(x: pulse ? -18 : -6)
                .animation(reduceMotion ? nil : .easeOut(duration: 2.4).repeatForever(autoreverses: false), value: pulse)
            Circle()
                .fill(WaketideTheme.nowLine)
                .frame(width: 12, height: 12)
                .offset(x: -6)
        }
        .overlay(alignment: .topTrailing) {
            Text("NOW")
                .font(.ui(11, .bold, fixed: true))
                .tracking(0.66)
                .foregroundStyle(WaketideTheme.nowInk)
                .offset(x: -12, y: -18)
        }
        .frame(height: 2)
        .onAppear { if !reduceMotion { pulse = true } }
        .accessibilityHidden(true)
    }
}
