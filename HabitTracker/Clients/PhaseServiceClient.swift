import Foundation
import CoreLocation
import Dependencies

// MARK: - Phase Service Client

/// Computes phase intervals for a day
public struct PhaseServiceClient: Sendable {
    public var computePhases: @Sendable (Date, UserSettings, CLLocationCoordinate2D?) async -> DayPhases

    public init(
        computePhases: @escaping @Sendable (Date, UserSettings, CLLocationCoordinate2D?) async -> DayPhases
    ) {
        self.computePhases = computePhases
    }
}

// MARK: - Dependency

extension PhaseServiceClient: DependencyKey {
    public static let liveValue = PhaseServiceClient(
        computePhases: { date, settings, location in
            await computeDayPhases(for: date, settings: settings, location: location)
        }
    )

    public static let testValue = PhaseServiceClient(
        computePhases: { date, settings, _ in
            // For tests, use simple fixed times
            return createManualPhases(for: date, settings: settings)
        }
    )
}

extension DependencyValues {
    public var phaseService: PhaseServiceClient {
        get { self[PhaseServiceClient.self] }
        set { self[PhaseServiceClient.self] = newValue }
    }
}

// MARK: - Implementation

private func computeDayPhases(
    for date: Date,
    settings: UserSettings,
    location: CLLocationCoordinate2D?
) async -> DayPhases {
    let calendar = Calendar.current
    let dateKey = computeDateKeyForPhases(date: date, settings: settings)

    // Determine which mode to use
    switch settings.phaseMode {
    case .autoSolar:
        if let location = location {
            return createSolarPhases(for: date, location: location, dateKey: dateKey)
        } else {
            // Fall back to manual if location not available
            return createManualPhases(for: date, settings: settings, dateKey: dateKey)
        }

    case .manual:
        return createManualPhases(for: date, settings: settings, dateKey: dateKey)
    }
}

private func createSolarPhases(
    for date: Date,
    location: CLLocationCoordinate2D,
    dateKey: String
) -> DayPhases {
    let calendar = Calendar.current

    // Compute sunrise and sunset
    let (sunrise, sunset) = computeSunriseSunset(for: date, location: location)

    // Create phase intervals
    var intervals: [PhaseInterval] = []

    // Start of day (reset boundary - typically 2am)
    guard let startOfDay = calendar.date(bySettingHour: 2, minute: 0, second: 0, of: date) else {
        return createManualPhases(for: date, settings: UserSettings(), dateKey: dateKey)
    }

    // End of day (next reset boundary)
    guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
        return createManualPhases(for: date, settings: UserSettings(), dateKey: dateKey)
    }

    // Noon
    guard let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) else {
        return createManualPhases(for: date, settings: UserSettings(), dateKey: dateKey)
    }

    // Evening end (2 hours after sunset)
    let eveningEnd = sunset.addingTimeInterval(2 * 3600)

    // Phase 1: Morning (sunrise → noon)
    intervals.append(PhaseInterval(phase: .morning, startDate: sunrise, endDate: noon))

    // Phase 2: Afternoon (noon → sunset)
    intervals.append(PhaseInterval(phase: .afternoon, startDate: noon, endDate: sunset))

    // Phase 3: Evening (sunset → sunset+2h)
    intervals.append(PhaseInterval(phase: .evening, startDate: sunset, endDate: eveningEnd))

    // Phase 4: Night (evening end → sunrise OR reset boundary, whichever comes first)
    // Night wraps around: from evening end to next day's sunrise
    let nextMorningStart = min(endOfDay, sunrise.addingTimeInterval(24 * 3600))
    intervals.append(PhaseInterval(phase: .night, startDate: eveningEnd, endDate: nextMorningStart))

    return DayPhases(dateKey: dateKey, intervals: intervals, computedAt: Date())
}

private func createManualPhases(
    for date: Date,
    settings: UserSettings,
    dateKey: String? = nil
) -> DayPhases {
    let calendar = Calendar.current
    let key = dateKey ?? computeDateKeyForPhases(date: date, settings: settings)

    // Get overrides or use defaults
    let morningOverride = settings.manualPhaseOverrides[.morning] ?? PhaseOverride.defaults[.morning]!
    let afternoonOverride = settings.manualPhaseOverrides[.afternoon] ?? PhaseOverride.defaults[.afternoon]!
    let eveningOverride = settings.manualPhaseOverrides[.evening] ?? PhaseOverride.defaults[.evening]!
    let nightOverride = settings.manualPhaseOverrides[.night] ?? PhaseOverride.defaults[.night]!

    var intervals: [PhaseInterval] = []

    // Create dates from overrides
    guard let morningStart = calendar.date(bySettingHour: morningOverride.startHour, minute: morningOverride.startMinute, second: 0, of: date),
          let afternoonStart = calendar.date(bySettingHour: afternoonOverride.startHour, minute: afternoonOverride.startMinute, second: 0, of: date),
          let eveningStart = calendar.date(bySettingHour: eveningOverride.startHour, minute: eveningOverride.startMinute, second: 0, of: date),
          let nightStart = calendar.date(bySettingHour: nightOverride.startHour, minute: nightOverride.startMinute, second: 0, of: date) else {
        // Fallback to hardcoded defaults
        return createHardcodedDefaults(for: date, dateKey: key)
    }

    // Handle night wrapping to next day
    let nextMorningStart = calendar.date(byAdding: .day, value: 1, to: morningStart) ?? morningStart

    intervals.append(PhaseInterval(phase: .morning, startDate: morningStart, endDate: afternoonStart))
    intervals.append(PhaseInterval(phase: .afternoon, startDate: afternoonStart, endDate: eveningStart))
    intervals.append(PhaseInterval(phase: .evening, startDate: eveningStart, endDate: nightStart))
    intervals.append(PhaseInterval(phase: .night, startDate: nightStart, endDate: nextMorningStart))

    return DayPhases(dateKey: key, intervals: intervals, computedAt: Date())
}

private func createHardcodedDefaults(for date: Date, dateKey: String) -> DayPhases {
    let calendar = Calendar.current

    guard let morning = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: date),
          let afternoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date),
          let evening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: date),
          let night = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: date),
          let nextMorning = calendar.date(byAdding: .day, value: 1, to: morning) else {
        fatalError("Could not create phase dates")
    }

    let intervals = [
        PhaseInterval(phase: .morning, startDate: morning, endDate: afternoon),
        PhaseInterval(phase: .afternoon, startDate: afternoon, endDate: evening),
        PhaseInterval(phase: .evening, startDate: evening, endDate: night),
        PhaseInterval(phase: .night, startDate: night, endDate: nextMorning)
    ]

    return DayPhases(dateKey: dateKey, intervals: intervals, computedAt: Date())
}

// MARK: - Solar Calculations

private func computeSunriseSunset(
    for date: Date,
    location: CLLocationCoordinate2D
) -> (sunrise: Date, sunset: Date) {
    // Simplified solar calculation
    // In production, use a proper solar calculation library or framework

    let calendar = Calendar.current
    let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1

    // Approximate solar noon (12:00)
    guard let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) else {
        fatalError("Could not create noon date")
    }

    // Simple approximation based on latitude
    let latitude = location.latitude
    let declination = -23.45 * cos(2 * .pi * (Double(dayOfYear) + 10) / 365.0)
    let latRad = latitude * .pi / 180.0
    let decRad = declination * .pi / 180.0

    let cosHourAngle = -tan(latRad) * tan(decRad)
    let hourAngle = acos(max(-1, min(1, cosHourAngle)))
    let sunlightHours = 2 * hourAngle * 180 / .pi / 15.0

    let sunriseHour = 12 - sunlightHours / 2
    let sunsetHour = 12 + sunlightHours / 2

    let sunriseHourInt = Int(floor(sunriseHour))
    let sunriseMinuteInt = Int((sunriseHour - Double(sunriseHourInt)) * 60)

    let sunsetHourInt = Int(floor(sunsetHour))
    let sunsetMinuteInt = Int((sunsetHour - Double(sunsetHourInt)) * 60)

    guard let sunrise = calendar.date(bySettingHour: sunriseHourInt, minute: sunriseMinuteInt, second: 0, of: date),
          let sunset = calendar.date(bySettingHour: sunsetHourInt, minute: sunsetMinuteInt, second: 0, of: date) else {
        // Fallback to default times
        let defaultSunrise = calendar.date(bySettingHour: 6, minute: 30, second: 0, of: date)!
        let defaultSunset = calendar.date(bySettingHour: 18, minute: 30, second: 0, of: date)!
        return (defaultSunrise, defaultSunset)
    }

    return (sunrise, sunset)
}

private func computeDateKeyForPhases(date: Date, settings: UserSettings) -> String {
    let calendar = Calendar.current
    var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)

    let resetHour = settings.resetHourMinute.hour
    let resetMinute = settings.resetHourMinute.minute

    if let hour = components.hour, let minute = components.minute {
        let currentMinutes = hour * 60 + minute
        let resetMinutes = resetHour * 60 + resetMinute

        if currentMinutes < resetMinutes {
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
