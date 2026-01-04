import Foundation

// MARK: - Completion Metadata

public struct CompletionMetadata: Codable, Equatable, Sendable {
    public var note: String?
    public var calories: Int?
    public var mealName: String?
    public var mealType: MealType?
    public var customData: [String: String]?

    public init(
        note: String? = nil,
        calories: Int? = nil,
        mealName: String? = nil,
        mealType: MealType? = nil,
        customData: [String: String]? = nil
    ) {
        self.note = note
        self.calories = calories
        self.mealName = mealName
        self.mealType = mealType
        self.customData = customData
    }
}

// MARK: - Meal Type

public enum MealType: String, Codable, Equatable, Sendable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack

    public var displayName: String {
        rawValue.capitalized
    }

    public var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "carrot.fill"
        }
    }
}

// MARK: - Completion Event (Domain)

public struct CompletionEvent: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let habitId: UUID
    public let timestamp: Date
    public let dateKey: String
    public var metadata: CompletionMetadata
    public var isLateCorrection: Bool

    public init(
        id: UUID,
        habitId: UUID,
        timestamp: Date,
        dateKey: String,
        metadata: CompletionMetadata = CompletionMetadata(),
        isLateCorrection: Bool = false
    ) {
        self.id = id
        self.habitId = habitId
        self.timestamp = timestamp
        self.dateKey = dateKey
        self.metadata = metadata
        self.isLateCorrection = isLateCorrection
    }
}
