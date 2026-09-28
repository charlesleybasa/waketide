import WidgetKit
import SwiftUI
import AlarmKit
import ActivityKit
import AppIntents

/// Lock Screen and Dynamic Island for Waketide alarms and timers, from the design's
/// "Dynamic Island and Lock Screen" board.
struct WaketideAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<WaketideMetadata>.self) { context in
            LockScreenCard(state: context.state, meta: Meta(context.attributes.metadata))
                .activityBackgroundTint(Color(hex: 0x14112E).opacity(0.72))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let meta = Meta(context.attributes.metadata)
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        StateTime(state: state, meta: meta)
                            .font(.waketide(46, .heavy, fixed: true))
                            .tracking(-1.38)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(meta.label)
                            .font(.ui(15, .medium, fixed: true))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                    .padding(.leading, 6)
                    .dynamicIsland(verticalPlacement: .belowIfTooWide)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StateIcon(state: state, meta: meta, size: 26)
                        .foregroundStyle(WaketideTheme.islandLilac)
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ActionButtons(state: state, meta: meta, style: .island)
                        .padding(.top, 8)
                }
            } compactLeading: {
                StateIcon(state: state, meta: meta, size: 18)
                    .foregroundStyle(WaketideTheme.islandLilac)
            } compactTrailing: {
                StateTime(state: state, meta: meta)
                    .font(.waketide(16, .bold, fixed: true))
                    .monospacedDigit()
                    .foregroundStyle(WaketideTheme.islandLilac)
                    .frame(maxWidth: 58)
            } minimal: {
                StateIcon(state: state, meta: meta, size: 18)
                    .foregroundStyle(WaketideTheme.islandLilac)
            }
            .keylineTint(WaketideTheme.islandLilac)
        }
    }
}

struct Meta {
    let label: String
    let isTimer: Bool

    init(_ meta: WaketideMetadata?) {
        label = meta?.label ?? "Alarm"
        isTimer = meta?.isTimer ?? false
    }
}

/// Countdown, paused remainder, or the alarm's time.
struct StateTime: View {
    let state: AlarmPresentationState
    let meta: Meta

    var body: some View {
        switch state.mode {
        case .countdown(let countdown):
            Text(timerInterval: Date.now...max(Date.now, countdown.fireDate), countsDown: true)
        case .paused(let paused):
            Text(Self.clock(paused.totalCountdownDuration - paused.previouslyElapsedDuration))
        case .alert(let alert):
            Text(Self.time(hour: alert.time.hour, minute: alert.time.minute))
        @unknown default:
            Text("")
        }
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    static func time(hour: Int, minute: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour; comps.minute = minute
        let date = Calendar.current.date(from: comps) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

struct StateIcon: View {
    let state: AlarmPresentationState
    let meta: Meta
    var size: CGFloat = 20

    var body: some View {
        switch state.mode {
        case .paused:
            IconGlyph(icon: .pause, size: size)
        case .alert:
            IconGlyph(icon: .bell, size: size)
        default:
            IconGlyph(icon: meta.isTimer ? .timer : .bell, size: size)
        }
    }
}

/// Status text in the card's top row ("Rings in 4:12", "Paused", "Ringing").
struct StatusText: View {
    let state: AlarmPresentationState
    let meta: Meta

    var body: some View {
        switch state.mode {
        case .countdown(let countdown):
            HStack(spacing: 4) {
                Text(meta.isTimer ? "Ends in" : "Rings in")
                Text(timerInterval: Date.now...max(Date.now, countdown.fireDate), countsDown: true)
                    .monospacedDigit()
                    .frame(maxWidth: 56, alignment: .leading)
            }
        case .paused:
            Text("Paused")
        case .alert:
            Text(meta.isTimer ? "Time's up" : "Ringing")
        @unknown default:
            Text("")
        }
    }
}

/// Snooze or pause/resume, and Stop, as Live Activity intents.
struct ActionButtons: View {
    enum Style { case island, card }
    let state: AlarmPresentationState
    let meta: Meta
    let style: Style

    var body: some View {
        let id = state.alarmID
        HStack(spacing: 10) {
            switch state.mode {
            case .alert:
                if !meta.isTimer {
                    button(SnoozeAlarmIntent(id: id), icon: .moon, title: "Snooze", primary: false)
                }
            case .countdown:
                if meta.isTimer {
                    button(PauseTimerIntent(id: id), icon: .pause, title: "Pause", primary: false)
                }
            case .paused:
                button(ResumeTimerIntent(id: id), icon: .play, title: "Resume", primary: false)
            @unknown default:
                EmptyView()
            }
            button(StopAlarmIntent(id: id), icon: .close, title: "Stop", primary: true)
        }
    }

    @ViewBuilder
    private func button<I: LiveActivityIntent>(_ intent: I, icon: WTIcon, title: String, primary: Bool) -> some View {
        Button(intent: intent) {
            if style == .island {
                HStack(spacing: 8) {
                    if !primary { IconGlyph(icon: icon, size: 20) }
                    Text(title)
                }
                .font(.ui(16, .bold, fixed: true))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Capsule().fill(primary ? AnyShapeStyle(WaketideTheme.coralGradient) : AnyShapeStyle(Color.white.opacity(0.16))))
            } else {
                IconGlyph(icon: icon, size: 20)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle().fill(primary ? AnyShapeStyle(WaketideTheme.coralGradient) : AnyShapeStyle(Color.white.opacity(0.18)))
                            .overlay(Circle().strokeBorder(Color.white.opacity(primary ? 0.4 : 0.3), lineWidth: 1))
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct LockScreenCard: View {
    let state: AlarmPresentationState
    let meta: Meta

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image("AppGlyph")
                    .resizable()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text("Waketide")
                Spacer()
                StatusText(state: state, meta: meta)
            }
            .font(.ui(13, .bold, fixed: true))
            .foregroundStyle(.white.opacity(0.8))
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 0) {
                    StateTime(state: state, meta: meta)
                        .font(.waketide(30, .heavy, fixed: true))
                        .tracking(-0.6)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(meta.label)
                        .font(.ui(14, .medium, fixed: true))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                }
                Spacer()
                ActionButtons(state: state, meta: meta, style: .card)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
