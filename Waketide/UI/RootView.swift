import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case week, schedule, plans, timer

    var title: String {
        switch self {
        case .week: return "Week"
        case .schedule: return "Schedule"
        case .plans: return "Plans"
        case .timer: return "Timer"
        }
    }

    var icon: WTIcon {
        switch self {
        case .week: return .alarm
        case .schedule: return .calendar
        case .plans: return .list
        case .timer: return .timer
        }
    }
}

@MainActor
final class Router: ObservableObject {
    @Published var selectedTab: AppTab = {
        // Allow screenshot automation to pick the starting tab via
        // `xcrun simctl launch … --args -screenshot_tab timer`
        if let override = UserDefaults.standard.string(forKey: "screenshot_tab"),
           let tab = AppTab.allCases.first(where: { $0.title.lowercased() == override.lowercased() }) {
            return tab
        }
        return .week
    }()
    @Published var editing: WakeAlarm?
    @Published var showAI: Bool = {
        return UserDefaults.standard.bool(forKey: "screenshot_ai")
    }()
    /// The day the visible screen is showing, so the plus button adds to it.
    @Published var focusDay: Date?

    func newAlarm(on date: Date? = nil) {
        var alarm = WakeAlarm(label: "Alarm", hour: 7, minute: 0)
        alarm.date = date
        editing = alarm
    }

    /// New alarm on the day the current screen shows (today means "next time it reaches").
    func newAlarmForFocus() {
        guard selectedTab != .timer, let day = focusDay, !Calendar.current.isDateInToday(day) else {
            newAlarm()
            return
        }
        newAlarm(on: Calendar.current.startOfDay(for: day))
    }

    func edit(_ alarm: WakeAlarm) {
        editing = alarm
    }
}

/// Space the floating tab bar needs at the bottom of scrolling content (above the safe area).
let tabBarClearance: CGFloat = 84

struct RootView: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var router: Router

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $router.selectedTab) {
                Tab(value: AppTab.week) { WeekView().toolbarVisibility(.hidden, for: .tabBar) }
                Tab(value: AppTab.schedule) { ScheduleView().toolbarVisibility(.hidden, for: .tabBar) }
                Tab(value: AppTab.plans) { PlansView().toolbarVisibility(.hidden, for: .tabBar) }
                Tab(value: AppTab.timer) { TimerView().toolbarVisibility(.hidden, for: .tabBar) }
            }
            WaketideTabBar()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(.container, edges: .bottom)
                .ignoresSafeArea(.keyboard)
        }
        .tint(WaketideTheme.indigo)
        .sheet(item: $router.editing) { alarm in
            AlarmEditorView(alarm: alarm)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(38)
        }
        .sheet(isPresented: $router.showAI) {
            AskAIView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(38)
        }
        .fullScreenCover(item: $store.ringing) { alarm in
            RingingView(alarm: alarm)
        }
        .overlay(alignment: .top) { PermissionBanner() }
        .overlay(alignment: .bottom) { ToastHost().padding(.bottom, tabBarClearance) }
    }
}

/// The canvas's tab bar: a glass capsule whose bubble slides between tabs, and the plus button.
private struct WaketideTabBar: View {
    @EnvironmentObject private var router: Router
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var bubble

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            .padding(6)
            .frame(height: 68)
            .glassCapsule()

            Button {
                Feedback.press()
                router.newAlarmForFocus()
            } label: {
                IconGlyph(icon: .plus, size: 30)
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background {
                        Circle().fill(WaketideTheme.brandGradient)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
                            .overlay(Circle().strokeBorder(LinearGradient(colors: [Color.white.opacity(0.6), .clear], startPoint: .top, endPoint: .center), lineWidth: 2))
                            .outlineShadow(Circle(), color: Color(hex: 0x5B52E0).opacity(0.5), radius: 14, y: 12)
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(PressScaleStyle(scale: 0.9))
            .accessibilityLabel("New alarm")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let on = router.selectedTab == tab
        return Button {
            guard !on else { return }
            Feedback.tick()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.68)) { router.selectedTab = tab }
        } label: {
            VStack(spacing: 2) {
                IconGlyph(icon: tab.icon, size: 22)
                Text(tab.title).font(.ui(11, .bold, fixed: true))
            }
            .foregroundStyle(on ? WaketideTheme.accentInk : WaketideTheme.tabIdle)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                if on {
                    Capsule()
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.78))
                        .overlay(Capsule().strokeBorder(LinearGradient(colors: [Color.white.opacity(colorScheme == .dark ? 0.3 : 1), .clear], startPoint: .top, endPoint: .center), lineWidth: 1))
                        .outlineShadow(Capsule(), color: Color(hex: 0x5B52E0).opacity(0.28), radius: 7, y: 4)
                        .matchedGeometryEffect(id: "bubble", in: bubble)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
    }
}

/// Top-of-screen prompt when alarms are not allowed yet.
private struct PermissionBanner: View {
    @EnvironmentObject private var store: AlarmStore

    var body: some View {
        if store.permissionDenied {
            HStack(spacing: 12) {
                IconGlyph(icon: .bell, size: 20)
                    .foregroundStyle(WaketideTheme.coral)
                Text("Allow Waketide alarms so they can ring on a silent iPhone.")
                    .font(.ui(14, .bold))
                    .foregroundStyle(WaketideTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                GlassPill(title: "Settings", selected: true) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .padding(14)
            .glassCard(24)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// Toasts: general messages and the delete-undo bar.
private struct ToastHost: View {
    @EnvironmentObject private var store: AlarmStore
    @State private var visibleBanner: String?

    var body: some View {
        VStack(spacing: 10) {
            if let deleted = store.lastDeleted {
                HStack(spacing: 12) {
                    Text("Deleted \(deleted.label)")
                        .font(.ui(15, .bold))
                        .foregroundStyle(WaketideTheme.ink)
                        .lineLimit(1)
                    GlassPill(title: "Undo", icon: .undo, selected: true) {
                        withAnimation(.spring) { store.undoDelete() }
                    }
                }
                .padding(.leading, 18)
                .padding(.trailing, 6)
                .padding(.vertical, 6)
                .glassCapsule()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let text = visibleBanner {
                Text(text)
                    .font(.ui(15, .bold))
                    .foregroundStyle(WaketideTheme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .glassCard(22)
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: store.lastDeleted?.id)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: visibleBanner)
        .onChange(of: store.banner) { _, new in
            guard let new else { return }
            visibleBanner = new
            store.banner = nil
            Task {
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                if visibleBanner == new { visibleBanner = nil }
            }
        }
    }
}
