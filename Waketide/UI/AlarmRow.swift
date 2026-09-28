import SwiftUI

/// One alarm on the rail (`.acard`): time, label, switch, edit and delete.
struct AlarmRow: View {
    let alarm: WakeAlarm
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var router: Router

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { alarm.isEnabled },
            set: { on in
                Feedback.toggle(on: on)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    store.setEnabled(alarm, on)
                }
            }
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(alarm.timeText)
                        .font(.waketide(30))
                        .tracking(-0.6)
                        .monospacedDigit()
                        .foregroundStyle(WaketideTheme.ink)
                    if !alarm.meridiem.isEmpty {
                        Text(alarm.meridiem)
                            .font(.waketide(14))
                            .foregroundStyle(WaketideTheme.eyebrow)
                    }
                }
                Text(alarm.label)
                    .font(.ui(13, .medium))
                    .foregroundStyle(WaketideTheme.inkSoft)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { router.edit(alarm) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(alarm.accessibilityText)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens the alarm editor")
            .accessibilityAction { router.edit(alarm) }

            WaketideToggle(isOn: enabledBinding, label: "Alarm \(alarm.label)")

            IconButton(icon: .pencil, label: "Edit \(alarm.label)") {
                router.edit(alarm)
            }
            IconButton(icon: .trash, label: "Delete \(alarm.label)") {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    store.delete(alarm)
                }
                Feedback.delete()
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .frame(minHeight: 84)
        .glassCard(26)
        .opacity(alarm.isEnabled ? 1 : 0.72)
    }
}

/// Alarm cards joined by the timeline rail (`.list` with `.rail` and `.dot`).
struct AlarmRail: View {
    let alarms: [WakeAlarm]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(alarms) { alarm in
                AlarmRow(alarm: alarm)
                    .overlay(alignment: .topLeading) {
                        RailDot(on: alarm.isEnabled)
                            .offset(x: -26, y: 34)
                    }
                    .transition(.asymmetric(insertion: .scale(scale: 0.8).combined(with: .opacity), removal: .opacity))
            }
        }
        .padding(.leading, 28)
        .background(alignment: .leading) {
            if !alarms.isEmpty {
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: 0x5B52E0).opacity(0.55), Color(hex: 0x5B52E0).opacity(0.1)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 3)
                    .padding(.leading, 9)
                    .padding(.vertical, 6)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: alarms.map { $0.id })
    }
}

private struct RailDot: View {
    let on: Bool

    var body: some View {
        Circle()
            .fill(on ? Color(hex: 0x5B52E0) : WaketideTheme.surface)
            .overlay(Circle().strokeBorder(on ? Color.white : Color(hex: 0x5B52E0).opacity(0.4), lineWidth: 2))
            .background {
                if on { Circle().fill(Color(hex: 0x5B52E0).opacity(0.22)).padding(-4) }
            }
            .frame(width: 14, height: 14)
            .accessibilityHidden(true)
    }
}

struct EmptyDayCard: View {
    let title: String
    @EnvironmentObject private var router: Router
    var addAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            IconGlyph(icon: .moon, size: 30)
                .foregroundStyle(WaketideTheme.indigo)
            Text(title)
                .font(.waketide(20))
                .foregroundStyle(WaketideTheme.ink)
                .multilineTextAlignment(.center)
            Text("Add an alarm, or just say it and Waketide will set it up.")
                .font(.ui(14, .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(WaketideTheme.inkSoft)
            HStack(spacing: 10) {
                GlassPill(title: "Add alarm", icon: .plus, action: addAction)
                GlassPill(title: "Say it", icon: .sparkle) { router.showAI = true }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassCard(28)
    }
}
