import XCTest
@testable import HabitTracker

final class RuleEngineTests: XCTestCase {
    var engine: RuleEngine!
    var habitId: UUID!
    var ruleId: UUID!

    override func setUp() {
        super.setUp()
        engine = RuleEngine()
        habitId = UUID()
        ruleId = UUID()
    }

    // MARK: - Condition Tests

    func testCompletedToday_WhenCompleted_ReturnsTrue() {
        let context = makeContext(
            completions: [makeCompletion(habitId: habitId, timestamp: Date())]
        )

        let rule = makeRule(
            trigger: .phaseStart(.morning),
            conditions: [.completedToday(habitId: habitId)],
            actions: [.notify(templateId: "test", habitId: habitId, priority: 1)]
        )

        let decisions = engine.evaluate(
            rules: [rule],
            context: context,
            event: .phaseChange(from: nil, to: .morning)
        )

        // Should trigger because habit was completed today
        XCTAssertTrue(decisions.isEmpty == false)
    }

    func testCompletedToday_WhenNotCompleted_ReturnsFalse() {
        let context = makeContext(completions: [])

        let rule = makeRule(
            trigger: .phaseStart(.morning),
            conditions: [.completedToday(habitId: habitId)],
            actions: [.notify(templateId: "test", habitId: habitId, priority: 1)]
        )

        let decisions = engine.evaluate(
            rules: [rule],
            context: context,
            event: .phaseChange(from: nil, to: .morning)
        )

        // Should NOT trigger because habit was not completed
        XCTAssertTrue(decisions.isEmpty)
    }

    func testCompletedWithinLast_Within120Minutes_ReturnsTrue() {
        let twoHoursAgo = Date().addingTimeInterval(-120 * 60)
        let context = makeContext(
            completions: [makeCompletion(habitId: habitId, timestamp: twoHoursAgo)]
        )

        let rule = makeRule(
            trigger: .phaseStart(.evening),
            conditions: [.completedWithinLast(habitId: habitId, minutes: 120)],
            actions: [.notify(templateId: "test", habitId: habitId, priority: 1)]
        )

        let decisions = engine.evaluate(
            rules: [rule],
            context: context,
            event: .phaseChange(from: .afternoon, to: .evening)
        )

        XCTAssertTrue(decisions.isEmpty == false)
    }

    func testCompletedWithinLast_Beyond120Minutes_ReturnsFalse() {
        let threeHoursAgo = Date().addingTimeInterval(-180 * 60)
        let context = makeContext(
            completions: [makeCompletion(habitId: habitId, timestamp: threeHoursAgo)]
        )

        let rule = makeRule(
            trigger: .phaseStart(.evening),
            conditions: [.completedWithinLast(habitId: habitId, minutes: 120)],
            actions: [.notify(templateId: "test", habitId: habitId, priority: 1)]
        )

        let decisions = engine.evaluate(
            rules: [rule],
            context: context,
            event: .phaseChange(from: .afternoon, to: .evening)
        )

        XCTAssertTrue(decisions.isEmpty)
    }

    func testCountCompletedToday_MeetsThreshold_ReturnsTrue() {
        let context = makeContext(
            completions: [
                makeCompletion(habitId: habitId, timestamp: Date().addingTimeInterval(-3600)),
                makeCompletion(habitId: habitId, timestamp: Date().addingTimeInterval(-1800)),
                makeCompletion(habitId: habitId, timestamp: Date())
            ]
        )

        let rule = makeRule(
            trigger: .phaseStart(.evening),
            conditions: [.countCompletedToday(habitId: habitId, atLeast: 3)],
            actions: [.notify(templateId: "test", habitId: habitId, priority: 1)]
        )

        let decisions = engine.evaluate(
            rules: [rule],
            context: context,
            event: .phaseChange(from: .afternoon, to: .evening)
        )

        XCTAssertTrue(decisions.isEmpty == false)
    }

    func testCountCompletedToday_BelowThreshold_ReturnsFalse() {
        let context = makeContext(
            completions: [
                makeCompletion(habitId: habitId, timestamp: Date())
            ]
        )

        let rule = makeRule(
            trigger: .phaseStart(.evening),
            conditions: [.countCompletedToday(habitId: habitId, atLeast: 3)],
            actions: [.notify(templateId: "test", habitId: habitId, priority: 1)]
        )

        let decisions = engine.evaluate(
            rules: [rule],
            context: context,
            event: .phaseChange(from: .afternoon, to: .evening)
        )

        XCTAssertTrue(decisions.isEmpty)
    }

    // MARK: - Cascading Example

    func testCascadingReminder_SupplementsAfterMeal() {
        let mealHabitId = UUID()
        let supplementsHabitId = UUID()

        // Meal was completed 30 minutes ago
        let mealTime = Date().addingTimeInterval(-30 * 60)
        let context = makeContext(
            completions: [makeCompletion(habitId: mealHabitId, timestamp: mealTime)]
        )

        // Rule: If meal within 120 min, remind for supplements
        let rule = makeRule(
            trigger: .phaseStart(.evening),
            conditions: [.completedWithinLast(habitId: mealHabitId, minutes: 120)],
            actions: [.notify(templateId: "supplements", habitId: supplementsHabitId, priority: 2)]
        )

        let decisions = engine.evaluate(
            rules: [rule],
            context: context,
            event: .phaseChange(from: .afternoon, to: .evening)
        )

        XCTAssertTrue(decisions.count == 1)
        if case .scheduleReminder(_, let habitId, _, _, _, let templateId, let priority) = decisions[0] {
            XCTAssertEqual(habitId, supplementsHabitId)
            XCTAssertEqual(templateId, "supplements")
            XCTAssertEqual(priority, 2)
        } else {
            XCTFail("Expected scheduleReminder decision")
        }
    }

    // MARK: - Throttling Tests

    func testThrottling_RespectsNotificationCap() {
        let context = makeContext(
            completions: [],
            existingReminders: Array(repeating: makeReminder(state: .scheduled), count: 8), // Cap reached
            settings: UserSettings(notificationCapPerDay: 8)
        )

        let rule = makeRule(
            trigger: .phaseStart(.evening),
            conditions: [],
            actions: [.notify(templateId: "test", habitId: habitId, priority: 1)]
        )

        let decisions = engine.evaluate(
            rules: [rule],
            context: context,
            event: .phaseChange(from: .afternoon, to: .evening)
        )

        // Should be throttled due to cap
        XCTAssertTrue(decisions.isEmpty)
    }

    func testThrottling_PrioritizesHigherPriority() {
        let context = makeContext(
            completions: [],
            existingReminders: Array(repeating: makeReminder(state: .scheduled), count: 7), // 1 slot left
            settings: UserSettings(notificationCapPerDay: 8)
        )

        let lowPriorityRule = makeRule(
            trigger: .phaseStart(.evening),
            conditions: [],
            actions: [.notify(templateId: "low", habitId: habitId, priority: 1)]
        )

        let highPriorityRule = makeRule(
            trigger: .phaseStart(.evening),
            conditions: [],
            actions: [.notify(templateId: "high", habitId: habitId, priority: 10)]
        )

        let decisions = engine.evaluate(
            rules: [lowPriorityRule, highPriorityRule],
            context: context,
            event: .phaseChange(from: .afternoon, to: .evening)
        )

        // Should only schedule the high priority one
        XCTAssertEqual(decisions.count, 1)
        if case .scheduleReminder(_, _, _, _, _, let templateId, let priority) = decisions[0] {
            XCTAssertEqual(templateId, "high")
            XCTAssertEqual(priority, 10)
        } else {
            XCTFail("Expected scheduleReminder decision")
        }
    }

    // MARK: - Helpers

    private func makeContext(
        completions: [CompletionEvent] = [],
        existingReminders: [Reminder] = [],
        settings: UserSettings = UserSettings()
    ) -> DayContext {
        let phases = makeMockPhases()
        return DayContext(
            dateKey: "2025-01-05",
            currentDate: Date(),
            phases: phases,
            completionEvents: completions,
            existingReminders: existingReminders,
            returnHooks: [],
            settings: settings,
            dayService: DayService(resetHour: 2, resetMinute: 0)
        )
    }

    private func makeMockPhases() -> DayPhases {
        let now = Date()
        let calendar = Calendar.current
        let morning = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: now)!
        let afternoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!
        let evening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now)!
        let night = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: now)!
        let nextMorning = calendar.date(byAdding: .day, value: 1, to: morning)!

        return DayPhases(
            dateKey: "2025-01-05",
            intervals: [
                PhaseInterval(phase: .morning, startDate: morning, endDate: afternoon),
                PhaseInterval(phase: .afternoon, startDate: afternoon, endDate: evening),
                PhaseInterval(phase: .evening, startDate: evening, endDate: night),
                PhaseInterval(phase: .night, startDate: night, endDate: nextMorning)
            ],
            computedAt: now
        )
    }

    private func makeCompletion(habitId: UUID, timestamp: Date) -> CompletionEvent {
        CompletionEvent(
            id: UUID(),
            habitId: habitId,
            timestamp: timestamp,
            dateKey: "2025-01-05",
            metadata: CompletionMetadata()
        )
    }

    private func makeReminder(state: ReminderState) -> Reminder {
        Reminder(
            id: UUID(),
            habitId: habitId,
            ruleId: ruleId,
            dateKey: "2025-01-05",
            fireDate: Date(),
            expirationDate: Date().addingTimeInterval(3600),
            notificationId: UUID().uuidString,
            state: state,
            priority: 1,
            templateId: "test"
        )
    }

    private func makeRule(
        trigger: RuleTrigger,
        conditions: [RuleCondition],
        actions: [RuleAction]
    ) -> Rule {
        Rule(
            id: ruleId,
            routineId: UUID(),
            enabled: true,
            trigger: trigger,
            conditions: conditions,
            actions: actions,
            createdAt: Date()
        )
    }
}
