import Foundation

// MARK: - Goal Measurement

public enum GoalMeasurement: String, Codable, Equatable, Sendable {
    case count      // Track number of completions
    case boolean    // Just done/not done (single completion)

    public var displayName: String {
        switch self {
        case .count: return "Count"
        case .boolean: return "Yes/No"
        }
    }
}

// MARK: - Goal (Domain)

public struct Goal: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let habitId: UUID
    public var targetCountPerDay: Int
    public var targetByPhase: [PhaseName: Int]?  // Optional per-phase targets
    public var measurement: GoalMeasurement

    public init(
        id: UUID,
        habitId: UUID,
        targetCountPerDay: Int,
        targetByPhase: [PhaseName: Int]? = nil,
        measurement: GoalMeasurement = .count
    ) {
        self.id = id
        self.habitId = habitId
        self.targetCountPerDay = targetCountPerDay
        self.targetByPhase = targetByPhase
        self.measurement = measurement
    }

    // Helper: Get target for a specific phase
    public func target(for phase: PhaseName) -> Int? {
        return targetByPhase?[phase]
    }
}
