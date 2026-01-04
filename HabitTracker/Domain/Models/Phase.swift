import Foundation

// MARK: - Phase Name

public enum PhaseName: String, Codable, Equatable, Sendable, CaseIterable {
    case morning
    case afternoon
    case evening
    case night

    public var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }

    public var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }
}

// MARK: - Phase Interval

public struct PhaseInterval: Codable, Equatable, Sendable {
    public let phase: PhaseName
    public let startDate: Date
    public let endDate: Date

    public init(phase: PhaseName, startDate: Date, endDate: Date) {
        self.phase = phase
        self.startDate = startDate
        self.endDate = endDate
    }

    public func contains(_ date: Date) -> Bool {
        return date >= startDate && date < endDate
    }

    public var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
}

// MARK: - Phase Mode

public enum PhaseMode: String, Codable, Equatable, Sendable {
    case autoSolar  // Use sunrise/sunset from location
    case manual     // Use fixed times or manual overrides
}

// MARK: - Phase Override

public struct PhaseOverride: Codable, Equatable, Sendable {
    public let phase: PhaseName
    public let startHour: Int
    public let startMinute: Int
    public let endHour: Int
    public let endMinute: Int

    public init(
        phase: PhaseName,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int
    ) {
        self.phase = phase
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }

    // Default times for each phase
    public static let defaults: [PhaseName: PhaseOverride] = [
        .morning: PhaseOverride(phase: .morning, startHour: 6, startMinute: 0, endHour: 12, endMinute: 0),
        .afternoon: PhaseOverride(phase: .afternoon, startHour: 12, startMinute: 0, endHour: 18, endMinute: 0),
        .evening: PhaseOverride(phase: .evening, startHour: 18, startMinute: 0, endHour: 22, endMinute: 0),
        .night: PhaseOverride(phase: .night, startHour: 22, startMinute: 0, endHour: 6, endMinute: 0)
    ]
}

// MARK: - Day Phases

public struct DayPhases: Codable, Equatable, Sendable {
    public let dateKey: String
    public let intervals: [PhaseInterval]
    public let computedAt: Date

    public init(dateKey: String, intervals: [PhaseInterval], computedAt: Date) {
        self.dateKey = dateKey
        self.intervals = intervals
        self.computedAt = computedAt
    }

    public func currentPhase(at date: Date) -> PhaseName? {
        return intervals.first(where: { $0.contains(date) })?.phase
    }

    public func interval(for phase: PhaseName) -> PhaseInterval? {
        return intervals.first(where: { $0.phase == phase })
    }
}
