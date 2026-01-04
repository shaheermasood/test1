import Foundation

// MARK: - Scheduling Decision

/// Output of rule engine evaluation - what to do
public enum SchedulingDecision: Equatable, Sendable {
    case scheduleReminder(
        id: UUID,
        habitId: UUID?,
        ruleId: UUID?,
        fireDate: Date,
        expirationDate: Date,
        templateId: String,
        priority: Int
    )
    case cancelReminder(reminderId: UUID)
    case createReturnHook(prompt: String)
    case createSalvagePlan(plan: SalvagePlan)
}

// MARK: - Salvage Plan

public struct SalvagePlan: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let dateKey: String
    public let createdAt: Date
    public var title: String
    public var message: String
    public var rebalancedItems: [RebalancedItem]
    public var isAccepted: Bool
    public var acceptedAt: Date?

    public init(
        id: UUID,
        dateKey: String,
        createdAt: Date,
        title: String,
        message: String,
        rebalancedItems: [RebalancedItem],
        isAccepted: Bool = false,
        acceptedAt: Date? = nil
    ) {
        self.id = id
        self.dateKey = dateKey
        self.createdAt = createdAt
        self.title = title
        self.message = message
        self.rebalancedItems = rebalancedItems
        self.isAccepted = isAccepted
        self.acceptedAt = acceptedAt
    }
}

// MARK: - Rebalanced Item

public struct RebalancedItem: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let habitId: UUID
    public var suggestedPhase: PhaseName
    public var suggestedTime: Date?
    public var reason: String

    public init(
        id: UUID,
        habitId: UUID,
        suggestedPhase: PhaseName,
        suggestedTime: Date? = nil,
        reason: String
    ) {
        self.id = id
        self.habitId = habitId
        self.suggestedPhase = suggestedPhase
        self.suggestedTime = suggestedTime
        self.reason = reason
    }
}

// MARK: - Notification Template

public struct NotificationTemplate: Equatable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let categoryId: String

    public init(id: String, title: String, body: String, categoryId: String = "HABIT_REMINDER") {
        self.id = id
        self.title = title
        self.body = body
        self.categoryId = categoryId
    }

    // MARK: - Standard Templates

    public static let genericReminder = NotificationTemplate(
        id: "generic_reminder",
        title: "Gentle reminder",
        body: "Time to check in with your routine"
    )

    public static let phaseStart = NotificationTemplate(
        id: "phase_start",
        title: "New phase beginning",
        body: "Your %@ is starting"
    )

    public static let cascadeReminder = NotificationTemplate(
        id: "cascade_reminder",
        title: "Dependency reminder",
        body: "%@ so %@ can happen"
    )

    public static let returnHook = NotificationTemplate(
        id: "return_hook",
        title: "Welcome back",
        body: "How did %@ go?"
    )

    public static let salvagePlan = NotificationTemplate(
        id: "salvage_plan",
        title: "Let's rebalance",
        body: "Your routine needs a gentle adjustment"
    )
}
