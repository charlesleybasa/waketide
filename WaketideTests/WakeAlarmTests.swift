import XCTest
@testable import Waketide

final class WakeAlarmTests: XCTestCase {
    private let cal = TestCal.calendar

    override func setUp() {
        super.setUp()
        WakeAlarm.uses24HourClock = false
    }

    override func tearDown() {
        WakeAlarm.uses24HourClock = false
        super.tearDown()
    }

    func testTimeTextUsesTwelveHourClock() {
        XCTAssertEqual(WakeAlarm(label: "a", hour: 0, minute: 5).timeText, "12:05")
        XCTAssertEqual(WakeAlarm(label: "a", hour: 0, minute: 5).meridiem, "AM")
        XCTAssertEqual(WakeAlarm(label: "a", hour: 12, minute: 0).timeText, "12:00")
        XCTAssertEqual(WakeAlarm(label: "a", hour: 12, minute: 0).meridiem, "PM")
        XCTAssertEqual(WakeAlarm(label: "a", hour: 13, minute: 30).fullTimeText, "1:30 PM")
        XCTAssertEqual(WakeAlarm(label: "a", hour: 5, minute: 30).fullTimeText, "5:30 AM")
    }

    func testRepeatText() {
        XCTAssertEqual(WakeAlarm(label: "a", hour: 6, minute: 0, weekdays: [2, 3, 4, 5, 6]).repeatText, "Weekdays")
        XCTAssertEqual(WakeAlarm(label: "a", hour: 6, minute: 0, weekdays: [1, 7]).repeatText, "Weekends")
        XCTAssertEqual(WakeAlarm(label: "a", hour: 6, minute: 0, weekdays: Set(1...7)).repeatText, "Every day")
        XCTAssertEqual(WakeAlarm(label: "a", hour: 6, minute: 0).repeatText, "Once")
    }

    func testWeekdayAlarmFiresLaterTodayWhenTimeIsAhead() {
        let a = WakeAlarm(label: "Work", hour: 6, minute: 30, weekdays: [2, 3, 4, 5, 6])
        let fire = a.nextFireDate(after: TestCal.monday3am, calendar: cal)
        XCTAssertEqual(fire, TestCal.date(2026, 9, 21, 6, 30))
    }

    func testWeekdayAlarmRollsToTomorrowWhenTimePassed() {
        let a = WakeAlarm(label: "Work", hour: 6, minute: 30, weekdays: [2, 3, 4, 5, 6])
        let fire = a.nextFireDate(after: TestCal.date(2026, 9, 21, 7, 0), calendar: cal)
        XCTAssertEqual(fire, TestCal.date(2026, 9, 22, 6, 30))
    }

    func testWeekdayAlarmSkipsWeekend() {
        let a = WakeAlarm(label: "Work", hour: 6, minute: 30, weekdays: [2, 3, 4, 5, 6])
        // Friday 25 Sep, 08:00 -> next Monday 28 Sep
        let fire = a.nextFireDate(after: TestCal.date(2026, 9, 25, 8, 0), calendar: cal)
        XCTAssertEqual(fire, TestCal.date(2026, 9, 28, 6, 30))
    }

    func testOneOffWithoutDateUsesNextOccurrence() {
        let a = WakeAlarm(label: "x", hour: 2, minute: 0)
        XCTAssertEqual(a.nextFireDate(after: TestCal.monday3am, calendar: cal), TestCal.date(2026, 9, 22, 2, 0))
        let b = WakeAlarm(label: "x", hour: 4, minute: 0)
        XCTAssertEqual(b.nextFireDate(after: TestCal.monday3am, calendar: cal), TestCal.date(2026, 9, 21, 4, 0))
    }

    func testOneOffWithDateNeverFiresAgainOnceExpired() {
        let a = WakeAlarm(label: "x", hour: 10, minute: 0, date: TestCal.date(2026, 9, 21))
        XCTAssertEqual(a.nextFireDate(after: TestCal.monday3am, calendar: cal), TestCal.date(2026, 9, 21, 10, 0))
        XCTAssertNil(a.nextFireDate(after: TestCal.date(2026, 9, 21, 11, 0), calendar: cal))
        XCTAssertTrue(a.hasExpired(now: TestCal.date(2026, 9, 21, 11, 0), calendar: cal))
        XCTAssertFalse(a.hasExpired(now: TestCal.monday3am, calendar: cal))
    }

    func testOccursOn() {
        let weekly = WakeAlarm(label: "x", hour: 6, minute: 0, weekdays: [2])
        XCTAssertTrue(weekly.occurs(on: TestCal.date(2026, 9, 21), calendar: cal))
        XCTAssertFalse(weekly.occurs(on: TestCal.date(2026, 9, 22), calendar: cal))
        let dated = WakeAlarm(label: "x", hour: 6, minute: 0, date: TestCal.date(2026, 9, 24))
        XCTAssertTrue(dated.occurs(on: TestCal.date(2026, 9, 24, 15, 0), calendar: cal))
        XCTAssertFalse(dated.occurs(on: TestCal.date(2026, 9, 25), calendar: cal))
    }

    func testCodableRoundTrip() throws {
        let a = WakeAlarm(label: "Medicine", hour: 1, minute: 30, weekdays: [2, 4], date: nil, isEnabled: false)
        let data = try JSONEncoder().encode([a])
        let back = try JSONDecoder().decode([WakeAlarm].self, from: data)
        XCTAssertEqual(back, [a])
    }

    func testCountdownAndClockFormatting() {
        XCTAssertEqual(DateText.countdown(45), "45 s")
        XCTAssertEqual(DateText.countdown(12 * 60), "12 min")
        XCTAssertEqual(DateText.countdown(3600 + 5 * 60), "1 h 05 min")
        XCTAssertEqual(DateText.clock(750), "12:30")
        XCTAssertEqual(DateText.clock(3750), "1:02:30")
        XCTAssertEqual(DateText.clock(0), "0:00")
    }

    func testTimeTextUsesTwentyFourHourClock() {
        WakeAlarm.uses24HourClock = true
        XCTAssertEqual(WakeAlarm(label: "a", hour: 0, minute: 5).fullTimeText, "00:05")
        XCTAssertEqual(WakeAlarm(label: "a", hour: 13, minute: 30).fullTimeText, "13:30")
        XCTAssertEqual(WakeAlarm(label: "a", hour: 13, minute: 30).meridiem, "")
        XCTAssertEqual(WakeAlarm(label: "a", hour: 23, minute: 0, durationMinutes: 90).rangeText, "23:00 to 00:30")
    }

    func testPinningUndatedOneOffUsesTheDayItRings() {
        let now = TestCal.monday3am
        let later = WakeAlarm(label: "a", hour: 7, minute: 0).pinningOneOffDate(now: now, calendar: cal)
        XCTAssertEqual(later.date, TestCal.date(2026, 9, 21))
        let earlier = WakeAlarm(label: "a", hour: 2, minute: 0).pinningOneOffDate(now: now, calendar: cal)
        XCTAssertEqual(earlier.date, TestCal.date(2026, 9, 22))
    }

    func testPinnedOneOffDoesNotRingAgainAfterItsDay() {
        let pinned = WakeAlarm(label: "a", hour: 7, minute: 0).pinningOneOffDate(now: TestCal.monday3am, calendar: cal)
        XCTAssertNil(pinned.nextFireDate(after: TestCal.date(2026, 9, 21, 8, 0), calendar: cal))
        XCTAssertTrue(pinned.hasExpired(now: TestCal.date(2026, 9, 21, 8, 0), calendar: cal))
    }

    func testPinningReschedulesAnExpiredOneOff() {
        var old = WakeAlarm(label: "a", hour: 7, minute: 0)
        old.date = TestCal.date(2026, 9, 14)
        XCTAssertEqual(old.pinningOneOffDate(now: TestCal.monday3am, calendar: cal).date, TestCal.date(2026, 9, 21))
    }

    func testPinningLeavesRepeatingAndFutureDatedAlarmsAlone() {
        let weekly = WakeAlarm(label: "a", hour: 7, minute: 0, weekdays: [2])
        XCTAssertNil(weekly.pinningOneOffDate(now: TestCal.monday3am, calendar: cal).date)
        var dated = WakeAlarm(label: "a", hour: 7, minute: 0)
        dated.date = TestCal.date(2026, 9, 30)
        XCTAssertEqual(dated.pinningOneOffDate(now: TestCal.monday3am, calendar: cal).date, TestCal.date(2026, 9, 30))
    }
}
