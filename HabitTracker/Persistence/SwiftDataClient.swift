import Foundation
import SwiftData
import Dependencies

// MARK: - SwiftData Client

public struct SwiftDataClient: Sendable {
    // Settings
    public var fetchSettings: @Sendable () async throws -> UserSettings
    public var saveSettings: @Sendable (UserSettings) async throws -> Void

    // Habits
    public var fetchHabits: @Sendable () async throws -> [Habit]
    public var fetchHabit: @Sendable (UUID) async throws -> Habit?
    public var saveHabit: @Sendable (Habit) async throws -> Void
    public var deleteHabit: @Sendable (UUID) async throws -> Void

    // Goals
    public var fetchGoals: @Sendable () async throws -> [Goal]
    public var fetchGoalsForHabit: @Sendable (UUID) async throws -> [Goal]
    public var saveGoal: @Sendable (Goal) async throws -> Void
    public var deleteGoal: @Sendable (UUID) async throws -> Void

    // Routines
    public var fetchRoutines: @Sendable () async throws -> [Routine]
    public var fetchRoutine: @Sendable (UUID) async throws -> Routine?
    public var saveRoutine: @Sendable (Routine) async throws -> Void
    public var deleteRoutine: @Sendable (UUID) async throws -> Void

    // Rules
    public var fetchRules: @Sendable () async throws -> [Rule]
    public var fetchRulesForRoutine: @Sendable (UUID) async throws -> [Rule]
    public var saveRule: @Sendable (Rule) async throws -> Void
    public var deleteRule: @Sendable (UUID) async throws -> Void

    // Daily Logs
    public var fetchDailyLog: @Sendable (String) async throws -> DailyLog?
    public var saveDailyLog: @Sendable (DailyLog) async throws -> Void

    // Completion Events
    public var fetchCompletionEvents: @Sendable (String) async throws -> [CompletionEvent]
    public var fetchCompletionEventsForHabit: @Sendable (UUID, String) async throws -> [CompletionEvent]
    public var saveCompletionEvent: @Sendable (CompletionEvent) async throws -> Void
    public var deleteCompletionEvent: @Sendable (UUID) async throws -> Void

    // Reminders
    public var fetchReminders: @Sendable (String) async throws -> [Reminder]
    public var saveReminder: @Sendable (Reminder) async throws -> Void
    public var updateReminderState: @Sendable (UUID, ReminderState) async throws -> Void
    public var deleteReminder: @Sendable (UUID) async throws -> Void

    // Salvage Plans
    public var fetchSalvagePlans: @Sendable (String) async throws -> [SalvagePlan]
    public var saveSalvagePlan: @Sendable (SalvagePlan) async throws -> Void
}

// MARK: - Dependency

extension SwiftDataClient: DependencyKey {
    public static let liveValue: SwiftDataClient = {
        // Create ModelContainer
        let schema = Schema([
            UserSettingsModel.self,
            HabitModel.self,
            GoalModel.self,
            RoutineModel.self,
            RuleModel.self,
            DailyLogModel.self,
            CompletionEventModel.self,
            ReminderModel.self,
            SalvagePlanModel.self
        ])

        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        guard let container = try? ModelContainer(for: schema, configurations: [modelConfiguration]) else {
            fatalError("Could not create ModelContainer")
        }

        let context = ModelContext(container)

        return SwiftDataClient(
            // Settings
            fetchSettings: {
                let descriptor = FetchDescriptor<UserSettingsModel>()
                let models = try context.fetch(descriptor)
                if let model = models.first {
                    return model.toDomain()
                } else {
                    // Create default settings
                    let defaultSettings = UserSettings()
                    let model = UserSettingsModel()
                    model.update(from: defaultSettings)
                    context.insert(model)
                    try context.save()
                    return defaultSettings
                }
            },
            saveSettings: { settings in
                let descriptor = FetchDescriptor<UserSettingsModel>()
                let models = try context.fetch(descriptor)
                if let model = models.first {
                    model.update(from: settings)
                } else {
                    let model = UserSettingsModel()
                    model.update(from: settings)
                    context.insert(model)
                }
                try context.save()
            },

            // Habits
            fetchHabits: {
                let descriptor = FetchDescriptor<HabitModel>(sortBy: [SortDescriptor(\.createdAt)])
                let models = try context.fetch(descriptor)
                return models.map { $0.toDomain() }
            },
            fetchHabit: { id in
                let descriptor = FetchDescriptor<HabitModel>(
                    predicate: #Predicate { $0.id == id }
                )
                let models = try context.fetch(descriptor)
                return models.first?.toDomain()
            },
            saveHabit: { habit in
                let descriptor = FetchDescriptor<HabitModel>(
                    predicate: #Predicate { $0.id == habit.id }
                )
                let existing = try context.fetch(descriptor).first

                if let existing = existing {
                    existing.title = habit.title
                    existing.categoryRawValue = habit.category.rawValue
                    existing.defaultPhaseRawValue = habit.defaultPhase.rawValue
                    existing.isActive = habit.isActive
                    existing.buildingTypeRawValue = habit.buildingType.rawValue
                } else {
                    let model = HabitModel(from: habit)
                    context.insert(model)
                }
                try context.save()
            },
            deleteHabit: { id in
                let descriptor = FetchDescriptor<HabitModel>(
                    predicate: #Predicate { $0.id == id }
                )
                if let model = try context.fetch(descriptor).first {
                    context.delete(model)
                    try context.save()
                }
            },

            // Goals
            fetchGoals: {
                let descriptor = FetchDescriptor<GoalModel>()
                let models = try context.fetch(descriptor)
                return models.map { $0.toDomain() }
            },
            fetchGoalsForHabit: { habitId in
                let descriptor = FetchDescriptor<GoalModel>(
                    predicate: #Predicate { $0.habitId == habitId }
                )
                let models = try context.fetch(descriptor)
                return models.map { $0.toDomain() }
            },
            saveGoal: { goal in
                let descriptor = FetchDescriptor<GoalModel>(
                    predicate: #Predicate { $0.id == goal.id }
                )
                let existing = try context.fetch(descriptor).first

                if let existing = existing {
                    existing.habitId = goal.habitId
                    existing.targetCountPerDay = goal.targetCountPerDay
                    existing.targetByPhaseData = try? JSONEncoder().encode(goal.targetByPhase)
                    existing.measurementRawValue = goal.measurement.rawValue
                } else {
                    let model = GoalModel(from: goal)
                    context.insert(model)
                }
                try context.save()
            },
            deleteGoal: { id in
                let descriptor = FetchDescriptor<GoalModel>(
                    predicate: #Predicate { $0.id == id }
                )
                if let model = try context.fetch(descriptor).first {
                    context.delete(model)
                    try context.save()
                }
            },

            // Routines
            fetchRoutines: {
                let descriptor = FetchDescriptor<RoutineModel>(sortBy: [SortDescriptor(\.createdAt)])
                let models = try context.fetch(descriptor)
                return models.map { $0.toDomain() }
            },
            fetchRoutine: { id in
                let descriptor = FetchDescriptor<RoutineModel>(
                    predicate: #Predicate { $0.id == id }
                )
                let models = try context.fetch(descriptor)
                return models.first?.toDomain()
            },
            saveRoutine: { routine in
                let descriptor = FetchDescriptor<RoutineModel>(
                    predicate: #Predicate { $0.id == routine.id }
                )
                let existing = try context.fetch(descriptor).first

                if let existing = existing {
                    existing.name = routine.name
                    existing.habitIdsData = (try? JSONEncoder().encode(routine.habitIds)) ?? Data()
                    existing.ruleIdsData = (try? JSONEncoder().encode(routine.ruleIds)) ?? Data()
                    existing.isActive = routine.isActive
                } else {
                    let model = RoutineModel(from: routine)
                    context.insert(model)
                }
                try context.save()
            },
            deleteRoutine: { id in
                let descriptor = FetchDescriptor<RoutineModel>(
                    predicate: #Predicate { $0.id == id }
                )
                if let model = try context.fetch(descriptor).first {
                    context.delete(model)
                    try context.save()
                }
            },

            // Rules
            fetchRules: {
                let descriptor = FetchDescriptor<RuleModel>()
                let models = try context.fetch(descriptor)
                return models.compactMap { $0.toDomain() }
            },
            fetchRulesForRoutine: { routineId in
                let descriptor = FetchDescriptor<RuleModel>(
                    predicate: #Predicate { $0.routineId == routineId }
                )
                let models = try context.fetch(descriptor)
                return models.compactMap { $0.toDomain() }
            },
            saveRule: { rule in
                let descriptor = FetchDescriptor<RuleModel>(
                    predicate: #Predicate { $0.id == rule.id }
                )
                let existing = try context.fetch(descriptor).first

                if let existing = existing {
                    existing.enabled = rule.enabled
                    existing.triggerData = (try? JSONEncoder().encode(rule.trigger)) ?? Data()
                    existing.conditionsData = (try? JSONEncoder().encode(rule.conditions)) ?? Data()
                    existing.actionsData = (try? JSONEncoder().encode(rule.actions)) ?? Data()
                } else {
                    let model = RuleModel(from: rule)
                    context.insert(model)
                }
                try context.save()
            },
            deleteRule: { id in
                let descriptor = FetchDescriptor<RuleModel>(
                    predicate: #Predicate { $0.id == id }
                )
                if let model = try context.fetch(descriptor).first {
                    context.delete(model)
                    try context.save()
                }
            },

            // Daily Logs
            fetchDailyLog: { dateKey in
                let descriptor = FetchDescriptor<DailyLogModel>(
                    predicate: #Predicate { $0.dateKey == dateKey }
                )
                let models = try context.fetch(descriptor)
                return models.first?.toDomain()
            },
            saveDailyLog: { log in
                let descriptor = FetchDescriptor<DailyLogModel>(
                    predicate: #Predicate { $0.dateKey == log.dateKey }
                )
                let existing = try context.fetch(descriptor).first

                if let existing = existing {
                    existing.returnHooksData = (try? JSONEncoder().encode(log.returnHooks)) ?? Data()
                    existing.summaryData = try? JSONEncoder().encode(log.summary)
                } else {
                    let model = DailyLogModel(from: log)
                    context.insert(model)
                }
                try context.save()
            },

            // Completion Events
            fetchCompletionEvents: { dateKey in
                let descriptor = FetchDescriptor<CompletionEventModel>(
                    predicate: #Predicate { $0.dateKey == dateKey },
                    sortBy: [SortDescriptor(\.timestamp)]
                )
                let models = try context.fetch(descriptor)
                return models.map { $0.toDomain() }
            },
            fetchCompletionEventsForHabit: { habitId, dateKey in
                let descriptor = FetchDescriptor<CompletionEventModel>(
                    predicate: #Predicate { $0.habitId == habitId && $0.dateKey == dateKey },
                    sortBy: [SortDescriptor(\.timestamp)]
                )
                let models = try context.fetch(descriptor)
                return models.map { $0.toDomain() }
            },
            saveCompletionEvent: { event in
                let model = CompletionEventModel(from: event)
                context.insert(model)
                try context.save()
            },
            deleteCompletionEvent: { id in
                let descriptor = FetchDescriptor<CompletionEventModel>(
                    predicate: #Predicate { $0.id == id }
                )
                if let model = try context.fetch(descriptor).first {
                    context.delete(model)
                    try context.save()
                }
            },

            // Reminders
            fetchReminders: { dateKey in
                let descriptor = FetchDescriptor<ReminderModel>(
                    predicate: #Predicate { $0.dateKey == dateKey },
                    sortBy: [SortDescriptor(\.fireDate)]
                )
                let models = try context.fetch(descriptor)
                return models.map { $0.toDomain() }
            },
            saveReminder: { reminder in
                let descriptor = FetchDescriptor<ReminderModel>(
                    predicate: #Predicate { $0.id == reminder.id }
                )
                let existing = try context.fetch(descriptor).first

                if let existing = existing {
                    existing.stateRawValue = reminder.state.rawValue
                    existing.priority = reminder.priority
                } else {
                    let model = ReminderModel(from: reminder)
                    context.insert(model)
                }
                try context.save()
            },
            updateReminderState: { id, state in
                let descriptor = FetchDescriptor<ReminderModel>(
                    predicate: #Predicate { $0.id == id }
                )
                if let model = try context.fetch(descriptor).first {
                    model.stateRawValue = state.rawValue
                    try context.save()
                }
            },
            deleteReminder: { id in
                let descriptor = FetchDescriptor<ReminderModel>(
                    predicate: #Predicate { $0.id == id }
                )
                if let model = try context.fetch(descriptor).first {
                    context.delete(model)
                    try context.save()
                }
            },

            // Salvage Plans
            fetchSalvagePlans: { dateKey in
                let descriptor = FetchDescriptor<SalvagePlanModel>(
                    predicate: #Predicate { $0.dateKey == dateKey },
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
                let models = try context.fetch(descriptor)
                return models.map { $0.toDomain() }
            },
            saveSalvagePlan: { plan in
                let descriptor = FetchDescriptor<SalvagePlanModel>(
                    predicate: #Predicate { $0.id == plan.id }
                )
                let existing = try context.fetch(descriptor).first

                if let existing = existing {
                    existing.title = plan.title
                    existing.message = plan.message
                    existing.rebalancedItemsData = (try? JSONEncoder().encode(plan.rebalancedItems)) ?? Data()
                    existing.isAccepted = plan.isAccepted
                    existing.acceptedAt = plan.acceptedAt
                } else {
                    let model = SalvagePlanModel(from: plan)
                    context.insert(model)
                }
                try context.save()
            }
        )
    }()

    public static let testValue = SwiftDataClient(
        fetchSettings: { UserSettings() },
        saveSettings: { _ in },
        fetchHabits: { [] },
        fetchHabit: { _ in nil },
        saveHabit: { _ in },
        deleteHabit: { _ in },
        fetchGoals: { [] },
        fetchGoalsForHabit: { _ in [] },
        saveGoal: { _ in },
        deleteGoal: { _ in },
        fetchRoutines: { [] },
        fetchRoutine: { _ in nil },
        saveRoutine: { _ in },
        deleteRoutine: { _ in },
        fetchRules: { [] },
        fetchRulesForRoutine: { _ in [] },
        saveRule: { _ in },
        deleteRule: { _ in },
        fetchDailyLog: { _ in nil },
        saveDailyLog: { _ in },
        fetchCompletionEvents: { _ in [] },
        fetchCompletionEventsForHabit: { _, _ in [] },
        saveCompletionEvent: { _ in },
        deleteCompletionEvent: { _ in },
        fetchReminders: { _ in [] },
        saveReminder: { _ in },
        updateReminderState: { _, _ in },
        deleteReminder: { _ in },
        fetchSalvagePlans: { _ in [] },
        saveSalvagePlan: { _ in }
    )
}

extension DependencyValues {
    public var swiftDataClient: SwiftDataClient {
        get { self[SwiftDataClient.self] }
        set { self[SwiftDataClient.self] = newValue }
    }
}
