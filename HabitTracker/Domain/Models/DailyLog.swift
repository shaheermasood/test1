import Foundation

// MARK: - Return Hook

public struct ReturnHook: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var prompt: String
    public var userResponse: String?
    public let createdAt: Date
    public var respondedAt: Date?

    public init(
        id: UUID,
        prompt: String,
        userResponse: String? = nil,
        createdAt: Date,
        respondedAt: Date? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.userResponse = userResponse
        self.createdAt = createdAt
        self.respondedAt = respondedAt
    }

    public var isResponded: Bool {
        return userResponse != nil
    }
}

// MARK: - Daily Summary

public struct DailySummary: Codable, Equatable, Sendable {
    public var totalCompletions: Int
    public var completionsByPhase: [PhaseName: Int]
    public var completionsByHabit: [UUID: Int]
    public var streaks: [UUID: Int]

    public init(
        totalCompletions: Int = 0,
        completionsByPhase: [PhaseName: Int] = [:],
        completionsByHabit: [UUID: Int] = [:],
        streaks: [UUID: Int] = [:]
    ) {
        self.totalCompletions = totalCompletions
        self.completionsByPhase = completionsByPhase
        self.completionsByHabit = completionsByHabit
        self.streaks = streaks
    }
}

// MARK: - Daily Log (Domain)

public struct DailyLog: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let dateKey: String
    public let createdAt: Date
    public var returnHooks: [ReturnHook]
    public var summary: DailySummary?

    public init(
        id: UUID,
        dateKey: String,
        createdAt: Date,
        returnHooks: [ReturnHook] = [],
        summary: DailySummary? = nil
    ) {
        self.id = id
        self.dateKey = dateKey
        self.createdAt = createdAt
        self.returnHooks = returnHooks
        self.summary = summary
    }
}
