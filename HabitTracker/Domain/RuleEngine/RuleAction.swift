import Foundation

// MARK: - Rule Action

/// Actions to take when a rule fires
public enum RuleAction: Codable, Equatable, Sendable {
    /// Send a notification immediately
    case notify(templateId: String, habitId: UUID?, priority: Int)

    /// Schedule a notification for a specific time with expiration
    case scheduleNotifyAt(
        date: Date,
        expiration: Date,
        templateId: String,
        habitId: UUID?,
        priority: Int
    )

    /// Cancel notifications matching a tag
    case cancelNotifications(tag: CancelTag)

    /// Create a return hook for tomorrow
    case createReturnHook(prompt: String)

    /// Trigger salvage plan generation
    case triggerSalvage(planId: String)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case templateId
        case habitId
        case priority
        case date
        case expiration
        case tag
        case prompt
        case planId
    }

    private enum ActionType: String, Codable {
        case notify
        case scheduleNotifyAt
        case cancelNotifications
        case createReturnHook
        case triggerSalvage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ActionType.self, forKey: .type)

        switch type {
        case .notify:
            let templateId = try container.decode(String.self, forKey: .templateId)
            let habitId = try container.decodeIfPresent(UUID.self, forKey: .habitId)
            let priority = try container.decode(Int.self, forKey: .priority)
            self = .notify(templateId: templateId, habitId: habitId, priority: priority)

        case .scheduleNotifyAt:
            let date = try container.decode(Date.self, forKey: .date)
            let expiration = try container.decode(Date.self, forKey: .expiration)
            let templateId = try container.decode(String.self, forKey: .templateId)
            let habitId = try container.decodeIfPresent(UUID.self, forKey: .habitId)
            let priority = try container.decode(Int.self, forKey: .priority)
            self = .scheduleNotifyAt(
                date: date,
                expiration: expiration,
                templateId: templateId,
                habitId: habitId,
                priority: priority
            )

        case .cancelNotifications:
            let tag = try container.decode(CancelTag.self, forKey: .tag)
            self = .cancelNotifications(tag: tag)

        case .createReturnHook:
            let prompt = try container.decode(String.self, forKey: .prompt)
            self = .createReturnHook(prompt: prompt)

        case .triggerSalvage:
            let planId = try container.decode(String.self, forKey: .planId)
            self = .triggerSalvage(planId: planId)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .notify(let templateId, let habitId, let priority):
            try container.encode(ActionType.notify, forKey: .type)
            try container.encode(templateId, forKey: .templateId)
            try container.encodeIfPresent(habitId, forKey: .habitId)
            try container.encode(priority, forKey: .priority)

        case .scheduleNotifyAt(let date, let expiration, let templateId, let habitId, let priority):
            try container.encode(ActionType.scheduleNotifyAt, forKey: .type)
            try container.encode(date, forKey: .date)
            try container.encode(expiration, forKey: .expiration)
            try container.encode(templateId, forKey: .templateId)
            try container.encodeIfPresent(habitId, forKey: .habitId)
            try container.encode(priority, forKey: .priority)

        case .cancelNotifications(let tag):
            try container.encode(ActionType.cancelNotifications, forKey: .type)
            try container.encode(tag, forKey: .tag)

        case .createReturnHook(let prompt):
            try container.encode(ActionType.createReturnHook, forKey: .type)
            try container.encode(prompt, forKey: .prompt)

        case .triggerSalvage(let planId):
            try container.encode(ActionType.triggerSalvage, forKey: .type)
            try container.encode(planId, forKey: .planId)
        }
    }
}

// MARK: - Cancel Tag

public enum CancelTag: Codable, Equatable, Sendable {
    case byHabitId(UUID)
    case byRuleId(UUID)
    case byDateKey(String)
    case all

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case dateKey
    }

    private enum TagType: String, Codable {
        case byHabitId
        case byRuleId
        case byDateKey
        case all
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(TagType.self, forKey: .type)

        switch type {
        case .byHabitId:
            let id = try container.decode(UUID.self, forKey: .id)
            self = .byHabitId(id)
        case .byRuleId:
            let id = try container.decode(UUID.self, forKey: .id)
            self = .byRuleId(id)
        case .byDateKey:
            let dateKey = try container.decode(String.self, forKey: .dateKey)
            self = .byDateKey(dateKey)
        case .all:
            self = .all
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .byHabitId(let id):
            try container.encode(TagType.byHabitId, forKey: .type)
            try container.encode(id, forKey: .id)
        case .byRuleId(let id):
            try container.encode(TagType.byRuleId, forKey: .type)
            try container.encode(id, forKey: .id)
        case .byDateKey(let dateKey):
            try container.encode(TagType.byDateKey, forKey: .type)
            try container.encode(dateKey, forKey: .dateKey)
        case .all:
            try container.encode(TagType.all, forKey: .type)
        }
    }
}

extension RuleAction {
    public var description: String {
        switch self {
        case .notify(let templateId, _, let priority):
            return "Notify '\(templateId)' (priority: \(priority))"
        case .scheduleNotifyAt(let date, _, let templateId, _, _):
            return "Schedule '\(templateId)' at \(date)"
        case .cancelNotifications:
            return "Cancel notifications"
        case .createReturnHook(let prompt):
            return "Return hook: \(prompt)"
        case .triggerSalvage(let planId):
            return "Salvage plan: \(planId)"
        }
    }
}
