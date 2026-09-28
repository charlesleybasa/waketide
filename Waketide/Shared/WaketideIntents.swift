import AlarmKit
import AppIntents
import Foundation

/// Buttons on the Lock Screen card and Dynamic Island. Live Activity intents run in the app's
/// process, so the store sees the change through AlarmKit's updates.

struct StopAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop"
    static let isDiscoverable = false

    @Parameter(title: "Alarm ID") var alarmID: String

    init() {}
    init(id: UUID) { alarmID = id.uuidString }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) { try AlarmManager.shared.stop(id: id) }
        return .result()
    }
}

struct SnoozeAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Snooze"
    static let isDiscoverable = false

    @Parameter(title: "Alarm ID") var alarmID: String

    init() {}
    init(id: UUID) { alarmID = id.uuidString }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) { try AlarmManager.shared.countdown(id: id) }
        return .result()
    }
}

struct PauseTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause"
    static let isDiscoverable = false

    @Parameter(title: "Timer ID") var alarmID: String

    init() {}
    init(id: UUID) { alarmID = id.uuidString }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) { try AlarmManager.shared.pause(id: id) }
        return .result()
    }
}

struct ResumeTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Resume"
    static let isDiscoverable = false

    @Parameter(title: "Timer ID") var alarmID: String

    init() {}
    init(id: UUID) { alarmID = id.uuidString }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) { try AlarmManager.shared.resume(id: id) }
        return .result()
    }
}
