import Foundation

enum TestCal {
    static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2
        return c
    }()

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h; comps.minute = min
        return calendar.date(from: comps)!
    }

    /// Monday 21 September 2026, 03:00 UTC
    static var monday3am: Date { date(2026, 9, 21, 3, 0) }
}
