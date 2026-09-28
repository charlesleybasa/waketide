import Foundation
import AlarmKit
import ActivityKit
import SwiftUI

/// AlarmKit's alarm state, mirrored so the store does not depend on AlarmKit types.
enum SystemAlarmState {
    case scheduled, countdown, paused, alerting
}

/// All AlarmKit calls live in this one file. AlarmKit is new (iOS 26), so if Xcode
/// flags a signature here, this is the only place to adjust. Search for "AlarmKit note".
@MainActor
final class AlarmScheduler {
    static let shared = AlarmScheduler()
    private let manager = AlarmManager.shared

    // MARK: Authorization

    func authorize() async -> Bool {
        switch manager.authorizationState {
        case .authorized:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                let state = try await manager.requestAuthorization()
                return state == .authorized
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    // MARK: Alarms

    func schedule(_ alarm: WakeAlarm) async throws {
        cancel(id: alarm.id)
        guard alarm.isEnabled else { return }

        let schedule: Alarm.Schedule
        if alarm.weekdays.isEmpty {
            guard let fire = alarm.nextFireDate() else { return }
            schedule = .fixed(fire)
        } else {
            let time = Alarm.Schedule.Relative.Time(hour: alarm.hour, minute: alarm.minute)
            let days = alarm.weekdays.sorted().compactMap { Self.weekday(for: $0) }
            schedule = .relative(Alarm.Schedule.Relative(time: time, repeats: .weekly(days)))
        }

        // AlarmKit note: if your Xcode reports `stopButton` as deprecated or removed,
        // delete that argument. The system then supplies the Stop button itself.
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alarm.label),
            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle"),
            secondaryButton: AlarmButton(text: "Snooze", textColor: .white, systemImageName: "moon.zzz"),
            secondaryButtonBehavior: .countdown
        )
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: WaketideMetadata(label: alarm.label),
            tintColor: WaketideTheme.brandIndigo
        )
        // AlarmKit note: argument order follows Apple's WWDC25 sample (countdownDuration first).
        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: TimeInterval(alarm.snoozeMinutes * 60)),
            schedule: schedule,
            attributes: attributes,
            sound: .default
        )
        _ = try await manager.schedule(id: alarm.id, configuration: configuration)
    }

    func cancel(id: UUID) {
        try? manager.cancel(id: id)
    }

    func stop(id: UUID) {
        try? manager.stop(id: id)
    }

    /// Starts the snooze countdown of a ringing alarm.
    func snooze(id: UUID) {
        try? manager.countdown(id: id)
    }

    // MARK: Timers

    func startTimer(id: UUID, label: String, duration: TimeInterval) async throws {
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: label),
            stopButton: AlarmButton(text: "Done", textColor: .white, systemImageName: "checkmark"),
            secondaryButton: nil,
            secondaryButtonBehavior: nil
        )
        let countdown = AlarmPresentation.Countdown(
            title: LocalizedStringResource(stringLiteral: label),
            pauseButton: AlarmButton(text: "Pause", textColor: WaketideTheme.brandIndigo, systemImageName: "pause.fill")
        )
        let paused = AlarmPresentation.Paused(
            title: "Paused",
            resumeButton: AlarmButton(text: "Resume", textColor: WaketideTheme.brandIndigo, systemImageName: "play.fill")
        )
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert, countdown: countdown, paused: paused),
            metadata: WaketideMetadata(label: label, isTimer: true),
            tintColor: WaketideTheme.brandIndigo
        )
        let configuration = AlarmManager.AlarmConfiguration.timer(
            duration: duration,
            attributes: attributes,
            sound: .default
        )
        _ = try await manager.schedule(id: id, configuration: configuration)
    }

    func pauseTimer(id: UUID) {
        try? manager.pause(id: id)
    }

    func resumeTimer(id: UUID) {
        try? manager.resume(id: id)
    }

    // MARK: State updates

    /// Emits the state of every alarm and timer AlarmKit knows about, each time the list changes.
    /// Ids that are missing have finished or been stopped.
    func stateUpdates() -> AsyncStream<[UUID: SystemAlarmState]> {
        AsyncStream { continuation in
            let task = Task {
                for await alarms in AlarmManager.shared.alarmUpdates {
                    var states: [UUID: SystemAlarmState] = [:]
                    for alarm in alarms {
                        switch alarm.state {
                        case .alerting: states[alarm.id] = .alerting
                        case .paused: states[alarm.id] = .paused
                        case .countdown: states[alarm.id] = .countdown
                        default: states[alarm.id] = .scheduled
                        }
                    }
                    continuation.yield(states)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Ids AlarmKit already knows about, so relaunching never cancels an alarm that is ringing.
    func scheduledIDs() -> Set<UUID> {
        guard let alarms = try? manager.alarms else { return [] }
        return Set(alarms.map { $0.id })
    }

    // MARK: Helpers

    private static func weekday(for calendarWeekday: Int) -> Locale.Weekday? {
        switch calendarWeekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return nil
        }
    }
}
