import Foundation
import Dependencies

// MARK: - Day Service Client

/// Manages day boundaries and date key computation
public struct DayServiceClient: Sendable {
    public var dateKey: @Sendable (Date, UserSettings) -> String
    public var isNewDay: @Sendable (String, Date, UserSettings) -> Bool
    public var resetBoundary: @Sendable (Date, UserSettings) -> Date

    public init(
        dateKey: @escaping @Sendable (Date, UserSettings) -> String,
        isNewDay: @escaping @Sendable (String, Date, UserSettings) -> Bool,
        resetBoundary: @escaping @Sendable (Date, UserSettings) -> Date
    ) {
        self.dateKey = dateKey
        self.isNewDay = isNewDay
        self.resetBoundary = resetBoundary
    }
}

// MARK: - Dependency

extension DayServiceClient: DependencyKey {
    public static let liveValue = DayServiceClient(
        dateKey: { date, settings in
            computeDateKey(for: date, settings: settings)
        },
        isNewDay: { lastDateKey, currentDate, settings in
            let currentDateKey = computeDateKey(for: currentDate, settings: settings)
            return currentDateKey != lastDateKey
        },
        resetBoundary: { date, settings in
            computeResetBoundary(for: date, settings: settings)
        }
    )

    public static let testValue = DayServiceClient(
        dateKey: { date, _ in
            // For tests, use simple date formatting
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        },
        isNewDay: { lastDateKey, currentDate, settings in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: currentDate) != lastDateKey
        },
        resetBoundary: { date, settings in
            computeResetBoundary(for: date, settings: settings)
        }
    )
}

extension DependencyValues {
    public var dayService: DayServiceClient {
        get { self[DayServiceClient.self] }
        set { self[DayServiceClient.self] = newValue }
    }
}

// MARK: - Implementation

private func computeDateKey(for date: Date, settings: UserSettings) -> String {
    let calendar = Calendar.current
    var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)

    let resetHour = settings.resetHourMinute.hour
    let resetMinute = settings.resetHourMinute.minute

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

private func computeResetBoundary(for date: Date, settings: UserSettings) -> Date {
    let calendar = Calendar.current
    let resetHour = settings.resetHourMinute.hour
    let resetMinute = settings.resetHourMinute.minute

    var components = calendar.dateComponents([.year, .month, .day], from: date)
    components.hour = resetHour
    components.minute = resetMinute
    components.second = 0

    guard let boundaryDate = calendar.date(from: components) else {
        return date
    }

    // If current time is before reset, return today's boundary
    // If current time is after reset, return tomorrow's boundary
    if date >= boundaryDate {
        // Return tomorrow's boundary
        return calendar.date(byAdding: .day, value: 1, to: boundaryDate) ?? boundaryDate
    } else {
        // Return today's boundary
        return boundaryDate
    }
}
