import Foundation
import SwiftUI

struct RunningTimer: Identifiable, Codable {
    var id = UUID()
    var label: String
    var total: TimeInterval
    /// Set while running.
    var endDate: Date?
    /// Set while paused.
    var pausedRemaining: TimeInterval?

    var isPaused: Bool { pausedRemaining != nil }

    func remaining(at now: Date = Date()) -> TimeInterval {
        if let p = pausedRemaining { return p }
        if let e = endDate { return max(0, e.timeIntervalSince(now)) }
        return total
    }

    func isFinished(at now: Date = Date()) -> Bool {
        !isPaused && remaining(at: now) <= 0
    }
}

struct ApplyResult {
    var alarmsAdded = 0
    var timersStarted = 0

    var message: String {
        var parts: [String] = []
        if alarmsAdded > 0 { parts.append(alarmsAdded == 1 ? "1 alarm set" : "\(alarmsAdded) alarms set") }
        if timersStarted > 0 { parts.append(timersStarted == 1 ? "timer started" : "\(timersStarted) timers started") }
        return parts.isEmpty ? "Nothing to add" : parts.joined(separator: ", ").capitalizedFirst
    }
}

extension String {
    var capitalizedFirst: String {
        guard let f = first else { return self }
        return f.uppercased() + dropFirst()
    }
}

@MainActor
final class AlarmStore: ObservableObject {
    @Published private(set) var alarms: [WakeAlarm] = []
    @Published private(set) var timers: [RunningTimer] = [] {
        didSet { persistTimers() }
    }
    @Published var ringing: WakeAlarm?
    @Published var banner: String?
    @Published var lastDeleted: WakeAlarm?
    @Published var permissionDenied = false

    private let defaults: UserDefaults
    private let key = "waketide.alarms.v1"
    private let timersKey = "waketide.timers.v2"
    /// Track which timer IDs AlarmKit has reported, so we know when one genuinely finishes.
    private var timersSeen: Set<UUID> = []
    private let scheduler = AlarmScheduler.shared
    private var started = false
    private var undoTask: Task<Void, Never>?

    // MARK: Backwards compatibility — single-timer readers

    /// The first running (non-finished) timer, or nil. Kept for widget / Live Activity code.
    var timer: RunningTimer? { timers.first }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        loadTimers()
    }

    // MARK: Lifecycle

    func bootstrap() async {
        guard !started else { return }
        started = true
        
        // Dummy data injection for screenshots
        if self.alarms.isEmpty {
            var alarm1 = WakeAlarm(label: "Morning Workout", hour: 6, minute: 30)
            alarm1.weekdays = [2, 4, 6]
            alarm1.isEnabled = true
            self.save(alarm1)

            var alarm2 = WakeAlarm(label: "Breakfast", hour: 7, minute: 0)
            alarm2.weekdays = [2, 3, 4, 5, 6]
            alarm2.isEnabled = true
            self.save(alarm2)
        }
        
        if self.timers.isEmpty {
            self.startTimer(label: "Focus Block", duration: 1500)
        }

        expireOneOffs()
        let ok = await scheduler.authorize()
        permissionDenied = !ok
        if ok {
            let known = scheduler.scheduledIDs()
            for alarm in alarms where alarm.isEnabled && !known.contains(alarm.id) {
                await reschedule(alarm)
            }
            // Timers AlarmKit no longer knows about finished while the app was closed.
            var alive: [RunningTimer] = []
            for t in timers {
                if known.contains(t.id) {
                    timersSeen.insert(t.id)
                    alive.append(t)
                }
                // else: it finished while closed — drop it silently
            }
            if alive.count != timers.count { timers = alive }
        }
        Task { await observeSystem() }
    }

    func refresh() {
        expireOneOffs()
    }

    private func observeSystem() async {
        var previous: WakeAlarm?
        for await states in scheduler.stateUpdates() {
            syncTimers(with: states)
            let ids = Set(states.filter { $0.value == .alerting }.map(\.key))
            if let id = ids.first(where: { id in alarms.contains { $0.id == id } }),
               let alarm = alarms.first(where: { $0.id == id }) {
                ringing = alarm
                previous = alarm
            } else if ids.isEmpty {
                ringing = nil
                if let p = previous, p.weekdays.isEmpty, var done = alarms.first(where: { $0.id == p.id }) {
                    done.isEnabled = false
                    replace(done)
                }
                previous = nil
            }
        }
    }

    /// Mirrors pause, resume and stop done from the Lock Screen or Dynamic Island — for all timers.
    private func syncTimers(with states: [UUID: SystemAlarmState]) {
        var changed = false
        var updated = timers
        var toRemove: [UUID] = []
        for i in updated.indices {
            let t = updated[i]
            guard let state = states[t.id] else {
                // If we've seen this timer from AlarmKit before and it's now gone, it finished.
                if timersSeen.contains(t.id) { toRemove.append(t.id) }
                continue
            }
            timersSeen.insert(t.id)
            switch state {
            case .paused where !t.isPaused:
                updated[i].pausedRemaining = t.remaining()
                updated[i].endDate = nil
                changed = true
            case .countdown where t.isPaused:
                updated[i].endDate = Date().addingTimeInterval(t.pausedRemaining ?? 0)
                updated[i].pausedRemaining = nil
                changed = true
            default:
                break
            }
        }
        if !toRemove.isEmpty {
            updated.removeAll { toRemove.contains($0.id) }
            timersSeen.subtract(toRemove)
            changed = true
        }
        if changed { timers = updated }
    }

    // MARK: Persistence

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([WakeAlarm].self, from: data) else { return }
        alarms = decoded.sorted(by: Self.order)
    }

    private func loadTimers() {
        // Try new multi-timer key first
        if let data = defaults.data(forKey: timersKey),
           let saved = try? JSONDecoder().decode([RunningTimer].self, from: data) {
            timers = saved; return
        }
        // Migrate from old single-timer key
        let oldKey = "waketide.timer.v1"
        if let data = defaults.data(forKey: oldKey),
           let saved = try? JSONDecoder().decode(RunningTimer.self, from: data) {
            timers = [saved]
            defaults.removeObject(forKey: oldKey)
        }
    }

    private func persistTimers() {
        if let data = try? JSONEncoder().encode(timers) {
            defaults.set(data, forKey: timersKey)
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(alarms) {
            defaults.set(data, forKey: key)
        }
    }

    private static func order(_ a: WakeAlarm, _ b: WakeAlarm) -> Bool {
        if a.minutesSinceMidnight != b.minutesSinceMidnight { return a.minutesSinceMidnight < b.minutesSinceMidnight }
        return a.label < b.label
    }

    private func replace(_ alarm: WakeAlarm) {
        if let i = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[i] = alarm
        } else {
            alarms.append(alarm)
        }
        alarms.sort(by: Self.order)
        persist()
    }

    // MARK: Alarm actions

    func save(_ alarm: WakeAlarm) {
        let alarm = alarm.pinningOneOffDate()
        replace(alarm)
        Task { await reschedule(alarm) }
    }

    func setEnabled(_ alarm: WakeAlarm, _ on: Bool) {
        var a = on ? alarm.pinningOneOffDate() : alarm
        a.isEnabled = on
        replace(a)
        Task { await reschedule(a) }
    }

    func delete(_ alarm: WakeAlarm) {
        alarms.removeAll { $0.id == alarm.id }
        persist()
        scheduler.cancel(id: alarm.id)
        lastDeleted = alarm
        undoTask?.cancel()
        undoTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if !Task.isCancelled { self?.lastDeleted = nil }
        }
    }

    func undoDelete() {
        guard let a = lastDeleted else { return }
        lastDeleted = nil
        undoTask?.cancel()
        save(a)
    }

    func expireOneOffs() {
        var changed = false
        for i in alarms.indices where alarms[i].isEnabled && alarms[i].hasExpired() {
            alarms[i].isEnabled = false
            changed = true
        }
        if changed { persist() }
    }

    private func reschedule(_ alarm: WakeAlarm) async {
        if !(await scheduler.authorize()) {
            permissionDenied = true
            return
        }
        permissionDenied = false
        do {
            try await scheduler.schedule(alarm)
        } catch {
            banner = "Couldn't schedule \(alarm.label): \(error.localizedDescription)"
        }
    }

    func stopRinging() {
        guard let a = ringing else { return }
        scheduler.stop(id: a.id)
        ringing = nil
        if a.weekdays.isEmpty, var done = alarms.first(where: { $0.id == a.id }) {
            done.isEnabled = false
            replace(done)
        }
    }

    func snoozeRinging() {
        guard let a = ringing else { return }
        scheduler.snooze(id: a.id)
        ringing = nil
    }

    // MARK: Queries

    func alarms(on day: Date) -> [WakeAlarm] {
        alarms.filter { $0.occurs(on: day) }
    }

    var nextAlarm: (alarm: WakeAlarm, fire: Date)? {
        alarms
            .filter { $0.isEnabled }
            .compactMap { a in a.nextFireDate().map { (alarm: a, fire: $0) } }
            .min { $0.fire < $1.fire }
    }

    // MARK: Timer actions (multi-timer)

    @discardableResult
    func startTimer(label: String, duration: TimeInterval) -> RunningTimer? {
        guard duration >= 1 else { return nil }
        let t = RunningTimer(label: label, total: duration,
                             endDate: Date().addingTimeInterval(duration),
                             pausedRemaining: nil)
        timers.append(t)
        Task {
            if await scheduler.authorize() {
                do { try await scheduler.startTimer(id: t.id, label: label, duration: duration) }
                catch { banner = "Couldn't start the Lock Screen timer: \(error.localizedDescription)" }
            } else {
                permissionDenied = true
            }
        }
        return t
    }

    func pauseTimer(id: UUID) {
        guard let i = timers.firstIndex(where: { $0.id == id }), !timers[i].isPaused else { return }
        timers[i].pausedRemaining = timers[i].remaining()
        timers[i].endDate = nil
        scheduler.pauseTimer(id: id)
    }

    func resumeTimer(id: UUID) {
        guard let i = timers.firstIndex(where: { $0.id == id }),
              let rem = timers[i].pausedRemaining else { return }
        timers[i].endDate = Date().addingTimeInterval(rem)
        timers[i].pausedRemaining = nil
        scheduler.resumeTimer(id: id)
    }

    func addToTimer(id: UUID, seconds: TimeInterval) {
        guard let i = timers.firstIndex(where: { $0.id == id }) else { return }
        let t = timers[i]
        let newDuration = t.remaining() + seconds
        // Restart the AlarmKit entry with the extended duration
        scheduler.cancel(id: t.id)
        timers[i].total = t.total + seconds
        timers[i].endDate = Date().addingTimeInterval(newDuration)
        timers[i].pausedRemaining = nil
        let label = t.label
        Task {
            if await scheduler.authorize() {
                do { try await scheduler.startTimer(id: timers[i].id, label: label, duration: newDuration) }
                catch { banner = "Couldn't extend timer: \(error.localizedDescription)" }
            }
        }
    }

    func cancelTimer(id: UUID) {
        scheduler.cancel(id: id)
        scheduler.stop(id: id)
        timersSeen.remove(id)
        timers.removeAll { $0.id == id }
    }

    func cancelAllTimers() {
        for t in timers { scheduler.cancel(id: t.id); scheduler.stop(id: t.id) }
        timersSeen = []
        timers = []
    }

    // MARK: AI

    @discardableResult
    func apply(_ intents: [ParsedIntent]) -> ApplyResult {
        var result = ApplyResult()
        for intent in intents {
            switch intent.kind {
            case .alarm, .reminder:
                save(intent.makeAlarm())
                result.alarmsAdded += 1
            case .timer:
                startTimer(label: intent.label, duration: intent.duration)
                result.timersStarted += 1
            }
        }
        return result
    }
}
