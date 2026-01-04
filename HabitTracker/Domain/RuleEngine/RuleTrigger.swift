import Foundation

// MARK: - Rule Trigger

/// Defines when a rule should be evaluated
public enum RuleTrigger: Codable, Equatable, Sendable {
    /// Trigger at the start of a phase
    case phaseStart(PhaseName)

    /// Trigger at a specific time within a phase
    case timeInPhase(PhaseName, minutesFromPhaseStart: Int)

    /// Trigger at an absolute local time (HH:mm format)
    case absoluteTime(hour: Int, minute: Int)

    /// Trigger when a specific habit is completed
    case onCompletion(habitId: UUID)

    /// Trigger X minutes after a habit completion
    case timeAfterCompletion(habitId: UUID, offsetMinutes: Int, mustBeSameDay: Bool)

    /// Trigger at a specific time only if within a phase
    case absoluteTimeInPhase(PhaseName, hour: Int, minute: Int)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case phase
        case minutesFromPhaseStart
        case hour
        case minute
        case habitId
        case offsetMinutes
        case mustBeSameDay
    }

    private enum TriggerType: String, Codable {
        case phaseStart
        case timeInPhase
        case absoluteTime
        case onCompletion
        case timeAfterCompletion
        case absoluteTimeInPhase
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(TriggerType.self, forKey: .type)

        switch type {
        case .phaseStart:
            let phase = try container.decode(PhaseName.self, forKey: .phase)
            self = .phaseStart(phase)

        case .timeInPhase:
            let phase = try container.decode(PhaseName.self, forKey: .phase)
            let minutes = try container.decode(Int.self, forKey: .minutesFromPhaseStart)
            self = .timeInPhase(phase, minutesFromPhaseStart: minutes)

        case .absoluteTime:
            let hour = try container.decode(Int.self, forKey: .hour)
            let minute = try container.decode(Int.self, forKey: .minute)
            self = .absoluteTime(hour: hour, minute: minute)

        case .onCompletion:
            let habitId = try container.decode(UUID.self, forKey: .habitId)
            self = .onCompletion(habitId: habitId)

        case .timeAfterCompletion:
            let habitId = try container.decode(UUID.self, forKey: .habitId)
            let offset = try container.decode(Int.self, forKey: .offsetMinutes)
            let sameDay = try container.decode(Bool.self, forKey: .mustBeSameDay)
            self = .timeAfterCompletion(habitId: habitId, offsetMinutes: offset, mustBeSameDay: sameDay)

        case .absoluteTimeInPhase:
            let phase = try container.decode(PhaseName.self, forKey: .phase)
            let hour = try container.decode(Int.self, forKey: .hour)
            let minute = try container.decode(Int.self, forKey: .minute)
            self = .absoluteTimeInPhase(phase, hour: hour, minute: minute)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .phaseStart(let phase):
            try container.encode(TriggerType.phaseStart, forKey: .type)
            try container.encode(phase, forKey: .phase)

        case .timeInPhase(let phase, let minutes):
            try container.encode(TriggerType.timeInPhase, forKey: .type)
            try container.encode(phase, forKey: .phase)
            try container.encode(minutes, forKey: .minutesFromPhaseStart)

        case .absoluteTime(let hour, let minute):
            try container.encode(TriggerType.absoluteTime, forKey: .type)
            try container.encode(hour, forKey: .hour)
            try container.encode(minute, forKey: .minute)

        case .onCompletion(let habitId):
            try container.encode(TriggerType.onCompletion, forKey: .type)
            try container.encode(habitId, forKey: .habitId)

        case .timeAfterCompletion(let habitId, let offset, let sameDay):
            try container.encode(TriggerType.timeAfterCompletion, forKey: .type)
            try container.encode(habitId, forKey: .habitId)
            try container.encode(offset, forKey: .offsetMinutes)
            try container.encode(sameDay, forKey: .mustBeSameDay)

        case .absoluteTimeInPhase(let phase, let hour, let minute):
            try container.encode(TriggerType.absoluteTimeInPhase, forKey: .type)
            try container.encode(phase, forKey: .phase)
            try container.encode(hour, forKey: .hour)
            try container.encode(minute, forKey: .minute)
        }
    }
}

extension RuleTrigger {
    public var description: String {
        switch self {
        case .phaseStart(let phase):
            return "At start of \(phase.displayName)"
        case .timeInPhase(let phase, let minutes):
            return "\(minutes) min into \(phase.displayName)"
        case .absoluteTime(let hour, let minute):
            return String(format: "At %02d:%02d", hour, minute)
        case .onCompletion:
            return "When completed"
        case .timeAfterCompletion(_, let offset, let sameDay):
            return "\(offset) min after completion\(sameDay ? " (same day)" : "")"
        case .absoluteTimeInPhase(let phase, let hour, let minute):
            return String(format: "At %02d:%02d in %@", hour, minute, phase.displayName)
        }
    }
}
