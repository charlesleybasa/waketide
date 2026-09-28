import Foundation

enum ParsedKind {
    case alarm
    case timer
    case reminder
}

/// One thing the "just say it" box understood.
struct ParsedIntent: Identifiable {
    let id = UUID()
    var kind: ParsedKind
    var label: String
    var hour: Int = 0
    var minute: Int = 0
    var weekdays: Set<Int> = []
    var date: Date? = nil
    var duration: TimeInterval = 0

    func makeAlarm() -> WakeAlarm {
        WakeAlarm(label: label, hour: hour, minute: minute, weekdays: weekdays, date: weekdays.isEmpty ? date : nil)
    }

    var title: String {
        switch kind {
        case .alarm: return "\(makeAlarm().fullTimeText), \(label)"
        case .timer: return "\(DateText.countdown(duration)) timer, \(label)"
        case .reminder: return "\(makeAlarm().fullTimeText), \(label)"
        }
    }

    func subtitle(now: Date = Date(), calendar: Calendar = .current) -> String {
        switch kind {
        case .timer: return "Starts when you confirm"
        case .reminder:
            if !weekdays.isEmpty { return makeAlarm().repeatText }
            if let d = date {
                if calendar.isDate(d, inSameDayAs: now) { return "Reminder · Today" }
                if let t = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(d, inSameDayAs: t) { return "Reminder · Tomorrow" }
                return "Reminder · \(DateText.short(d))"
            }
            return "Reminder"
        case .alarm:
            if !weekdays.isEmpty { return makeAlarm().repeatText }
            if let d = date {
                if calendar.isDate(d, inSameDayAs: now) { return "Today" }
                if let t = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(d, inSameDayAs: t) { return "Tomorrow" }
                return DateText.short(d)
            }
            return "Next time it reaches \(makeAlarm().fullTimeText)"
        }
    }
}

/// Deterministic, on-device understanding of short alarm and timer requests.
/// It always produces a list the user confirms before anything is scheduled.
struct IntentParser {
    var now: Date = Date()
    var calendar: Calendar = .current

    func parse(_ text: String) -> [ParsedIntent] {
        split(text).compactMap { parseClause($0) }
    }

    // MARK: Normalisation

    /// Normalise common typos, abbreviations, and natural speech into machine-parseable forms
    /// before any splitting or parsing happens.
    private func normalise(_ text: String) -> String {
        var s = text
        // Periods in am/pm
        s = s.replacingOccurrences(of: "a.m.", with: "am", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "p.m.", with: "pm", options: .caseInsensitive)

        // Common typos and abbreviations
        let typos: [(String, String)] = [
            (#"\balram\b"#, "alarm"),
            (#"\balarma?\b"#, "alarm"),
            (#"\btmrw\b"#, "tomorrow"),
            (#"\btmmrw?\b"#, "tomorrow"),
            (#"\btomrw?\b"#, "tomorrow"),
            (#"\btomorow\b"#, "tomorrow"),
            (#"\btommorrow\b"#, "tomorrow"),
            (#"\btmr\b"#, "tomorrow"),
            (#"\bremid\b"#, "remind"),
            (#"\brmeind\b"#, "remind"),
            (#"\btimmer\b"#, "timer"),
            (#"\bminuets?\b"#, "minutes"),
            (#"\bminits?\b"#, "minutes"),
            (#"\bmintes?\b"#, "minutes"),
        ]
        for (pattern, replacement) in typos {
            s = s.removing(pattern, with: replacement)
        }

        // Conversational prefixes: "can you", "I want", "I need to", "could you", "would you"
        s = s.removing(#"^(?:can you|could you|would you|i want to|i want a|i want|i need to|i need a|i need|hey|hi|hello|yo)\s+"#, with: "")

        // "don't forget to" → "remind me to"
        s = s.removing(#"\bdon'?t forget\b"#, with: "remind me")

        // "o'clock" → just remove it, the number is already captured
        s = s.removing(#"\s*o'?clock\b"#, with: "")

        // "pomodoro" → timer synonym
        s = s.removing(#"\bpomodoro\b"#, with: "timer")

        // Natural time speech: "half past 7" → "7:30", "quarter past 7" → "7:15", "quarter to 8" → "7:45"
        if let m = s.firstMatch(#"\bhalf\s+past\s+(\d{1,2})\b"#), let hs = s.sub(m.range(at: 1)), let h = Int(hs) {
            s = (s as NSString).replacingCharacters(in: m.range, with: "\(h):30")
        }
        if let m = s.firstMatch(#"\bquarter\s+past\s+(\d{1,2})\b"#), let hs = s.sub(m.range(at: 1)), let h = Int(hs) {
            s = (s as NSString).replacingCharacters(in: m.range, with: "\(h):15")
        }
        if let m = s.firstMatch(#"\bquarter\s+(?:to|til|before)\s+(\d{1,2})\b"#), let hs = s.sub(m.range(at: 1)), let h = Int(hs) {
            let prev = h == 1 ? 12 : h - 1
            s = (s as NSString).replacingCharacters(in: m.range, with: "\(prev):45")
        }

        // Natural duration speech: "half an hour" → "30 minutes", "quarter hour" → "15 minutes"
        s = s.removing(#"\bhalf\s+(?:an?\s+)?hour\b"#, with: "30 minutes")
        s = s.removing(#"\b(?:a\s+)?quarter\s+(?:an?\s+)?hour\b"#, with: "15 minutes")
        // "an hour and a half" → "90 minutes"
        s = s.removing(#"\b(?:an?\s+)?hour\s+and\s+(?:a\s+)?half\b"#, with: "90 minutes")

        // "from now" → "in" (for relative timing, e.g., "2 hours from now" → "in 2 hours")
        // We handle this by converting "N hours/minutes from now" to "in N hours/minutes"
        if let m = s.firstMatch(#"(\d+(?:\.\d+)?)\s*(hours?|hrs?|minutes?|mins?)\s+from\s+now"#),
           let num = s.sub(m.range(at: 1)), let unit = s.sub(m.range(at: 2)) {
            s = (s as NSString).replacingCharacters(in: m.range, with: "in \(num) \(unit)")
        }

        return s
    }

    // MARK: Splitting

    func split(_ text: String) -> [String] {
        let s = normalise(text)
        guard let sep = try? NSRegularExpression(
            pattern: #"\s*(?:,|;|\.\s|\.$)\s*|\s+(?:and|then|also|plus)\s+"#,
            options: [.caseInsensitive]) else { return [s] }
        let ns = s as NSString
        var parts: [String] = []
        var last = 0
        for m in sep.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            parts.append(ns.substring(with: NSRange(location: last, length: m.range.location - last)))
            last = m.range.location + m.range.length
        }
        parts.append(ns.substring(from: last))
        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).removing(#"^(?:and|then|also|plus)\s+"#) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: One clause

    func parseClause(_ clause: String) -> ParsedIntent? {
        let lower = clause.lowercased()
        let days = extractDays(clause)
        let duration = extractDuration(clause)
        let time = extractTime(clause)

        // Detect explicit intent signals
        let hasTimerWord = lower.contains("timer") || lower.contains("countdown")
        let hasAlarmWord = lower.firstMatch(#"\balarm\b"#) != nil
        let hasReminderWord = lower.firstMatch(#"\b(?:remind(?:er)?|remind\s+me)\b"#) != nil
        let hasUntil = lower.firstMatch(#"\buntil\b"#) != nil

        // ── Timer paths ──

        // "timer until 4PM" / "set timer until 6:30pm today"
        // User wants a timer that counts down from now to the given clock time.
        if hasTimerWord && hasUntil, let t = time {
            let timerDuration = computeDurationUntil(hour: t.hour, minute: t.minute, on: days.date)
            if timerDuration > 0 {
                let label = extractLabel(clause, fallback: "Timer")
                return ParsedIntent(kind: .timer, label: label, duration: timerDuration)
            }
        }

        // "timer for 5 minutes", "20 minute nap timer", "countdown 30s"
        if let dur = duration, hasTimerWord || (lower.contains("nap") && !lower.contains(" in ")) {
            let label = extractLabel(clause, fallback: "Timer")
            return ParsedIntent(kind: .timer, label: label, duration: dur.seconds)
        }

        // Bare duration with no explicit keyword and no time/day: "5 minute countdown", or just a standalone duration
        if let dur = duration, !hasAlarmWord && !hasReminderWord && !dur.isRelative && !hasUntil {
            if time == nil && days.weekdays.isEmpty && days.date == nil {
                let label = extractLabel(clause, fallback: "Timer")
                return ParsedIntent(kind: .timer, label: label, duration: dur.seconds)
            }
        }

        // ── Reminder paths ──

        // "remind me on Tuesday to prepare", "reminder at 3pm to call mom"
        if hasReminderWord {
            // Relative: "remind me in 30 minutes to stretch"
            if let dur = duration, dur.isRelative {
                let fire = now.addingTimeInterval(dur.seconds)
                let hour = calendar.component(.hour, from: fire)
                let minute = calendar.component(.minute, from: fire)
                let label = extractLabel(clause, fallback: "Reminder")
                return ParsedIntent(kind: .reminder, label: label, hour: hour, minute: minute,
                                    weekdays: [], date: calendar.startOfDay(for: fire))
            }
            // Clock time: "remind me at 3pm", "remind me on Tuesday at 9 to prepare"
            if let t = time {
                let label = extractLabel(clause, fallback: "Reminder")
                var date = days.date
                if days.weekdays.isEmpty && date == nil && lower.contains("tonight") {
                    date = calendar.startOfDay(for: now)
                }
                return ParsedIntent(kind: .reminder, label: label, hour: t.hour, minute: t.minute,
                                    weekdays: days.weekdays, date: date)
            }
            // Day but no time: "remind me on Tuesday to prepare" → default to 9 AM
            if !days.weekdays.isEmpty || days.date != nil {
                let label = extractLabel(clause, fallback: "Reminder")
                return ParsedIntent(kind: .reminder, label: label, hour: 9, minute: 0,
                                    weekdays: days.weekdays, date: days.date)
            }
        }

        // ── Alarm paths ──

        // Relative alarm: "wake me in 30 minutes"
        if let dur = duration, dur.isRelative {
            let fire = now.addingTimeInterval(dur.seconds)
            let hour = calendar.component(.hour, from: fire)
            let minute = calendar.component(.minute, from: fire)
            let label = extractLabel(clause, fallback: lower.contains("wake") ? "Wake up" : "Alarm")
            return ParsedIntent(kind: .alarm, label: label, hour: hour, minute: minute,
                                weekdays: [], date: calendar.startOfDay(for: fire))
        }

        // Clock time: "at 6:30", "10 am", "noon"
        guard let t = time else { return nil }
        let label = extractLabel(clause, fallback: lower.contains("wake") ? "Wake up" : "Alarm")
        var date = days.date
        if days.weekdays.isEmpty && date == nil && lower.contains("tonight") {
            date = calendar.startOfDay(for: now)
        }
        return ParsedIntent(kind: .alarm, label: label, hour: t.hour, minute: t.minute,
                            weekdays: days.weekdays, date: date)
    }

    // MARK: Duration until clock time

    /// Computes the number of seconds from `now` until the given clock time, optionally on a specific day.
    /// Returns 0 if the time is in the past.
    private func computeDurationUntil(hour: Int, minute: Int, on date: Date?) -> TimeInterval {
        let target: Date
        if let d = date {
            guard let t = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: d) else { return 0 }
            target = t
        } else {
            let today = calendar.startOfDay(for: now)
            guard let t = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) else { return 0 }
            if t > now {
                target = t
            } else {
                guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
                      let t2 = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: tomorrow) else { return 0 }
                target = t2
            }
        }
        let interval = target.timeIntervalSince(now)
        return interval > 0 ? interval : 0
    }

    // MARK: Time

    struct TimeHit { var hour: Int; var minute: Int }

    func extractTime(_ clause: String) -> TimeHit? {
        let lower = clause.lowercased()

        if clause.firstMatch(#"\bnoon\b"#) != nil { return TimeHit(hour: 12, minute: 0) }
        if clause.firstMatch(#"\bmidnight\b"#) != nil { return TimeHit(hour: 0, minute: 0) }

        // 6:30 am, 10 pm
        if let m = clause.firstMatch(#"\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b"#),
           let hs = clause.sub(m.range(at: 1)), var h = Int(hs) {
            let min = clause.sub(m.range(at: 2)).flatMap { Int($0) } ?? 0
            let pm = clause.sub(m.range(at: 3))?.lowercased() == "pm"
            guard (1...12).contains(h), (0...59).contains(min) else { return nil }
            if pm { if h < 12 { h += 12 } } else if h == 12 { h = 0 }
            return TimeHit(hour: h, minute: min)
        }

        // 18:45, 6:30
        var hour: Int? = nil
        var minute = 0
        if let m = clause.firstMatch(#"\b(\d{1,2}):(\d{2})\b"#),
           let hs = clause.sub(m.range(at: 1)), let ms = clause.sub(m.range(at: 2)) {
            hour = Int(hs)
            minute = Int(ms) ?? 0
        } else if let m = clause.firstMatch(#"\bat\s+(\d{1,2})\b(?!\s*(?:hours?|hrs?|minutes?|mins?|seconds?|secs?))"#),
                  let hs = clause.sub(m.range(at: 1)) {
            hour = Int(hs)
        } else if let m = clause.firstMatch(#"\buntil\s+(\d{1,2})\b(?!\s*(?:hours?|hrs?|minutes?|mins?|seconds?|secs?))"#),
                  let hs = clause.sub(m.range(at: 1)) {
            hour = Int(hs)
        }
        guard var h = hour, (0...23).contains(h), (0...59).contains(minute) else { return nil }

        if (1...12).contains(h) {
            let pmHints = ["lunch", "dinner", "afternoon", "evening", "tonight", "night", "supper"]
            let amHints = ["breakfast", "morning", "gym", "jog", "run", "school", "work", "office", "commute"]
            let wantsPM = pmHints.contains { lower.contains($0) }
            let wantsAM = amHints.contains { lower.contains($0) }
            if wantsPM && h < 12 { h += 12 }
            else if wantsAM && h < 12 { /* keep as-is AM */ }
            else if !wantsPM && h == 12 && !lower.contains("morning") { h = 12 }
            else if h == 12 && lower.contains("morning") { h = 0 }
        }
        return TimeHit(hour: h, minute: minute)
    }

    // MARK: Durations

    struct DurationHit { var seconds: TimeInterval; var isRelative: Bool }

    func extractDuration(_ clause: String) -> DurationHit? {
        // Compound durations: "1 hour 30 minutes", "1h 30m", "2 hours 15 minutes"
        let compoundPattern = #"(\d+(?:\.\d+)?)\s*-?\s*(hours?|hrs?|hr|h)\s+(?:and\s+)?(\d+(?:\.\d+)?)\s*-?\s*(minutes?|mins?|min|m)\b"#
        if let m = clause.firstMatch(compoundPattern),
           let hoursStr = clause.sub(m.range(at: 1)), let hours = Double(hoursStr),
           let minsStr = clause.sub(m.range(at: 3)), let mins = Double(minsStr) {
            let seconds = hours * 3600 + mins * 60
            let before = (clause as NSString).substring(to: m.range.location).lowercased()
            let relative = before.trimmingCharacters(in: .whitespaces).hasSuffix(" in") || before.trimmingCharacters(in: .whitespaces) == "in"
            return DurationHit(seconds: seconds, isRelative: relative)
        }

        // Single duration: "5 minutes", "an hour"
        let pattern = #"(\d+(?:\.\d+)?)\s*-?\s*(hours?|hrs?|hr|h|minutes?|mins?|min|m|seconds?|secs?|sec|s)\b|\b(?:an?|one)\s+(hour|minute)\b"#
        guard let m = clause.firstMatch(pattern) else { return nil }
        var value: Double
        var unit: String
        if let vs = clause.sub(m.range(at: 1)), let v = Double(vs), let u = clause.sub(m.range(at: 2)) {
            value = v
            unit = u.lowercased()
        } else if let u = clause.sub(m.range(at: 3)) {
            value = 1
            unit = u.lowercased()
        } else {
            return nil
        }
        let seconds: Double
        if unit.hasPrefix("h") { seconds = value * 3600 }
        else if unit.hasPrefix("m") { seconds = value * 60 }
        else { seconds = value }
        let before = (clause as NSString).substring(to: m.range.location).lowercased()
        let relative = before.trimmingCharacters(in: .whitespaces).hasSuffix(" in") || before.trimmingCharacters(in: .whitespaces) == "in"
        return DurationHit(seconds: seconds, isRelative: relative)
    }

    // MARK: Days

    struct DayHit { var weekdays: Set<Int>; var date: Date? }

    func extractDays(_ clause: String) -> DayHit {
        let today = calendar.startOfDay(for: now)
        if clause.firstMatch(#"\bweekdays?\b"#) != nil { return DayHit(weekdays: [2, 3, 4, 5, 6], date: nil) }
        if clause.firstMatch(#"\bweekends?\b"#) != nil { return DayHit(weekdays: [1, 7], date: nil) }
        if clause.firstMatch(#"\b(?:every\s*day|everyday|daily|each day)\b"#) != nil {
            return DayHit(weekdays: Set(1...7), date: nil)
        }

        let names: [(String, String, Int)] = [
            ("sunday", "sun", 1), ("monday", "mon", 2), ("tuesday", "tue|tues", 3),
            ("wednesday", "wed", 4), ("thursday", "thu|thur|thurs", 5),
            ("friday", "fri", 6), ("saturday", "sat", 7)
        ]

        // Two-letter abbreviations: Mo Tu We Th Fr Sa Su
        let twoLetterMap: [(String, Int)] = [
            (#"\bsu\b"#, 1), (#"\bmo\b"#, 2), (#"\btu\b"#, 3),
            (#"\bwe\b"#, 4), (#"\bth\b"#, 5), (#"\bfr\b"#, 6), (#"\bsa\b"#, 7)
        ]

        // "next Monday", "this Friday", "coming Wednesday" — check BEFORE generic day names
        // so "next monday" skips today even if today is Monday.
        let dayMap = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7]
        if let m = clause.firstMatch(#"\b(next|this|coming)\s+(sunday|monday|tuesday|wednesday|thursday|friday|saturday)\b"#),
           let qualifier = clause.sub(m.range(at: 1))?.lowercased(),
           let dayName = clause.sub(m.range(at: 2))?.lowercased(),
           let target = dayMap[dayName] {
            let startOffset = qualifier == "next" ? 1 : 0
            for offset in startOffset..<8 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                      calendar.component(.weekday, from: day) == target else { continue }
                if offset == 0, let t = extractTime(clause),
                   let fire = calendar.date(bySettingHour: t.hour, minute: t.minute, second: 0, of: day), fire <= now {
                    continue
                }
                return DayHit(weekdays: [], date: day)
            }
        }

        var found: Set<Int> = []
        var plural = false
        for (full, abbr, num) in names {
            if clause.firstMatch("\\b\(full)s\\b") != nil { found.insert(num); plural = true }
            else if clause.firstMatch("\\b\(full)\\b") != nil { found.insert(num) }
            else if clause.firstMatch("\\b(?:on|every|each)\\s+(?:\(abbr))\\b") != nil { found.insert(num) }
        }

        // Two-letter abbreviations (only if we haven't already found anything from full names)
        if found.isEmpty {
            for (pattern, num) in twoLetterMap {
                if clause.firstMatch(pattern) != nil { found.insert(num) }
            }
        }

        // Single-letter day pattern: "M W F", "M, W, F", "M/W/F" etc.
        // Only match when letters appear together in a list-like pattern to avoid false positives.
        if found.isEmpty {
            let dayLetterPattern = #"\b([MTWRFSU])(?:\s*[,/\-]\s*|\s+)([MTWRFSU])(?:(?:\s*[,/\-]\s*|\s+)([MTWRFSU]))?(?:(?:\s*[,/\-]\s*|\s+)([MTWRFSU]))?(?:(?:\s*[,/\-]\s*|\s+)([MTWRFSU]))?(?:\s+only)?\b"#
            if let m = clause.firstMatch(dayLetterPattern) {
                let letterMap: [Character: Int] = [
                    "U": 1,  // sUnday
                    "M": 2,  // Monday
                    "T": 3,  // Tuesday
                    "W": 4,  // Wednesday
                    "R": 5,  // thuRsday
                    "F": 6,  // Friday
                    "S": 7   // Saturday
                ]
                for group in 1...5 {
                    if let letter = clause.sub(m.range(at: group)),
                       let c = letter.uppercased().first,
                       let num = letterMap[c] {
                        found.insert(num)
                    }
                }
            }
        }

        if !found.isEmpty {
            let repeating = plural || clause.firstMatch(#"\b(?:every|each|only)\b"#) != nil || found.count > 1
            if repeating { return DayHit(weekdays: found, date: nil) }
            let target = found.first!
            let fireTime = extractTime(clause)
            for offset in 0..<8 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                      calendar.component(.weekday, from: day) == target else { continue }
                if offset == 0, let t = fireTime,
                   let fire = calendar.date(bySettingHour: t.hour, minute: t.minute, second: 0, of: day), fire <= now {
                    continue
                }
                return DayHit(weekdays: [], date: day)
            }
        }

        // "day after tomorrow"
        if clause.firstMatch(#"\bday\s+after\s+tomorrow\b"#) != nil {
            return DayHit(weekdays: [], date: calendar.date(byAdding: .day, value: 2, to: today))
        }
        if clause.firstMatch(#"\btomorrow\b"#) != nil {
            return DayHit(weekdays: [], date: calendar.date(byAdding: .day, value: 1, to: today))
        }
        if clause.firstMatch(#"\b(?:today|tonight)\b"#) != nil {
            return DayHit(weekdays: [], date: today)
        }

        return DayHit(weekdays: [], date: nil)
    }

    // MARK: Label

    func extractLabel(_ clause: String, fallback: String) -> String {
        let marker = #"\b(?:labell?ed|label|for|to|about|called|named|of)\s+(?:the\s+|my\s+|a\s+|an\s+)?(.+?)(?=\s+(?:at|on|every|each|in|tomorrow|today|tonight|daily|weekdays?|weekends?|after|before|by|from|until)\b|$)"#
        if let m = clause.firstMatch(marker), let cand = clause.sub(m.range(at: 1)) {
            let cleaned = strip(cand)
            if !cleaned.isEmpty { return capitalized(cand.trimmingCharacters(in: .whitespaces)) }
        }
        let rest = strip(clause)
        return rest.isEmpty ? fallback : capitalized(rest)
    }

    private func strip(_ s: String) -> String {
        var t = s
        let patterns = [
            #"(\d+(?:\.\d+)?)\s*-?\s*(hours?|hrs?|hr|h|minutes?|mins?|min|m|seconds?|secs?|sec|s)\b"#,
            #"\b(?:an?|one)\s+(?:hour|minute)\b"#,
            #"\b\d{1,2}(?::\d{2})?\s*(?:am|pm)\b"#,
            #"\b\d{1,2}:\d{2}\b"#,
            #"\bat\s+\d{1,2}\b"#,
            #"\b(?:noon|midnight|tomorrow|today|tonight|daily|everyday|every\s*day|each day|weekdays?|weekends?)\b"#,
            #"\b(?:sun|mon|tues?|wed|thu(?:rs?)?|fri|sat)(?:day|nesday|sday|rsday|urday)?s?\b"#,
            #"\b(?:at|on|every|each|in|after|before|later|afterwards|until|only|next|this|coming)\b"#,
            #"\b(?:day after tomorrow)\b"#,
            #"\b(?:please|set|create|add|make|schedule|start|an?|the|new|alarms?|timer|countdown|gentle|wake me up|wake me|wake up|remind me to|remind me|remind|reminder|for|to|me|my)\b"#
        ]
        for p in patterns { t = t.removing(p) }
        return t.split(separator: " ").joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func capitalized(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }
}

// MARK: - String helpers

extension String {
    func firstMatch(_ pattern: String) -> NSTextCheckingResult? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        return re.firstMatch(in: self, range: NSRange(location: 0, length: (self as NSString).length))
    }

    func sub(_ range: NSRange) -> String? {
        guard range.location != NSNotFound else { return nil }
        return (self as NSString).substring(with: range)
    }

    func removing(_ pattern: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return self }
        return re.stringByReplacingMatches(in: self, range: NSRange(location: 0, length: (self as NSString).length), withTemplate: " ")
    }

    /// Replace matching pattern with a specific replacement string.
    func removing(_ pattern: String, with replacement: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return self }
        return re.stringByReplacingMatches(in: self, range: NSRange(location: 0, length: (self as NSString).length), withTemplate: replacement)
    }
}
