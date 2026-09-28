import XCTest
@testable import Waketide

final class IntentParserTests: XCTestCase {
    override func setUp() {
        super.setUp()
        WakeAlarm.uses24HourClock = false
    }

    private var parser: IntentParser {
        IntentParser(now: TestCal.monday3am, calendar: TestCal.calendar)
    }

    // MARK: - Original tests (unchanged behaviour)

    func testTheDesignExample() {
        let r = parser.parse("Gentle alarm for the AI seminar at 10, remind me about lunch at noon, and a 20 minute nap timer after")
        XCTAssertEqual(r.count, 3)
        guard r.count == 3 else { return }
        XCTAssertEqual(r[0].kind, .alarm)
        XCTAssertEqual(r[0].hour, 10)
        XCTAssertEqual(r[0].minute, 0)
        XCTAssertEqual(r[0].label, "AI seminar")
        XCTAssertEqual(r[1].kind, .reminder)
        XCTAssertEqual(r[1].hour, 12)
        XCTAssertEqual(r[1].label, "Lunch")
        XCTAssertEqual(r[2].kind, .timer)
        XCTAssertEqual(r[2].duration, 20 * 60, accuracy: 0.1)
        XCTAssertEqual(r[2].label, "Nap")
    }

    func testWakeMeOnWeekdays() {
        let r = parser.parse("Wake me at 6:30 on weekdays")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.hour, 6)
        XCTAssertEqual(r.first?.minute, 30)
        XCTAssertEqual(r.first?.weekdays, [2, 3, 4, 5, 6])
        XCTAssertEqual(r.first?.label, "Wake up")
    }

    func testEveryDayWithLabel() {
        let r = parser.parse("take medicine at 1:30 am every day")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.hour, 1)
        XCTAssertEqual(r.first?.minute, 30)
        XCTAssertEqual(r.first?.weekdays, Set(1...7))
        XCTAssertEqual(r.first?.label, "Take medicine")
    }

    func testLabelKeyword() {
        let r = parser.parse("tomorrow at 7am label dentist")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.hour, 7)
        XCTAssertEqual(r.first?.label, "Dentist")
    }

    func testTimerForMinutes() {
        let r = parser.parse("timer for 5 minutes")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.kind, .timer)
        XCTAssertEqual(r.first?.duration ?? 0, 300, accuracy: 0.1)
        XCTAssertEqual(r.first?.label, "Timer")
    }

    func testRelativeAlarm() {
        let r = parser.parse("wake me in 30 minutes")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.kind, .alarm)
        XCTAssertEqual(r.first?.hour, 3)
        XCTAssertEqual(r.first?.minute, 30)
    }

    func testDinnerDefaultsToEvening() {
        let r = parser.parse("dinner at 7")
        XCTAssertEqual(r.first?.hour, 19)
        XCTAssertEqual(r.first?.label, "Dinner")
    }

    func testExplicitPMAndTomorrow() {
        let r = parser.parse("10 pm tomorrow")
        XCTAssertEqual(r.first?.hour, 22)
        XCTAssertEqual(r.first?.date, TestCal.date(2026, 9, 22))
    }

    func testNamedWeekdayIsOneOff() {
        let r = parser.parse("alarm on friday at 8am")
        XCTAssertEqual(r.first?.hour, 8)
        XCTAssertTrue(r.first?.weekdays.isEmpty ?? false)
        XCTAssertEqual(r.first?.date, TestCal.date(2026, 9, 25))
    }

    func testEveryMondayRepeats() {
        let r = parser.parse("every monday at 9")
        XCTAssertEqual(r.first?.hour, 9)
        XCTAssertEqual(r.first?.weekdays, [2])
    }

    func testNoTimeMeansNothingIsCreated() {
        XCTAssertTrue(parser.parse("hello there").isEmpty)
        XCTAssertTrue(parser.parse("").isEmpty)
    }

    func testIntentBuildsAnAlarm() {
        let r = parser.parse("Wake me at 6:30 on weekdays")
        let alarm = r.first?.makeAlarm()
        XCTAssertEqual(alarm?.fullTimeText, "6:30 AM")
        XCTAssertEqual(alarm?.repeatText, "Weekdays")
    }

    // MARK: - Timer "until" a clock time

    func testTimerUntilClockTime() {
        let r = parser.parse("set timer until 4PM")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.kind, .timer)
        XCTAssertEqual(r.first?.duration ?? 0, 13 * 3600, accuracy: 1)
    }

    func testTimerUntilClockTimeWithToday() {
        let r = parser.parse("set timer until 4PM today")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.kind, .timer)
        XCTAssertEqual(r.first?.duration ?? 0, 13 * 3600, accuracy: 1)
    }

    func testTimerUntilWithLabel() {
        let r = parser.parse("timer until 6:30pm for studying")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.kind, .timer)
        XCTAssertEqual(r.first?.label, "Studying")
    }

    // MARK: - Reminders

    func testRemindMeOnDayAtTime() {
        let r = parser.parse("remind me on tuesday at 9am to prepare")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.kind, .reminder)
        XCTAssertEqual(r.first?.hour, 9)
        XCTAssertEqual(r.first?.label, "Prepare")
        XCTAssertEqual(r.first?.date, TestCal.date(2026, 9, 22))
    }

    func testRemindMeOnDayWithoutTime() {
        let r = parser.parse("remind me on tuesday to prepare")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.kind, .reminder)
        XCTAssertEqual(r.first?.hour, 9)
        XCTAssertEqual(r.first?.minute, 0)
        XCTAssertEqual(r.first?.label, "Prepare")
    }

    func testReminderAtTime() {
        let r = parser.parse("reminder at 3pm to call mom")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.kind, .reminder)
        XCTAssertEqual(r.first?.hour, 15)
        XCTAssertEqual(r.first?.label, "Call mom")
    }

    func testRemindMeIn30Minutes() {
        let r = parser.parse("remind me in 30 minutes to stretch")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.kind, .reminder)
        XCTAssertEqual(r.first?.hour, 3)
        XCTAssertEqual(r.first?.minute, 30)
        XCTAssertEqual(r.first?.label, "Stretch")
    }

    // MARK: - Single-letter day abbreviations

    func testMWFAlarm() {
        let r = parser.parse("set alarm M W F at 7am")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.kind, .alarm)
        XCTAssertEqual(r.first?.hour, 7)
        XCTAssertEqual(r.first?.weekdays, [2, 4, 6])
    }

    func testMWFOnly() {
        let r = parser.parse("alarm at 7am M W F only")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.weekdays, [2, 4, 6])
    }

    func testTwoLetterDays() {
        let r = parser.parse("alarm at 8am on Mo We Fr")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.weekdays, [2, 4, 6])
    }

    // MARK: - Intent classification priority

    func testExplicitTimerWordWins() {
        let r = parser.parse("5 minute timer")
        XCTAssertEqual(r.first?.kind, .timer)
        XCTAssertEqual(r.first?.duration ?? 0, 300, accuracy: 0.1)
    }

    func testExplicitAlarmWordWins() {
        let r = parser.parse("alarm at 7am tomorrow")
        XCTAssertEqual(r.first?.kind, .alarm)
        XCTAssertEqual(r.first?.hour, 7)
    }

    func testReminderSubtitle() {
        let r = parser.parse("remind me on tuesday at 9am to prepare")
        XCTAssertEqual(r.count, 1)
        let subtitle = r.first?.subtitle(now: TestCal.monday3am, calendar: TestCal.calendar)
        XCTAssertEqual(subtitle, "Reminder · Tomorrow")
    }

    // MARK: - Natural time speech

    func testHalfPast() {
        let r = parser.parse("alarm at half past 7")
        XCTAssertEqual(r.first?.hour, 7)
        XCTAssertEqual(r.first?.minute, 30)
    }

    func testQuarterPast() {
        let r = parser.parse("alarm at quarter past 9")
        XCTAssertEqual(r.first?.hour, 9)
        XCTAssertEqual(r.first?.minute, 15)
    }

    func testQuarterTo() {
        let r = parser.parse("alarm at quarter to 8")
        XCTAssertEqual(r.first?.hour, 7)
        XCTAssertEqual(r.first?.minute, 45)
    }

    func testOClock() {
        let r = parser.parse("alarm at 7 o'clock")
        XCTAssertEqual(r.first?.hour, 7)
        XCTAssertEqual(r.first?.minute, 0)
    }

    // MARK: - Natural duration speech

    func testHalfAnHour() {
        let r = parser.parse("timer for half an hour")
        XCTAssertEqual(r.first?.kind, .timer)
        XCTAssertEqual(r.first?.duration ?? 0, 30 * 60, accuracy: 0.1)
    }

    func testQuarterHour() {
        let r = parser.parse("timer for a quarter hour")
        XCTAssertEqual(r.first?.kind, .timer)
        XCTAssertEqual(r.first?.duration ?? 0, 15 * 60, accuracy: 0.1)
    }

    func testAnHourAndAHalf() {
        let r = parser.parse("timer for an hour and a half")
        XCTAssertEqual(r.first?.kind, .timer)
        XCTAssertEqual(r.first?.duration ?? 0, 90 * 60, accuracy: 0.1)
    }

    // MARK: - Compound durations

    func testCompoundHoursAndMinutes() {
        let r = parser.parse("timer for 1 hour 30 minutes")
        XCTAssertEqual(r.first?.kind, .timer)
        XCTAssertEqual(r.first?.duration ?? 0, 90 * 60, accuracy: 0.1)
    }

    func testCompoundShortUnits() {
        let r = parser.parse("timer for 2h 15m")
        XCTAssertEqual(r.first?.kind, .timer)
        XCTAssertEqual(r.first?.duration ?? 0, (2 * 60 + 15) * 60, accuracy: 0.1)
    }

    // MARK: - Day qualifiers

    func testNextMonday() {
        // Now is Monday 3am. "next monday" should be the following Monday, not today.
        let r = parser.parse("alarm next monday at 9am")
        XCTAssertEqual(r.first?.hour, 9)
        XCTAssertTrue(r.first?.weekdays.isEmpty ?? false)
        // Next Monday from Mon Sep 21 should be Sep 28
        XCTAssertEqual(r.first?.date, TestCal.date(2026, 9, 28))
    }

    func testThisFriday() {
        let r = parser.parse("alarm this friday at 5pm")
        XCTAssertEqual(r.first?.hour, 17)
        // This Friday from Mon Sep 21 is Sep 25
        XCTAssertEqual(r.first?.date, TestCal.date(2026, 9, 25))
    }

    func testDayAfterTomorrow() {
        let r = parser.parse("alarm at 8am day after tomorrow")
        XCTAssertEqual(r.first?.hour, 8)
        // Day after tomorrow from Mon Sep 21 is Sep 23
        XCTAssertEqual(r.first?.date, TestCal.date(2026, 9, 23))
    }

    // MARK: - "from now" relative

    func testFromNow() {
        // Normalisation converts "2 hours from now" → "in 2 hours"
        let r = parser.parse("alarm 2 hours from now")
        XCTAssertEqual(r.first?.kind, .alarm)
        XCTAssertEqual(r.first?.hour, 5) // 3am + 2h = 5am
        XCTAssertEqual(r.first?.minute, 0)
    }

    // MARK: - AM context hints

    func testBreakfastDefaultsToMorning() {
        let r = parser.parse("breakfast at 7")
        XCTAssertEqual(r.first?.hour, 7) // AM, not 19
    }

    func testGymDefaultsToMorning() {
        let r = parser.parse("gym at 6")
        XCTAssertEqual(r.first?.hour, 6) // AM
    }

    // MARK: - Typo resilience

    func testTypoAlram() {
        let r = parser.parse("alram at 7am")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.hour, 7)
    }

    func testTypoTmrw() {
        let r = parser.parse("alarm at 7am tmrw")
        XCTAssertEqual(r.first?.date, TestCal.date(2026, 9, 22))
    }

    func testTypoTomorow() {
        let r = parser.parse("alarm at 7am tomorow")
        XCTAssertEqual(r.first?.date, TestCal.date(2026, 9, 22))
    }

    // MARK: - Conversational prefixes

    func testCanYouPrefix() {
        let r = parser.parse("can you set an alarm for 6am")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.hour, 6)
    }

    func testIWantPrefix() {
        let r = parser.parse("I want a 10 minute timer")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.kind, .timer)
        XCTAssertEqual(r.first?.duration ?? 0, 600, accuracy: 0.1)
    }

    // MARK: - "don't forget" as reminder

    func testDontForget() {
        let r = parser.parse("don't forget to call dentist at 3pm")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.kind, .reminder)
        XCTAssertEqual(r.first?.hour, 15)
    }

    // MARK: - Pomodoro

    func testPomodoro() {
        let r = parser.parse("pomodoro 25 minutes")
        XCTAssertEqual(r.first?.kind, .timer)
        XCTAssertEqual(r.first?.duration ?? 0, 25 * 60, accuracy: 0.1)
    }
}
