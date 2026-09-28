import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var router: Router
    @State private var month = Date()
    @State private var selected = Date()
    @Namespace private var bubble

    private var calendar: Calendar { .current }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private var gridDays: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let count = calendar.range(of: .day, in: .month, for: month)?.count else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let lead = (firstWeekday - calendar.firstWeekday + 7) % 7
        var out: [Date?] = Array(repeating: nil, count: lead)
        for d in 0..<count {
            out.append(calendar.date(byAdding: .day, value: d, to: interval.start))
        }
        return out
    }

    private func shiftMonth(_ delta: Int) {
        Feedback.tick()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            if let m = calendar.date(byAdding: .month, value: delta, to: month) { month = m }
        }
    }

    var body: some View {
        let list = store.alarms(on: selected)
        ScrollView {
            VStack(spacing: 12) {
                ScreenHeader(title: "Schedule") {
                    IconButton(icon: .sparkle, label: "Ask Waketide", size: 22) { router.showAI = true }
                }
                calendarCard
                HStack(alignment: .firstTextBaseline) {
                    Text(selected.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.waketide(18))
                        .foregroundStyle(WaketideTheme.ink)
                    Spacer()
                    SectionEyebrow(text: list.count == 1 ? "1 alarm" : "\(list.count) alarms")
                }
                .padding(.horizontal, 4)

                if list.isEmpty {
                    EmptyDayCard(title: "Nothing on this date") { router.newAlarmForFocus() }
                } else {
                    AlarmRail(alarms: list)
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
        .onChange(of: router.selectedTab) { _, tab in if tab == .schedule { router.focusDay = selected } }
    }

    private var calendarCard: some View {
        VStack(spacing: 0) {
            HStack {
                IconButton(icon: .chevronLeft, label: "Previous month") { shiftMonth(-1) }
                Spacer()
                Text(DateText.monthYear(month))
                    .font(.waketide(20))
                    .tracking(-0.2)
                    .foregroundStyle(WaketideTheme.ink)
                Spacer()
                IconButton(icon: .chevronRight, label: "Next month") { shiftMonth(1) }
            }
            .frame(height: 48)
            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                    Text(s)
                        .font(.ui(12, .bold, fixed: true))
                        .foregroundStyle(WaketideTheme.eyebrow)
                        .frame(maxWidth: .infinity, minHeight: 26)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .glassCard(30)
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selected)
        let count = store.alarms(on: day).count
        return Button {
            Feedback.tick()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { selected = day }
        } label: {
            VStack(spacing: 1) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.waketide(17, .bold, fixed: true))
                    .foregroundStyle(isSelected ? Color.white : WaketideTheme.ink)
                HStack(spacing: 2) {
                    ForEach(0..<min(count, 3), id: \.self) { _ in
                        Circle().fill(isSelected ? Color.white : Color(hex: 0x5B52E0)).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(WaketideTheme.selectedGradient)
                        .outlineShadow(RoundedRectangle(cornerRadius: 16, style: .continuous), color: Color(hex: 0x5B52E0).opacity(0.4), radius: 10, y: 8)
                        .matchedGeometryEffect(id: "bubble", in: bubble)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(.dateTime.day().month(.wide)) + (count > 0 ? ", \(count) alarm\(count == 1 ? "" : "s")" : ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
