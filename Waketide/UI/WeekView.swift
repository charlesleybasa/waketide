import SwiftUI

/// Seven days in a glass strip; the selected day wears the indigo bubble (`.days`).
struct DayStrip: View {
    @Binding var selected: Date
    let days: [Date]
    let hasAlarm: (Date) -> Bool
    @Namespace private var bubble

    private var calendar: Calendar { .current }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                let isSelected = calendar.isDate(day, inSameDayAs: selected)
                Button {
                    Feedback.tick()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { selected = day }
                } label: {
                    VStack(spacing: 2) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.ui(12, .medium, fixed: true))
                            .foregroundStyle(isSelected ? Color.white : WaketideTheme.dayInk)
                        Text("\(calendar.component(.day, from: day))")
                            .font(.waketide(20, .bold, fixed: true))
                            .foregroundStyle(isSelected ? Color.white : WaketideTheme.ink)
                        Circle()
                            .fill(hasAlarm(day) ? (isSelected ? Color.white : WaketideTheme.indigo) : Color.clear)
                            .frame(width: 5, height: 5)
                    }
                    .frame(width: 46, height: 64)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(WaketideTheme.selectedGradient)
                                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.55), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.2)), lineWidth: 1))
                                .outlineShadow(RoundedRectangle(cornerRadius: 20, style: .continuous), color: Color(hex: 0x5B52E0).opacity(0.4), radius: 10, y: 8)
                                .matchedGeometryEffect(id: "bubble", in: bubble)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month(.wide)) + (hasAlarm(day) ? ", has alarms" : ""))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(6)
        .glassCard(26)
    }
}

/// The current week, starting on the locale's first weekday.
func currentWeek(calendar: Calendar = .current, containing date: Date = Date()) -> [Date] {
    let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
}

/// Soft morphing blob in the corner of the hero card (`.heroblob`).
private struct HeroBlob: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var morph = false

    var body: some View {
        Ellipse()
            .fill(RadialGradient(colors: [Color(hex: 0x9A9BF7).opacity(0.65), Color(hex: 0x92EAD9).opacity(0.35)],
                                 center: UnitPoint(x: 0.3, y: 0.3), startRadius: 0, endRadius: 110))
            .frame(width: morph ? 158 : 150, height: morph ? 142 : 150)
            .rotationEffect(.degrees(morph ? 40 : 0))
            .blur(radius: 8)
            .animation(reduceMotion ? nil : .easeInOut(duration: 9).repeatForever(autoreverses: true), value: morph)
            .onAppear { if !reduceMotion { morph = true } }
            .accessibilityHidden(true)
    }
}

struct NextAlarmCard: View {
    @EnvironmentObject private var store: AlarmStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let onCount = store.alarms.filter { $0.isEnabled }.count
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                SectionEyebrow(text: "Next alarm")
                if let next = store.nextAlarm {
                    Text(next.alarm.fullTimeText)
                        .font(.waketide(42, .heavy))
                        .tracking(-1.26)
                        .foregroundStyle(WaketideTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(next.alarm.label)
                        .font(.ui(13, .medium))
                        .foregroundStyle(WaketideTheme.inkSoft)
                        .lineLimit(1)
                } else {
                    Text("None")
                        .font(.waketide(42, .heavy))
                        .tracking(-1.26)
                        .foregroundStyle(WaketideTheme.ink)
                    Text(store.alarms.isEmpty ? "Tap plus to add your first alarm" : "All alarms are off")
                        .font(.ui(13, .medium))
                        .foregroundStyle(WaketideTheme.inkSoft)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(spacing: 0) {
                Text("\(onCount)")
                    .font(.waketide(24, .heavy))
                    .foregroundStyle(WaketideTheme.accentInk)
                Text("of \(store.alarms.count) on")
                    .font(.ui(11, .bold, fixed: true))
                    .foregroundStyle(WaketideTheme.inkSoft)
            }
            .frame(width: 64, height: 64)
            .background {
                Circle().fill(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.6))
                    .overlay(Circle().strokeBorder(LinearGradient(colors: [Color.white.opacity(colorScheme == .dark ? 0.25 : 1), .clear], startPoint: .top, endPoint: .center), lineWidth: 1.5))
                    .outlineShadow(Circle(), color: Color(hex: 0x5B52E0).opacity(0.25), radius: 8, y: 6)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(onCount) of \(store.alarms.count) alarms on")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .background(alignment: .topTrailing) {
            HeroBlob().offset(x: 30, y: -40)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .glassCard(28)
    }
}

struct WeekView: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var router: Router
    @State private var selected = Date()

    private var calendar: Calendar { .current }
    private var alarmsForDay: [WakeAlarm] { store.alarms(on: selected) }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ScreenHeader(title: "Your Week") {
                    AppearanceMenu()
                    IconButton(icon: .sparkle, label: "Ask Waketide", size: 22) { router.showAI = true }
                }
                DayStrip(selected: $selected, days: currentWeek()) { day in
                    !store.alarms(on: day).isEmpty
                }
                NextAlarmCard()
                if alarmsForDay.isEmpty {
                    EmptyDayCard(title: "Nothing set for \(selected.formatted(.dateTime.weekday(.wide)))") {
                        router.newAlarmForFocus()
                    }
                } else {
                    AlarmRail(alarms: alarmsForDay)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
        }
        .contentMargins(.bottom, tabBarClearance, for: .scrollContent)
        .scrollIndicators(.hidden)
        .background(AuroraBackground())
        .onAppear { router.focusDay = selected }
        .onChange(of: selected) { _, day in router.focusDay = day }
        .onChange(of: router.selectedTab) { _, tab in if tab == .week { router.focusDay = selected } }
    }
}
