import Foundation

// MARK: - Rule Condition

/// Conditions that must be met for a rule to fire
public enum RuleCondition: Codable, Equatable, Sendable {
    /// Habit was completed within the last N minutes
    case completedWithinLast(habitId: UUID, minutes: Int)

    /// Habit was completed at least once today
    case completedToday(habitId: UUID)

    /// Habit was NOT completed today
    case notCompletedToday(habitId: UUID)

    /// Habit was completed within its phase window
    case completedInPhaseWindow(habitId: UUID, phase: PhaseName)

    /// Habit completed count today meets threshold
    case countCompletedToday(habitId: UUID, atLeast: Int)

    /// Sleep/wake time is known
    case sleepWakeKnown(kind: SleepWakeKind)

    /// A return hook exists for today
    case returnHookExists

    /// Current time is within a phase
    case withinPhase(PhaseName)

    /// Logical combinators
    case all([RuleCondition])
    case any([RuleCondition])
    case not(RuleCondition)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case habitId
        case minutes
        case phase
        case atLeast
        case kind
        case conditions
        case condition
    }

    private enum ConditionType: String, Codable {
        case completedWithinLast
        case completedToday
        case notCompletedToday
        case completedInPhaseWindow
        case countCompletedToday
        case sleepWakeKnown
        case returnHookExists
        case withinPhase
        case all
        case any
        case not
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ConditionType.self, forKey: .type)

        switch type {
        case .completedWithinLast:
            let habitId = try container.decode(UUID.self, forKey: .habitId)
            let minutes = try container.decode(Int.self, forKey: .minutes)
            self = .completedWithinLast(habitId: habitId, minutes: minutes)

        case .completedToday:
            let habitId = try container.decode(UUID.self, forKey: .habitId)
            self = .completedToday(habitId: habitId)

        case .notCompletedToday:
            let habitId = try container.decode(UUID.self, forKey: .habitId)
            self = .notCompletedToday(habitId: habitId)

        case .completedInPhaseWindow:
            let habitId = try container.decode(UUID.self, forKey: .habitId)
            let phase = try container.decode(PhaseName.self, forKey: .phase)
            self = .completedInPhaseWindow(habitId: habitId, phase: phase)

        case .countCompletedToday:
            let habitId = try container.decode(UUID.self, forKey: .habitId)
            let atLeast = try container.decode(Int.self, forKey: .atLeast)
            self = .countCompletedToday(habitId: habitId, atLeast: atLeast)

        case .sleepWakeKnown:
            let kind = try container.decode(SleepWakeKind.self, forKey: .kind)
            self = .sleepWakeKnown(kind: kind)

        case .returnHookExists:
            self = .returnHookExists

        case .withinPhase:
            let phase = try container.decode(PhaseName.self, forKey: .phase)
            self = .withinPhase(phase)

        case .all:
            let conditions = try container.decode([RuleCondition].self, forKey: .conditions)
            self = .all(conditions)

        case .any:
            let conditions = try container.decode([RuleCondition].self, forKey: .conditions)
            self = .any(conditions)

        case .not:
            let condition = try container.decode(RuleCondition.self, forKey: .condition)
            self = .not(condition)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .completedWithinLast(let habitId, let minutes):
            try container.encode(ConditionType.completedWithinLast, forKey: .type)
            try container.encode(habitId, forKey: .habitId)
            try container.encode(minutes, forKey: .minutes)

        case .completedToday(let habitId):
            try container.encode(ConditionType.completedToday, forKey: .type)
            try container.encode(habitId, forKey: .habitId)

        case .notCompletedToday(let habitId):
            try container.encode(ConditionType.notCompletedToday, forKey: .type)
            try container.encode(habitId, forKey: .habitId)

        case .completedInPhaseWindow(let habitId, let phase):
            try container.encode(ConditionType.completedInPhaseWindow, forKey: .type)
            try container.encode(habitId, forKey: .habitId)
            try container.encode(phase, forKey: .phase)

        case .countCompletedToday(let habitId, let atLeast):
            try container.encode(ConditionType.countCompletedToday, forKey: .type)
            try container.encode(habitId, forKey: .habitId)
            try container.encode(atLeast, forKey: .atLeast)

        case .sleepWakeKnown(let kind):
            try container.encode(ConditionType.sleepWakeKnown, forKey: .type)
            try container.encode(kind, forKey: .kind)

        case .returnHookExists:
            try container.encode(ConditionType.returnHookExists, forKey: .type)

        case .withinPhase(let phase):
            try container.encode(ConditionType.withinPhase, forKey: .type)
            try container.encode(phase, forKey: .phase)

        case .all(let conditions):
            try container.encode(ConditionType.all, forKey: .type)
            try container.encode(conditions, forKey: .conditions)

        case .any(let conditions):
            try container.encode(ConditionType.any, forKey: .type)
            try container.encode(conditions, forKey: .conditions)

        case .not(let condition):
            try container.encode(ConditionType.not, forKey: .type)
            try container.encode(condition, forKey: .condition)
        }
    }
}

// MARK: - Sleep/Wake Kind

public enum SleepWakeKind: String, Codable, Equatable, Sendable {
    case sleep
    case wake
}

extension RuleCondition {
    public var description: String {
        switch self {
        case .completedWithinLast(_, let minutes):
            return "Completed within \(minutes) min"
        case .completedToday:
            return "Completed today"
        case .notCompletedToday:
            return "NOT completed today"
        case .completedInPhaseWindow(_, let phase):
            return "Completed in \(phase.displayName)"
        case .countCompletedToday(_, let atLeast):
            return "Completed ≥ \(atLeast) times"
        case .sleepWakeKnown(let kind):
            return "\(kind.rawValue.capitalized) time known"
        case .returnHookExists:
            return "Return hook exists"
        case .withinPhase(let phase):
            return "Within \(phase.displayName)"
        case .all:
            return "ALL conditions"
        case .any:
            return "ANY condition"
        case .not:
            return "NOT"
        }
    }
}
