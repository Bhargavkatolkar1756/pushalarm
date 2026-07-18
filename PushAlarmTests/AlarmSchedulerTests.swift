// PushAlarm — AlarmSchedulerTests.swift
// Unit tests for alarm next-fire-date logic and repeat-day summary.

import XCTest
@testable import PushAlarm

final class AlarmNextFireDateTests: XCTestCase {

    // Helper: create a reference date for "Wednesday 2025-01-15 at 09:00"
    private func makeDate(weekday: Int, hour: Int, minute: Int) -> Date {
        // weekday: 1=Sun, 2=Mon … 7=Sat
        var comps = DateComponents()
        comps.year    = 2025
        comps.weekday = weekday
        comps.hour    = hour
        comps.minute  = minute
        comps.second  = 0
        // Start from a known Wednesday (Jan 15, 2025) and adjust
        let base = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 15))!
        return Calendar.current.nextDate(
            after: base.addingTimeInterval(-86400 * 7),
            matching: comps,
            matchingPolicy: .nextTime
        )!
    }

    func testOneShot_futureTime_firesSameDay() {
        var alarm = Alarm(hour: 23, minute: 59, repeatDays: [])
        alarm.isEnabled = true
        // Use a time early in the morning so 23:59 is in the future
        let now = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 15, hour: 6, minute: 0))!
        let next = alarm.nextFireDate(from: now)
        XCTAssertNotNil(next)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: next!)
        XCTAssertEqual(comps.hour,   23)
        XCTAssertEqual(comps.minute, 59)
    }

    func testOneShot_pastTime_firesNextDay() {
        var alarm = Alarm(hour: 6, minute: 0, repeatDays: [])
        alarm.isEnabled = true
        // Now is 09:00 — 06:00 has already passed today
        let now = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 15, hour: 9, minute: 0))!
        let next = alarm.nextFireDate(from: now)
        XCTAssertNotNil(next)
        // Should be tomorrow at 06:00
        let nowDay  = Calendar.current.component(.day, from: now)
        let nextDay = Calendar.current.component(.day, from: next!)
        XCTAssertEqual(nextDay, nowDay + 1, "Missed time should schedule next day")
    }

    func testDisabledAlarm_returnsNil() {
        var alarm = Alarm(hour: 7, minute: 0, repeatDays: [.monday])
        alarm.isEnabled = false
        XCTAssertNil(alarm.nextFireDate(), "Disabled alarm should return nil")
    }

    func testRepeatAlarm_picksEarliestDay() {
        // Set alarm on Monday and Friday, called on Wednesday at 12:00
        // Earliest next occurrence should be Friday
        var alarm = Alarm(hour: 7, minute: 0, repeatDays: [.monday, .friday])
        alarm.isEnabled = true
        // Wednesday Jan 15 2025 at 12:00
        let now = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 15, hour: 12, minute: 0))!
        let next = alarm.nextFireDate(from: now)
        XCTAssertNotNil(next)
        let weekday = Calendar.current.component(.weekday, from: next!)
        // Friday = weekday 6
        XCTAssertEqual(weekday, 6, "Next fire should be Friday (weekday 6)")
    }

    // MARK: - Repeat Summary Tests

    func testRepeatSummary_empty_isOnce() {
        let alarm = Alarm(repeatDays: [])
        XCTAssertEqual(alarm.repeatSummary, "Once")
    }

    func testRepeatSummary_allDays_isEveryDay() {
        let all: Set<WeekDay> = Set(WeekDay.allCases)
        let alarm = Alarm(repeatDays: all)
        XCTAssertEqual(alarm.repeatSummary, "Every Day")
    }

    func testRepeatSummary_weekdays_isWeekdays() {
        let alarm = Alarm(repeatDays: [.monday, .tuesday, .wednesday, .thursday, .friday])
        XCTAssertEqual(alarm.repeatSummary, "Weekdays")
    }

    func testRepeatSummary_weekend_isWeekends() {
        let alarm = Alarm(repeatDays: [.saturday, .sunday])
        XCTAssertEqual(alarm.repeatSummary, "Weekends")
    }

    func testRepeatSummary_custom_abbreviations() {
        let alarm = Alarm(repeatDays: [.monday, .wednesday, .friday])
        let summary = alarm.repeatSummary
        XCTAssertTrue(summary.contains("Mo"), "Should contain Mo")
        XCTAssertTrue(summary.contains("We"), "Should contain We")
        XCTAssertTrue(summary.contains("Fr"), "Should contain Fr")
        XCTAssertFalse(summary.contains("Tu"), "Should not contain Tu")
    }

    // MARK: - Time String Tests

    func testTimeString_midnight() {
        let alarm = Alarm(hour: 0, minute: 0)
        XCTAssertEqual(alarm.timeString, "12:00 AM")
    }

    func testTimeString_noon() {
        let alarm = Alarm(hour: 12, minute: 0)
        XCTAssertEqual(alarm.timeString, "12:00 PM")
    }

    func testTimeString_7am() {
        let alarm = Alarm(hour: 7, minute: 5)
        XCTAssertEqual(alarm.timeString, "7:05 AM")
    }

    func testTimeString_11pm() {
        let alarm = Alarm(hour: 23, minute: 59)
        XCTAssertEqual(alarm.timeString, "11:59 PM")
    }
}
