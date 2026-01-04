import XCTest
@testable import HabitTracker

final class DayServiceTests: XCTestCase {
    var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar.current
    }

    // MARK: - 2am Boundary Tests

    func testDateKey_Before2AM_BelongsToPreviousDay() {
        // 1:30 AM on Jan 5 should belong to Jan 4
        let date = makeDate(year: 2025, month: 1, day: 5, hour: 1, minute: 30)
        let settings = UserSettings(resetHourMinute: (2, 0))
        let dayService = DayService(resetHour: 2, resetMinute: 0)

        let dateKey = dayService.dateKey(for: date)

        XCTAssertEqual(dateKey, "2025-01-04")
    }

    func testDateKey_At2AM_BelongsToCurrentDay() {
        // 2:00 AM on Jan 5 should belong to Jan 5
        let date = makeDate(year: 2025, month: 1, day: 5, hour: 2, minute: 0)
        let dayService = DayService(resetHour: 2, resetMinute: 0)

        let dateKey = dayService.dateKey(for: date)

        XCTAssertEqual(dateKey, "2025-01-05")
    }

    func testDateKey_After2AM_BelongsToCurrentDay() {
        // 10:00 AM on Jan 5 should belong to Jan 5
        let date = makeDate(year: 2025, month: 1, day: 5, hour: 10, minute: 0)
        let dayService = DayService(resetHour: 2, resetMinute: 0)

        let dateKey = dayService.dateKey(for: date)

        XCTAssertEqual(dateKey, "2025-01-05")
    }

    func testDateKey_CustomResetTime_3AM() {
        // 2:30 AM with 3am reset should belong to previous day
        let date = makeDate(year: 2025, month: 1, day: 5, hour: 2, minute: 30)
        let dayService = DayService(resetHour: 3, resetMinute: 0)

        let dateKey = dayService.dateKey(for: date)

        XCTAssertEqual(dateKey, "2025-01-04")
    }

    func testDateKey_MonthBoundary() {
        // 1:00 AM on Feb 1 should belong to Jan 31
        let date = makeDate(year: 2025, month: 2, day: 1, hour: 1, minute: 0)
        let dayService = DayService(resetHour: 2, resetMinute: 0)

        let dateKey = dayService.dateKey(for: date)

        XCTAssertEqual(dateKey, "2025-01-31")
    }

    func testDateKey_YearBoundary() {
        // 1:00 AM on Jan 1 2026 should belong to Dec 31 2025
        let date = makeDate(year: 2026, month: 1, day: 1, hour: 1, minute: 0)
        let dayService = DayService(resetHour: 2, resetMinute: 0)

        let dateKey = dayService.dateKey(for: date)

        XCTAssertEqual(dateKey, "2025-12-31")
    }

    // MARK: - Helper

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)!
    }
}
