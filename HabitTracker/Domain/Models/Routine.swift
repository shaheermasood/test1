import Foundation

// MARK: - Routine (Domain)

public struct Routine: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var habitIds: [UUID]
    public var ruleIds: [UUID]
    public var isActive: Bool
    public let createdAt: Date

    public init(
        id: UUID,
        name: String,
        habitIds: [UUID],
        ruleIds: [UUID],
        isActive: Bool = true,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.habitIds = habitIds
        self.ruleIds = ruleIds
        self.isActive = isActive
        self.createdAt = createdAt
    }
}
