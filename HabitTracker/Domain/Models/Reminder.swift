import Foundation

// MARK: - Reminder State

public enum ReminderState: String, Codable, Equatable, Sendable {
    case scheduled  // Pending delivery
    case fired      // Notification delivered
    case canceled   // Canceled before delivery
    case expired    // Passed expiration without action
    case completed  // User marked done
    case skipped    // User skipped
    case snoozed    // User snoozed (will create new reminder)
}

// MARK: - Reminder (Domain)

public struct Reminder: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let habitId: UUID?      // Nil for return hooks
    public let ruleId: UUID?
    public let dateKey: String
    public let fireDate: Date
    public let expirationDate: Date
    public let notificationId: String
    public var state: ReminderState
    public var priority: Int
    public var templateId: String

    public init(
        id: UUID,
        habitId: UUID?,
        ruleId: UUID?,
        dateKey: String,
        fireDate: Date,
        expirationDate: Date,
        notificationId: String,
        state: ReminderState = .scheduled,
        priority: Int = 0,
        templateId: String
    ) {
        self.id = id
        self.habitId = habitId
        self.ruleId = ruleId
        self.dateKey = dateKey
        self.fireDate = fireDate
        self.expirationDate = expirationDate
        self.notificationId = notificationId
        self.state = state
        self.priority = priority
        self.templateId = templateId
    }

    public var isExpired: Bool {
        return Date() > expirationDate && state == .scheduled
    }

    public var canSnooze: Bool {
        return state == .fired && !isExpired
    }
}
