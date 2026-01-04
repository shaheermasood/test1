import Foundation

// MARK: - Routine Template

public struct RoutineTemplate: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let icon: String
    public let habits: [HabitTemplate]
    public let rules: [RuleTemplate]

    public init(
        id: String,
        name: String,
        description: String,
        icon: String,
        habits: [HabitTemplate],
        rules: [RuleTemplate]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.habits = habits
        self.rules = rules
    }
}

// MARK: - Habit Template

public struct HabitTemplate: Sendable {
    public let title: String
    public let category: HabitCategory
    public let defaultPhase: PhaseName
    public let targetCountPerDay: Int

    public init(title: String, category: HabitCategory, defaultPhase: PhaseName, targetCountPerDay: Int = 1) {
        self.title = title
        self.category = category
        self.defaultPhase = defaultPhase
        self.targetCountPerDay = targetCountPerDay
    }

    public func createHabit(id: UUID, createdAt: Date) -> Habit {
        Habit(
            id: id,
            title: title,
            category: category,
            defaultPhase: defaultPhase,
            isActive: true,
            buildingType: BuildingType.forCategory(category),
            createdAt: createdAt
        )
    }

    public func createGoal(id: UUID, habitId: UUID) -> Goal {
        Goal(
            id: id,
            habitId: habitId,
            targetCountPerDay: targetCountPerDay,
            targetByPhase: nil,
            measurement: targetCountPerDay == 1 ? .boolean : .count
        )
    }
}

// MARK: - Rule Template

public struct RuleTemplate: Sendable {
    public let trigger: RuleTrigger
    public let conditions: [RuleCondition]
    public let actions: [RuleAction]

    public init(trigger: RuleTrigger, conditions: [RuleCondition], actions: [RuleAction]) {
        self.trigger = trigger
        self.conditions = conditions
        self.actions = actions
    }

    public func createRule(id: UUID, routineId: UUID, createdAt: Date) -> Rule {
        Rule(
            id: id,
            routineId: routineId,
            enabled: true,
            trigger: trigger,
            conditions: conditions,
            actions: actions,
            createdAt: createdAt
        )
    }
}

// MARK: - Built-in Templates

extension RoutineTemplate {
    public static let all: [RoutineTemplate] = [
        .mealsAndSupplements,
        .morningRoutine,
        .eveningWindDown,
        .exerciseAndMovement
    ]

    // MARK: - Meals + Supplements Template

    public static let mealsAndSupplements = RoutineTemplate(
        id: "meals_supplements",
        name: "Meals + Supplements",
        description: "Track meals and take supplements after eating",
        icon: "fork.knife.circle.fill",
        habits: [
            HabitTemplate(title: "Breakfast", category: .meal, defaultPhase: .morning),
            HabitTemplate(title: "Lunch", category: .meal, defaultPhase: .afternoon),
            HabitTemplate(title: "Dinner", category: .meal, defaultPhase: .evening),
            HabitTemplate(title: "Supplements", category: .supplements, defaultPhase: .evening)
        ],
        rules: [
            // Remind for breakfast at 8am if not eaten
            RuleTemplate(
                trigger: .absoluteTimeInPhase(.morning, hour: 8, minute: 0),
                conditions: [.notCompletedToday(habitId: UUID())], // Will be replaced with actual ID
                actions: [.notify(templateId: "breakfast_reminder", habitId: UUID(), priority: 1)]
            ),
            // Remind for lunch at 12:30pm if not eaten
            RuleTemplate(
                trigger: .absoluteTimeInPhase(.afternoon, hour: 12, minute: 30),
                conditions: [.notCompletedToday(habitId: UUID())],
                actions: [.notify(templateId: "lunch_reminder", habitId: UUID(), priority: 1)]
            ),
            // Remind for dinner at 6pm if not eaten
            RuleTemplate(
                trigger: .absoluteTimeInPhase(.evening, hour: 18, minute: 0),
                conditions: [.notCompletedToday(habitId: UUID())],
                actions: [.notify(templateId: "dinner_reminder", habitId: UUID(), priority: 1)]
            ),
            // At 9pm: if ate within 2 hours, remind for supplements
            RuleTemplate(
                trigger: .absoluteTime(hour: 21, minute: 0),
                conditions: [
                    .any([
                        .completedWithinLast(habitId: UUID(), minutes: 120), // breakfast
                        .completedWithinLast(habitId: UUID(), minutes: 120), // lunch
                        .completedWithinLast(habitId: UUID(), minutes: 120)  // dinner
                    ])
                ],
                actions: [.notify(templateId: "supplements_reminder", habitId: UUID(), priority: 2)]
            )
        ]
    )

    // MARK: - Morning Routine Template

    public static let morningRoutine = RoutineTemplate(
        id: "morning_routine",
        name: "Morning Routine",
        description: "Start your day with meditation and journaling",
        icon: "sunrise.fill",
        habits: [
            HabitTemplate(title: "Meditation", category: .meditation, defaultPhase: .morning),
            HabitTemplate(title: "Morning Journal", category: .journaling, defaultPhase: .morning),
            HabitTemplate(title: "Hydrate", category: .hydration, defaultPhase: .morning)
        ],
        rules: [
            // Morning phase start: gentle reminder
            RuleTemplate(
                trigger: .timeInPhase(.morning, minutesFromPhaseStart: 30),
                conditions: [],
                actions: [.notify(templateId: "morning_checkin", habitId: nil, priority: 1)]
            ),
            // After meditation, suggest journaling
            RuleTemplate(
                trigger: .onCompletion(habitId: UUID()),
                conditions: [],
                actions: [
                    .scheduleNotifyAt(
                        date: Date().addingTimeInterval(60), // 1 minute later
                        expiration: Date().addingTimeInterval(3600), // 1 hour expiration
                        templateId: "journal_after_meditation",
                        habitId: UUID(),
                        priority: 2
                    )
                ]
            )
        ]
    )

    // MARK: - Evening Wind Down Template

    public static let eveningWindDown = RoutineTemplate(
        id: "evening_winddown",
        name: "Evening Wind Down",
        description: "Prepare for restful sleep with a calm evening routine",
        icon: "moon.stars.fill",
        habits: [
            HabitTemplate(title: "Evening Hygiene", category: .hygiene, defaultPhase: .evening),
            HabitTemplate(title: "Evening Reflection", category: .journaling, defaultPhase: .evening),
            HabitTemplate(title: "Sleep Prep", category: .sleep, defaultPhase: .night)
        ],
        rules: [
            // Remind for evening hygiene at 9pm
            RuleTemplate(
                trigger: .absoluteTimeInPhase(.evening, hour: 21, minute: 0),
                conditions: [],
                actions: [.notify(templateId: "hygiene_reminder", habitId: UUID(), priority: 1)]
            ),
            // Remind for sleep prep at 10pm
            RuleTemplate(
                trigger: .absoluteTimeInPhase(.night, hour: 22, minute: 0),
                conditions: [],
                actions: [.notify(templateId: "sleep_prep", habitId: UUID(), priority: 2)]
            )
        ]
    )

    // MARK: - Exercise and Movement Template

    public static let exerciseAndMovement = RoutineTemplate(
        id: "exercise_movement",
        name: "Exercise & Movement",
        description: "Stay active throughout the day",
        icon: "figure.run",
        habits: [
            HabitTemplate(title: "Morning Stretch", category: .exercise, defaultPhase: .morning),
            HabitTemplate(title: "Workout", category: .exercise, defaultPhase: .afternoon),
            HabitTemplate(title: "Evening Walk", category: .exercise, defaultPhase: .evening)
        ],
        rules: [
            // Remind for morning stretch
            RuleTemplate(
                trigger: .timeInPhase(.morning, minutesFromPhaseStart: 60),
                conditions: [.notCompletedToday(habitId: UUID())],
                actions: [.notify(templateId: "stretch_reminder", habitId: UUID(), priority: 1)]
            ),
            // Remind for workout in afternoon
            RuleTemplate(
                trigger: .timeInPhase(.afternoon, minutesFromPhaseStart: 120),
                conditions: [.notCompletedToday(habitId: UUID())],
                actions: [.notify(templateId: "workout_reminder", habitId: UUID(), priority: 1)]
            )
        ]
    )
}

// MARK: - Template Instantiation

public struct TemplateInstantiator {
    public init() {}

    /// Create habits, goals, routine, and rules from a template
    public func instantiate(
        template: RoutineTemplate,
        uuidGenerator: () -> UUID = UUID.init,
        dateGenerator: () -> Date = Date.init
    ) -> (routine: Routine, habits: [Habit], goals: [Goal], rules: [Rule]) {
        let routineId = uuidGenerator()
        let createdAt = dateGenerator()

        // Create habits
        var habits: [Habit] = []
        var habitIdMap: [Int: UUID] = [:]

        for (index, habitTemplate) in template.habits.enumerated() {
            let habitId = uuidGenerator()
            habitIdMap[index] = habitId

            let habit = habitTemplate.createHabit(id: habitId, createdAt: createdAt)
            habits.append(habit)
        }

        // Create goals
        var goals: [Goal] = []
        for (index, habitTemplate) in template.habits.enumerated() {
            guard let habitId = habitIdMap[index] else { continue }
            let goalId = uuidGenerator()
            let goal = habitTemplate.createGoal(id: goalId, habitId: habitId)
            goals.append(goal)
        }

        // Create rules (need to map habit indices to actual UUIDs)
        var rules: [Rule] = []
        for ruleTemplate in template.rules {
            let ruleId = uuidGenerator()
            let rule = ruleTemplate.createRule(id: ruleId, routineId: routineId, createdAt: createdAt)
            rules.append(rule)
        }

        // Create routine
        let routine = Routine(
            id: routineId,
            name: template.name,
            habitIds: habits.map(\.id),
            ruleIds: rules.map(\.id),
            isActive: true,
            createdAt: createdAt
        )

        return (routine, habits, goals, rules)
    }
}
