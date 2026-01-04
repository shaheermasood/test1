import Foundation
import SwiftData

// MARK: - SwiftData Models

// NOTE: SwiftData models use @Model macro and are classes (not structs)
// They serve as the persistence layer and map to/from domain models

@Model
final class UserSettingsModel {
    @Attribute(.unique) var id: UUID
    var resetHour: Int
    var resetMinute: Int
    var notificationCapPerDay: Int
    var notificationCooldownMinutes: Int
    var phaseModeRawValue: String
    var manualPhaseOverridesData: Data?
    var toneRawValue: String
    var locationEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        resetHour: Int = 2,
        resetMinute: Int = 0,
        notificationCapPerDay: Int = 8,
        notificationCooldownMinutes: Int = 45,
        phaseModeRawValue: String = PhaseMode.autoSolar.rawValue,
        manualPhaseOverridesData: Data? = nil,
        toneRawValue: String = NotificationTone.zenCoach.rawValue,
        locationEnabled: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.resetHour = resetHour
        self.resetMinute = resetMinute
        self.notificationCapPerDay = notificationCapPerDay
        self.notificationCooldownMinutes = notificationCooldownMinutes
        self.phaseModeRawValue = phaseModeRawValue
        self.manualPhaseOverridesData = manualPhaseOverridesData
        self.toneRawValue = toneRawValue
        self.locationEnabled = locationEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func toDomain() -> UserSettings {
        let phaseMode = PhaseMode(rawValue: phaseModeRawValue) ?? .autoSolar
        let tone = NotificationTone(rawValue: toneRawValue) ?? .zenCoach

        var overrides: [PhaseName: PhaseOverride] = [:]
        if let data = manualPhaseOverridesData {
            overrides = (try? JSONDecoder().decode([PhaseName: PhaseOverride].self, from: data)) ?? [:]
        }

        return UserSettings(
            resetHourMinute: (resetHour, resetMinute),
            notificationCapPerDay: notificationCapPerDay,
            notificationCooldownMinutes: notificationCooldownMinutes,
            phaseMode: phaseMode,
            manualPhaseOverrides: overrides,
            tone: tone,
            locationEnabled: locationEnabled
        )
    }

    func update(from settings: UserSettings) {
        self.resetHour = settings.resetHourMinute.hour
        self.resetMinute = settings.resetHourMinute.minute
        self.notificationCapPerDay = settings.notificationCapPerDay
        self.notificationCooldownMinutes = settings.notificationCooldownMinutes
        self.phaseModeRawValue = settings.phaseMode.rawValue
        self.toneRawValue = settings.tone.rawValue
        self.locationEnabled = settings.locationEnabled
        self.manualPhaseOverridesData = try? JSONEncoder().encode(settings.manualPhaseOverrides)
        self.updatedAt = Date()
    }
}

@Model
final class HabitModel {
    @Attribute(.unique) var id: UUID
    var title: String
    var categoryRawValue: String
    var defaultPhaseRawValue: String
    var isActive: Bool
    var buildingTypeRawValue: String
    var createdAt: Date

    init(
        id: UUID,
        title: String,
        categoryRawValue: String,
        defaultPhaseRawValue: String,
        isActive: Bool = true,
        buildingTypeRawValue: String,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.categoryRawValue = categoryRawValue
        self.defaultPhaseRawValue = defaultPhaseRawValue
        self.isActive = isActive
        self.buildingTypeRawValue = buildingTypeRawValue
        self.createdAt = createdAt
    }

    convenience init(from habit: Habit) {
        self.init(
            id: habit.id,
            title: habit.title,
            categoryRawValue: habit.category.rawValue,
            defaultPhaseRawValue: habit.defaultPhase.rawValue,
            isActive: habit.isActive,
            buildingTypeRawValue: habit.buildingType.rawValue,
            createdAt: habit.createdAt
        )
    }

    func toDomain() -> Habit {
        Habit(
            id: id,
            title: title,
            category: HabitCategory(rawValue: categoryRawValue) ?? .general,
            defaultPhase: PhaseName(rawValue: defaultPhaseRawValue) ?? .morning,
            isActive: isActive,
            buildingType: BuildingType(rawValue: buildingTypeRawValue) ?? .house,
            createdAt: createdAt
        )
    }
}

@Model
final class GoalModel {
    @Attribute(.unique) var id: UUID
    var habitId: UUID
    var targetCountPerDay: Int
    var targetByPhaseData: Data?
    var measurementRawValue: String

    init(
        id: UUID,
        habitId: UUID,
        targetCountPerDay: Int,
        targetByPhaseData: Data? = nil,
        measurementRawValue: String
    ) {
        self.id = id
        self.habitId = habitId
        self.targetCountPerDay = targetCountPerDay
        self.targetByPhaseData = targetByPhaseData
        self.measurementRawValue = measurementRawValue
    }

    convenience init(from goal: Goal) {
        let targetData = try? JSONEncoder().encode(goal.targetByPhase)
        self.init(
            id: goal.id,
            habitId: goal.habitId,
            targetCountPerDay: goal.targetCountPerDay,
            targetByPhaseData: targetData,
            measurementRawValue: goal.measurement.rawValue
        )
    }

    func toDomain() -> Goal {
        let targetByPhase = targetByPhaseData.flatMap {
            try? JSONDecoder().decode([PhaseName: Int].self, from: $0)
        }

        return Goal(
            id: id,
            habitId: habitId,
            targetCountPerDay: targetCountPerDay,
            targetByPhase: targetByPhase,
            measurement: GoalMeasurement(rawValue: measurementRawValue) ?? .count
        )
    }
}

@Model
final class RoutineModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var habitIdsData: Data
    var ruleIdsData: Data
    var isActive: Bool
    var createdAt: Date

    init(
        id: UUID,
        name: String,
        habitIdsData: Data,
        ruleIdsData: Data,
        isActive: Bool = true,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.habitIdsData = habitIdsData
        self.ruleIdsData = ruleIdsData
        self.isActive = isActive
        self.createdAt = createdAt
    }

    convenience init(from routine: Routine) {
        let habitData = (try? JSONEncoder().encode(routine.habitIds)) ?? Data()
        let ruleData = (try? JSONEncoder().encode(routine.ruleIds)) ?? Data()
        self.init(
            id: routine.id,
            name: routine.name,
            habitIdsData: habitData,
            ruleIdsData: ruleData,
            isActive: routine.isActive,
            createdAt: routine.createdAt
        )
    }

    func toDomain() -> Routine {
        let habitIds = (try? JSONDecoder().decode([UUID].self, from: habitIdsData)) ?? []
        let ruleIds = (try? JSONDecoder().decode([UUID].self, from: ruleIdsData)) ?? []

        return Routine(
            id: id,
            name: name,
            habitIds: habitIds,
            ruleIds: ruleIds,
            isActive: isActive,
            createdAt: createdAt
        )
    }
}

@Model
final class RuleModel {
    @Attribute(.unique) var id: UUID
    var routineId: UUID
    var enabled: Bool
    var triggerData: Data
    var conditionsData: Data
    var actionsData: Data
    var createdAt: Date

    init(
        id: UUID,
        routineId: UUID,
        enabled: Bool = true,
        triggerData: Data,
        conditionsData: Data,
        actionsData: Data,
        createdAt: Date
    ) {
        self.id = id
        self.routineId = routineId
        self.enabled = enabled
        self.triggerData = triggerData
        self.conditionsData = conditionsData
        self.actionsData = actionsData
        self.createdAt = createdAt
    }

    convenience init(from rule: Rule) {
        let triggerData = (try? JSONEncoder().encode(rule.trigger)) ?? Data()
        let conditionsData = (try? JSONEncoder().encode(rule.conditions)) ?? Data()
        let actionsData = (try? JSONEncoder().encode(rule.actions)) ?? Data()

        self.init(
            id: rule.id,
            routineId: rule.routineId,
            enabled: rule.enabled,
            triggerData: triggerData,
            conditionsData: conditionsData,
            actionsData: actionsData,
            createdAt: rule.createdAt
        )
    }

    func toDomain() -> Rule? {
        guard
            let trigger = try? JSONDecoder().decode(RuleTrigger.self, from: triggerData),
            let conditions = try? JSONDecoder().decode([RuleCondition].self, from: conditionsData),
            let actions = try? JSONDecoder().decode([RuleAction].self, from: actionsData)
        else {
            return nil
        }

        return Rule(
            id: id,
            routineId: routineId,
            enabled: enabled,
            trigger: trigger,
            conditions: conditions,
            actions: actions,
            createdAt: createdAt
        )
    }
}

@Model
final class DailyLogModel {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var dateKey: String
    var createdAt: Date
    var returnHooksData: Data
    var summaryData: Data?

    init(
        id: UUID,
        dateKey: String,
        createdAt: Date,
        returnHooksData: Data,
        summaryData: Data? = nil
    ) {
        self.id = id
        self.dateKey = dateKey
        self.createdAt = createdAt
        self.returnHooksData = returnHooksData
        self.summaryData = summaryData
    }

    convenience init(from log: DailyLog) {
        let hooksData = (try? JSONEncoder().encode(log.returnHooks)) ?? Data()
        let summaryData = try? JSONEncoder().encode(log.summary)

        self.init(
            id: log.id,
            dateKey: log.dateKey,
            createdAt: log.createdAt,
            returnHooksData: hooksData,
            summaryData: summaryData
        )
    }

    func toDomain() -> DailyLog {
        let hooks = (try? JSONDecoder().decode([ReturnHook].self, from: returnHooksData)) ?? []
        let summary = summaryData.flatMap { try? JSONDecoder().decode(DailySummary.self, from: $0) }

        return DailyLog(
            id: id,
            dateKey: dateKey,
            createdAt: createdAt,
            returnHooks: hooks,
            summary: summary
        )
    }
}

@Model
final class CompletionEventModel {
    @Attribute(.unique) var id: UUID
    var habitId: UUID
    var timestamp: Date
    var dateKey: String
    var metadataData: Data
    var isLateCorrection: Bool

    init(
        id: UUID,
        habitId: UUID,
        timestamp: Date,
        dateKey: String,
        metadataData: Data,
        isLateCorrection: Bool = false
    ) {
        self.id = id
        self.habitId = habitId
        self.timestamp = timestamp
        self.dateKey = dateKey
        self.metadataData = metadataData
        self.isLateCorrection = isLateCorrection
    }

    convenience init(from event: CompletionEvent) {
        let metadataData = (try? JSONEncoder().encode(event.metadata)) ?? Data()
        self.init(
            id: event.id,
            habitId: event.habitId,
            timestamp: event.timestamp,
            dateKey: event.dateKey,
            metadataData: metadataData,
            isLateCorrection: event.isLateCorrection
        )
    }

    func toDomain() -> CompletionEvent {
        let metadata = (try? JSONDecoder().decode(CompletionMetadata.self, from: metadataData)) ?? CompletionMetadata()

        return CompletionEvent(
            id: id,
            habitId: habitId,
            timestamp: timestamp,
            dateKey: dateKey,
            metadata: metadata,
            isLateCorrection: isLateCorrection
        )
    }
}

@Model
final class ReminderModel {
    @Attribute(.unique) var id: UUID
    var habitId: UUID?
    var ruleId: UUID?
    var dateKey: String
    var fireDate: Date
    var expirationDate: Date
    var notificationId: String
    var stateRawValue: String
    var priority: Int
    var templateId: String

    init(
        id: UUID,
        habitId: UUID? = nil,
        ruleId: UUID? = nil,
        dateKey: String,
        fireDate: Date,
        expirationDate: Date,
        notificationId: String,
        stateRawValue: String,
        priority: Int,
        templateId: String
    ) {
        self.id = id
        self.habitId = habitId
        self.ruleId = ruleId
        self.dateKey = dateKey
        self.fireDate = fireDate
        self.expirationDate = expirationDate
        self.notificationId = notificationId
        self.stateRawValue = stateRawValue
        self.priority = priority
        self.templateId = templateId
    }

    convenience init(from reminder: Reminder) {
        self.init(
            id: reminder.id,
            habitId: reminder.habitId,
            ruleId: reminder.ruleId,
            dateKey: reminder.dateKey,
            fireDate: reminder.fireDate,
            expirationDate: reminder.expirationDate,
            notificationId: reminder.notificationId,
            stateRawValue: reminder.state.rawValue,
            priority: reminder.priority,
            templateId: reminder.templateId
        )
    }

    func toDomain() -> Reminder {
        Reminder(
            id: id,
            habitId: habitId,
            ruleId: ruleId,
            dateKey: dateKey,
            fireDate: fireDate,
            expirationDate: expirationDate,
            notificationId: notificationId,
            state: ReminderState(rawValue: stateRawValue) ?? .scheduled,
            priority: priority,
            templateId: templateId
        )
    }
}

@Model
final class SalvagePlanModel {
    @Attribute(.unique) var id: UUID
    var dateKey: String
    var createdAt: Date
    var title: String
    var message: String
    var rebalancedItemsData: Data
    var isAccepted: Bool
    var acceptedAt: Date?

    init(
        id: UUID,
        dateKey: String,
        createdAt: Date,
        title: String,
        message: String,
        rebalancedItemsData: Data,
        isAccepted: Bool = false,
        acceptedAt: Date? = nil
    ) {
        self.id = id
        self.dateKey = dateKey
        self.createdAt = createdAt
        self.title = title
        self.message = message
        self.rebalancedItemsData = rebalancedItemsData
        self.isAccepted = isAccepted
        self.acceptedAt = acceptedAt
    }

    convenience init(from plan: SalvagePlan) {
        let itemsData = (try? JSONEncoder().encode(plan.rebalancedItems)) ?? Data()
        self.init(
            id: plan.id,
            dateKey: plan.dateKey,
            createdAt: plan.createdAt,
            title: plan.title,
            message: plan.message,
            rebalancedItemsData: itemsData,
            isAccepted: plan.isAccepted,
            acceptedAt: plan.acceptedAt
        )
    }

    func toDomain() -> SalvagePlan {
        let items = (try? JSONDecoder().decode([RebalancedItem].self, from: rebalancedItemsData)) ?? []

        return SalvagePlan(
            id: id,
            dateKey: dateKey,
            createdAt: createdAt,
            title: title,
            message: message,
            rebalancedItems: items,
            isAccepted: isAccepted,
            acceptedAt: acceptedAt
        )
    }
}
