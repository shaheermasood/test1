import Foundation

// MARK: - Day Context

/// Encapsulates all state needed for rule evaluation
public struct DayContext: Equatable, Sendable {
    public let dateKey: String
    public let currentDate: Date
    public let phases: DayPhases
    public let completionEvents: [CompletionEvent]
    public let existingReminders: [Reminder]
    public let returnHooks: [ReturnHook]
    public let settings: UserSettings
    public let dayService: DayService

    public init(
        dateKey: String,
        currentDate: Date,
        phases: DayPhases,
        completionEvents: [CompletionEvent],
        existingReminders: [Reminder],
        returnHooks: [ReturnHook],
        settings: UserSettings,
        dayService: DayService
    ) {
        self.dateKey = dateKey
        self.currentDate = currentDate
        self.phases = phases
        self.completionEvents = completionEvents
        self.existingReminders = existingReminders
        self.returnHooks = returnHooks
        self.settings = settings
        self.dayService = dayService
    }

    // MARK: - Query Helpers

    /// Get all completion events for a specific habit today
    public func completions(for habitId: UUID) -> [CompletionEvent] {
        return completionEvents.filter { $0.habitId == habitId }
    }

    /// Check if habit was completed today
    public func isCompleted(_ habitId: UUID) -> Bool {
        return completions(for: habitId).isEmpty == false
    }

    /// Get completion count for habit today
    public func completionCount(for habitId: UUID) -> Int {
        return completions(for: habitId).count
    }

    /// Get most recent completion for a habit
    public func mostRecentCompletion(for habitId: UUID) -> CompletionEvent? {
        return completions(for: habitId).max(by: { $0.timestamp < $1.timestamp })
    }

    /// Check if habit was completed within last N minutes
    public func isCompletedWithinLast(habitId: UUID, minutes: Int) -> Bool {
        guard let mostRecent = mostRecentCompletion(for: habitId) else {
            return false
        }
        let threshold = currentDate.addingTimeInterval(-TimeInterval(minutes * 60))
        return mostRecent.timestamp >= threshold
    }

    /// Check if habit was completed in a specific phase
    public func isCompletedInPhase(habitId: UUID, phase: PhaseName) -> Bool {
        guard let interval = phases.interval(for: phase) else {
            return false
        }
        return completions(for: habitId).contains { event in
            interval.contains(event.timestamp)
        }
    }

    /// Get current phase
    public func currentPhase() -> PhaseName? {
        return phases.currentPhase(at: currentDate)
    }

    /// Count scheduled reminders for today
    public func scheduledReminderCount() -> Int {
        return existingReminders.filter { $0.state == .scheduled }.count
    }

    /// Get pending return hooks
    public func pendingReturnHooks() -> [ReturnHook] {
        return returnHooks.filter { !$0.isResponded }
    }
}

// MARK: - User Settings

public struct UserSettings: Codable, Equatable, Sendable {
    public var resetHourMinute: (hour: Int, minute: Int)
    public var notificationCapPerDay: Int
    public var notificationCooldownMinutes: Int
    public var phaseMode: PhaseMode
    public var manualPhaseOverrides: [PhaseName: PhaseOverride]
    public var tone: NotificationTone
    public var locationEnabled: Bool

    public init(
        resetHourMinute: (hour: Int, minute: Int) = (2, 0),
        notificationCapPerDay: Int = 8,
        notificationCooldownMinutes: Int = 45,
        phaseMode: PhaseMode = .autoSolar,
        manualPhaseOverrides: [PhaseName: PhaseOverride] = [:],
        tone: NotificationTone = .zenCoach,
        locationEnabled: Bool = false
    ) {
        self.resetHourMinute = resetHourMinute
        self.notificationCapPerDay = notificationCapPerDay
        self.notificationCooldownMinutes = notificationCooldownMinutes
        self.phaseMode = phaseMode
        self.manualPhaseOverrides = manualPhaseOverrides
        self.tone = tone
        self.locationEnabled = locationEnabled
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case resetHour
        case resetMinute
        case notificationCapPerDay
        case notificationCooldownMinutes
        case phaseMode
        case manualPhaseOverrides
        case tone
        case locationEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let hour = try container.decode(Int.self, forKey: .resetHour)
        let minute = try container.decode(Int.self, forKey: .resetMinute)
        self.resetHourMinute = (hour, minute)
        self.notificationCapPerDay = try container.decode(Int.self, forKey: .notificationCapPerDay)
        self.notificationCooldownMinutes = try container.decode(Int.self, forKey: .notificationCooldownMinutes)
        self.phaseMode = try container.decode(PhaseMode.self, forKey: .phaseMode)
        self.manualPhaseOverrides = try container.decode([PhaseName: PhaseOverride].self, forKey: .manualPhaseOverrides)
        self.tone = try container.decode(NotificationTone.self, forKey: .tone)
        self.locationEnabled = try container.decode(Bool.self, forKey: .locationEnabled)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(resetHourMinute.hour, forKey: .resetHour)
        try container.encode(resetHourMinute.minute, forKey: .resetMinute)
        try container.encode(notificationCapPerDay, forKey: .notificationCapPerDay)
        try container.encode(notificationCooldownMinutes, forKey: .notificationCooldownMinutes)
        try container.encode(phaseMode, forKey: .phaseMode)
        try container.encode(manualPhaseOverrides, forKey: .manualPhaseOverrides)
        try container.encode(tone, forKey: .tone)
        try container.encode(locationEnabled, forKey: .locationEnabled)
    }
}

// MARK: - Notification Tone

public enum NotificationTone: String, Codable, Equatable, Sendable {
    case zenCoach

    public var displayName: String {
        switch self {
        case .zenCoach: return "Zen Coach"
        }
    }
}

// MARK: - Day Service (value type for DayContext)

public struct DayService: Equatable, Sendable {
    public let resetHour: Int
    public let resetMinute: Int

    public init(resetHour: Int = 2, resetMinute: Int = 0) {
        self.resetHour = resetHour
        self.resetMinute = resetMinute
    }

    public func dateKey(for date: Date) -> String {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)

        // If before reset time, use previous day
        if let hour = components.hour, let minute = components.minute {
            let currentMinutes = hour * 60 + minute
            let resetMinutes = resetHour * 60 + resetMinute

            if currentMinutes < resetMinutes {
                // Subtract one day
                if let adjustedDate = calendar.date(byAdding: .day, value: -1, to: date) {
                    components = calendar.dateComponents([.year, .month, .day], from: adjustedDate)
                }
            }
        }

        let year = components.year ?? 2025
        let month = components.month ?? 1
        let day = components.day ?? 1

        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
