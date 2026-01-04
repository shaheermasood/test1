import Foundation

// MARK: - Habit Category

public enum HabitCategory: String, Codable, Equatable, Sendable, CaseIterable {
    case general
    case meal
    case hydration
    case exercise
    case sleep
    case meditation
    case journaling
    case medication
    case supplements
    case hygiene
    case social
    case creative
    case learning

    public var displayName: String {
        switch self {
        case .general: return "General"
        case .meal: return "Meal"
        case .hydration: return "Hydration"
        case .exercise: return "Exercise"
        case .sleep: return "Sleep"
        case .meditation: return "Meditation"
        case .journaling: return "Journaling"
        case .medication: return "Medication"
        case .supplements: return "Supplements"
        case .hygiene: return "Hygiene"
        case .social: return "Social"
        case .creative: return "Creative"
        case .learning: return "Learning"
        }
    }

    public var icon: String {
        switch self {
        case .general: return "circle.fill"
        case .meal: return "fork.knife"
        case .hydration: return "drop.fill"
        case .exercise: return "figure.run"
        case .sleep: return "bed.double.fill"
        case .meditation: return "leaf.fill"
        case .journaling: return "book.fill"
        case .medication: return "cross.case.fill"
        case .supplements: return "pills.fill"
        case .hygiene: return "sparkles"
        case .social: return "person.2.fill"
        case .creative: return "paintbrush.fill"
        case .learning: return "book.pages.fill"
        }
    }
}

// MARK: - Building Type (for City gamification)

public enum BuildingType: String, Codable, Equatable, Sendable {
    case house
    case garden
    case library
    case gym
    case temple
    case cafe
    case hospital
    case laboratory
    case studio
    case tower

    public var icon: String {
        switch self {
        case .house: return "house.fill"
        case .garden: return "tree.fill"
        case .library: return "building.columns.fill"
        case .gym: return "dumbbell.fill"
        case .temple: return "building.fill"
        case .cafe: return "cup.and.saucer.fill"
        case .hospital: return "cross.fill"
        case .laboratory: return "flask.fill"
        case .studio: return "paintpalette.fill"
        case .tower: return "building.2.fill"
        }
    }

    public static func forCategory(_ category: HabitCategory) -> BuildingType {
        switch category {
        case .general: return .house
        case .meal, .hydration: return .cafe
        case .exercise: return .gym
        case .sleep, .meditation: return .temple
        case .journaling, .learning: return .library
        case .medication, .supplements: return .hospital
        case .hygiene: return .garden
        case .social: return .tower
        case .creative: return .studio
        }
    }
}

// MARK: - Habit (Domain)

public struct Habit: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var title: String
    public var category: HabitCategory
    public var defaultPhase: PhaseName
    public var isActive: Bool
    public var buildingType: BuildingType
    public let createdAt: Date

    public init(
        id: UUID,
        title: String,
        category: HabitCategory,
        defaultPhase: PhaseName,
        isActive: Bool = true,
        buildingType: BuildingType? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.defaultPhase = defaultPhase
        self.isActive = isActive
        self.buildingType = buildingType ?? BuildingType.forCategory(category)
        self.createdAt = createdAt
    }
}
