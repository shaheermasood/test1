import Foundation

// MARK: - Rule (Domain)

public struct Rule: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let routineId: UUID
    public var enabled: Bool
    public var trigger: RuleTrigger
    public var conditions: [RuleCondition]
    public var actions: [RuleAction]
    public let createdAt: Date

    public init(
        id: UUID,
        routineId: UUID,
        enabled: Bool = true,
        trigger: RuleTrigger,
        conditions: [RuleCondition],
        actions: [RuleAction],
        createdAt: Date
    ) {
        self.id = id
        self.routineId = routineId
        self.enabled = enabled
        self.trigger = trigger
        self.conditions = conditions
        self.actions = actions
        self.createdAt = createdAt
    }

    // Helper: Check if rule should be evaluated based on trigger
    public func shouldEvaluate(
        at date: Date,
        context: DayContext,
        event: TriggerEvent?
    ) -> Bool {
        guard enabled else { return false }

        switch trigger {
        case .phaseStart(let phase):
            if let phaseStart = context.phases.interval(for: phase)?.startDate {
                // Check if we're within a small window of phase start
                return abs(date.timeIntervalSince(phaseStart)) < 60 // Within 1 minute
            }
            return false

        case .timeInPhase(let phase, let minutes):
            if let interval = context.phases.interval(for: phase) {
                let targetTime = interval.startDate.addingTimeInterval(TimeInterval(minutes * 60))
                return abs(date.timeIntervalSince(targetTime)) < 60
            }
            return false

        case .absoluteTime(let hour, let minute):
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: date)
            return components.hour == hour && components.minute == minute

        case .onCompletion(let habitId):
            if case .completion(let eventHabitId, _) = event {
                return eventHabitId == habitId
            }
            return false

        case .timeAfterCompletion(let habitId, let offset, let mustBeSameDay):
            // This should be evaluated when scheduling follow-up
            if case .completion(let eventHabitId, let completionDate) = event {
                if eventHabitId == habitId {
                    let targetTime = completionDate.addingTimeInterval(TimeInterval(offset * 60))
                    if mustBeSameDay {
                        return context.dayService.dateKey(for: completionDate) == context.dayService.dateKey(for: targetTime)
                    }
                    return true
                }
            }
            return false

        case .absoluteTimeInPhase(let phase, let hour, let minute):
            // Check time matches AND we're within the phase
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: date)
            let timeMatches = components.hour == hour && components.minute == minute
            let inPhase = context.phases.interval(for: phase)?.contains(date) ?? false
            return timeMatches && inPhase
        }
    }
}

// MARK: - Trigger Event

/// Events that can trigger rule evaluation
public enum TriggerEvent: Equatable, Sendable {
    case completion(habitId: UUID, date: Date)
    case phaseChange(from: PhaseName?, to: PhaseName)
    case timeCheck(date: Date)
}
