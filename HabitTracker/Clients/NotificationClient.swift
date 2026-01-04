import Foundation
import UserNotifications
import Dependencies

// MARK: - Notification Event

public enum NotificationEvent: Equatable, Sendable {
    case done(reminderId: UUID, habitId: UUID?)
    case snooze(reminderId: UUID, habitId: UUID?, minutes: Int)
    case skipToday(reminderId: UUID, habitId: UUID?)
}

// MARK: - Notification Content

public struct NotificationContent: Sendable {
    public let title: String
    public let body: String
    public let userInfo: [String: String]
    public let categoryId: String

    public init(title: String, body: String, userInfo: [String: String] = [:], categoryId: String = "HABIT_REMINDER") {
        self.title = title
        self.body = body
        self.userInfo = userInfo
        self.categoryId = categoryId
    }
}

// MARK: - Notification Action

public enum NotificationAction: String, CaseIterable, Sendable {
    case done = "DONE_ACTION"
    case snooze5 = "SNOOZE_5_ACTION"
    case snooze15 = "SNOOZE_15_ACTION"
    case snooze60 = "SNOOZE_60_ACTION"
    case skipToday = "SKIP_TODAY_ACTION"

    public var title: String {
        switch self {
        case .done: return "Done"
        case .snooze5: return "5 min"
        case .snooze15: return "15 min"
        case .snooze60: return "1 hour"
        case .skipToday: return "Skip Today"
        }
    }

    public var options: UNNotificationActionOptions {
        switch self {
        case .done: return [.foreground]
        case .snooze5, .snooze15, .snooze60: return []
        case .skipToday: return [.destructive]
        }
    }
}

// MARK: - Notification Client

public struct NotificationClient: Sendable {
    public var requestAuthorization: @Sendable () async throws -> Bool
    public var schedule: @Sendable (String, Date, NotificationContent) async throws -> Void
    public var cancel: @Sendable ([String]) async -> Void
    public var cancelAll: @Sendable () async -> Void
    public var registerCategories: @Sendable () async -> Void
    public var handleResponse: @Sendable (String, String, [AnyHashable: Any]) async -> NotificationEvent?

    public init(
        requestAuthorization: @escaping @Sendable () async throws -> Bool,
        schedule: @escaping @Sendable (String, Date, NotificationContent) async throws -> Void,
        cancel: @escaping @Sendable ([String]) async -> Void,
        cancelAll: @escaping @Sendable () async -> Void,
        registerCategories: @escaping @Sendable () async -> Void,
        handleResponse: @escaping @Sendable (String, String, [AnyHashable: Any]) async -> NotificationEvent?
    ) {
        self.requestAuthorization = requestAuthorization
        self.schedule = schedule
        self.cancel = cancel
        self.cancelAll = cancelAll
        self.registerCategories = registerCategories
        self.handleResponse = handleResponse
    }
}

// MARK: - Dependency

extension NotificationClient: DependencyKey {
    public static let liveValue: NotificationClient = {
        let center = UNUserNotificationCenter.current()

        return NotificationClient(
            requestAuthorization: {
                let options: UNAuthorizationOptions = [.alert, .sound, .badge]
                return try await center.requestAuthorization(options: options)
            },
            schedule: { identifier, fireDate, content in
                // Create notification content
                let notificationContent = UNMutableNotificationContent()
                notificationContent.title = content.title
                notificationContent.body = content.body
                notificationContent.sound = .default
                notificationContent.categoryIdentifier = content.categoryId

                // Add userInfo
                var userInfo: [String: Any] = [:]
                for (key, value) in content.userInfo {
                    userInfo[key] = value
                }
                notificationContent.userInfo = userInfo

                // Create trigger
                let triggerDate = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: fireDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

                // Create request
                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: notificationContent,
                    trigger: trigger
                )

                try await center.add(request)
            },
            cancel: { identifiers in
                center.removePendingNotificationRequests(withIdentifiers: identifiers)
            },
            cancelAll: {
                center.removeAllPendingNotificationRequests()
            },
            registerCategories: {
                // Create actions
                let doneAction = UNNotificationAction(
                    identifier: NotificationAction.done.rawValue,
                    title: NotificationAction.done.title,
                    options: NotificationAction.done.options
                )

                let snooze5Action = UNNotificationAction(
                    identifier: NotificationAction.snooze5.rawValue,
                    title: NotificationAction.snooze5.title,
                    options: NotificationAction.snooze5.options
                )

                let snooze15Action = UNNotificationAction(
                    identifier: NotificationAction.snooze15.rawValue,
                    title: NotificationAction.snooze15.title,
                    options: NotificationAction.snooze15.options
                )

                let snooze60Action = UNNotificationAction(
                    identifier: NotificationAction.snooze60.rawValue,
                    title: NotificationAction.snooze60.title,
                    options: NotificationAction.snooze60.options
                )

                let skipAction = UNNotificationAction(
                    identifier: NotificationAction.skipToday.rawValue,
                    title: NotificationAction.skipToday.title,
                    options: NotificationAction.skipToday.options
                )

                // Create category
                let habitCategory = UNNotificationCategory(
                    identifier: "HABIT_REMINDER",
                    actions: [doneAction, snooze5Action, snooze15Action, snooze60Action, skipAction],
                    intentIdentifiers: [],
                    options: []
                )

                center.setNotificationCategories([habitCategory])
            },
            handleResponse: { actionId, categoryId, userInfo in
                // Extract reminder ID and habit ID from userInfo
                guard let reminderIdString = userInfo["reminderId"] as? String,
                      let reminderId = UUID(uuidString: reminderIdString) else {
                    return nil
                }

                let habitId = (userInfo["habitId"] as? String).flatMap { UUID(uuidString: $0) }

                // Parse action
                switch actionId {
                case NotificationAction.done.rawValue:
                    return .done(reminderId: reminderId, habitId: habitId)

                case NotificationAction.snooze5.rawValue:
                    return .snooze(reminderId: reminderId, habitId: habitId, minutes: 5)

                case NotificationAction.snooze15.rawValue:
                    return .snooze(reminderId: reminderId, habitId: habitId, minutes: 15)

                case NotificationAction.snooze60.rawValue:
                    return .snooze(reminderId: reminderId, habitId: habitId, minutes: 60)

                case NotificationAction.skipToday.rawValue:
                    return .skipToday(reminderId: reminderId, habitId: habitId)

                default:
                    return nil
                }
            }
        )
    }()

    public static let testValue = NotificationClient(
        requestAuthorization: { true },
        schedule: { _, _, _ in },
        cancel: { _ in },
        cancelAll: { },
        registerCategories: { },
        handleResponse: { _, _, _ in nil }
    )
}

extension DependencyValues {
    public var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
