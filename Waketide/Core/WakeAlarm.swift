import Foundation

/// Sounds offered in the picker. Custom audio files can be added later;
/// until then AlarmKit rings with the system default alarm sound.
enum WakeSound: String, Codable, CaseIterable, Identifiable {
    case tidalRise = "Tidal Rise"
    case glassChime = "Glass Chime"
    case morningRain = "Morning Rain"
    case lowSun = "Low Sun"

    var id: String { rawValue }
}

struct WakeAlarm: Identifiable, Codable, Hashable {
    var id = UUID()
    var label: String
    /// 0...23
    var hour: Int
    /// 0...59
    var minute: Int
    /// Calendar weekday numbers, 1 = Sunday ... 7 = Saturday. Empty means "does not repeat".
    var weekdays: Set<Int> = []
    /// Day of a one-off alarm. Only used when `weekdays` is empty.
    var date: Date? = nil
    var isEnabled = true
    var gentleRise = true
    var sound: WakeSound = .tidalRise
    var snoozeMinutes = 9
    /// Length of the plan this alarm starts, in minutes. 0 means just a moment in time.
    var durationMinutes = 0

    // MARK: Display

    /// Follows the iPhone's 12/24-hour setting (read once at launch). Tests pin it.
    static var uses24HourClock: Bool = !(DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? "").contains("a")

    /// "AM"/"PM", or empty on a 24-hour clock.
    var meridiem: String {
        if Self.uses24HourClock { return "" }
        return hour < 12 ? "AM" : "PM"
    }

    var timeText: String {
        if Self.uses24HourClock { return String(format: "%02d:%02d", hour, minute) }
        let h = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d", h, minute)
    }

    var fullTimeText: String { meridiem.isEmpty ? timeText : "\(timeText) \(meridiem)" }

    var minutesSinceMidnight: Int { hour * 60 + minute }

    /// "5:30 to 7:00 AM" for plans with a length, otherwise just the start.
    var rangeText: String {
        guard durationMinutes > 0 else { return fullTimeText }
        let endTotal = (minutesSinceMidnight + durationMinutes) % (24 * 60)
        let end = WakeAlarm(label: "", hour: endTotal / 60, minute: endTotal % 60)
        if end.meridiem == meridiem { return "\(timeText) to \(end.fullTimeText)" }
        return "\(fullTimeText) to \(end.fullTimeText)"
    }

    var repeatText: String {
        if weekdays.isEmpty {
            if let d = date { return DateText.short(d) }
            return "Once"
        }
        if weekdays.count == 7 { return "Every day" }
        if weekdays == [2, 3, 4, 5, 6] { return "Weekdays" }
        if weekdays == [1, 7] { return "Weekends" }
        let names = Calendar.current.shortWeekdaySymbols
        return weekdays.sorted().map { names[$0 - 1] }.joined(separator: ", ")
    }

    var accessibilityText: String {
        "Alarm \(fullTimeText), \(label), \(repeatText), \(isEnabled ? "on" : "off")"
    }

    // MARK: Scheduling logic

    /// The next moment this alarm rings, or nil if it never will again.
    func nextFireDate(after now: Date = Date(), calendar: Calendar = .current) -> Date? {
        func at(_ day: Date) -> Date? {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
        }
        let today = calendar.startOfDay(for: now)

        if !weekdays.isEmpty {
            for offset in 0..<8 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
                guard weekdays.contains(calendar.component(.weekday, from: day)) else { continue }
                if let fire = at(day), fire > now { return fire }
            }
            return nil
        }
        if let d = date {
            if let fire = at(d), fire > now { return fire }
            return nil
        }
        if let fire = at(today), fire > now { return fire }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) { return at(tomorrow) }
        return nil
    }

    /// Whether this alarm rings on the given calendar day.
    func occurs(on day: Date, calendar: Calendar = .current) -> Bool {
        if !weekdays.isEmpty {
            return weekdays.contains(calendar.component(.weekday, from: day))
        }
        if let d = date { return calendar.isDate(d, inSameDayAs: day) }
        if let next = nextFireDate(calendar: calendar) {
            return calendar.isDate(next, inSameDayAs: day)
        }
        return false
    }

    /// A one-off alarm without a date (or whose date has passed) gets pinned to the day it will
    /// next ring. Otherwise, if it rang while the app was closed, relaunching would schedule it
    /// again for the following day.
    func pinningOneOffDate(now: Date = Date(), calendar: Calendar = .current) -> WakeAlarm {
        guard weekdays.isEmpty, date == nil || hasExpired(now: now, calendar: calendar) else { return self }
        var pinned = self
        pinned.date = nil
        guard let fire = pinned.nextFireDate(after: now, calendar: calendar) else { return self }
        pinned.date = calendar.startOfDay(for: fire)
        return pinned
    }

    /// A one-off alarm whose moment has passed.
    func hasExpired(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard weekdays.isEmpty, let d = date,
              let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: d) else { return false }
        return fire <= now
    }
}

enum DateText {
    static func short(_ date: Date) -> String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return f.string(from: date)
    }

    static func long(_ date: Date) -> String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return f.string(from: date)
    }

    static func monthYear(_ date: Date) -> String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return f.string(from: date)
    }

    /// "1 h 05 min", "12 min", "45 s"
    static func countdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d h %02d min", h, m) }
        if m > 0 { return "\(m) min" }
        return "\(s) s"
    }

    /// "12:30" or "1:02:30"
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
