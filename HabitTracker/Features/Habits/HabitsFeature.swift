import SwiftUI
import ComposableArchitecture

// MARK: - Habits Feature

@Reducer
public struct HabitsFeature {
    @ObservableState
    public struct State: Equatable {
        var habits: [Habit] = []
        var showingAddHabit: Bool = false

        public init() {}
    }

    public enum Action {
        case refresh
        case dataLoaded([Habit])
        case addHabitTapped
        case saveNewHabit(String, HabitCategory, PhaseName)
        case habitSaved
        case deleteHabit(UUID)
        case habitDeleted
    }

    @Dependency(\.swiftDataClient) var swiftDataClient
    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .refresh:
                return .run { send in
                    let habits = try await swiftDataClient.fetchHabits()
                    await send(.dataLoaded(habits))
                }

            case .dataLoaded(let habits):
                state.habits = habits
                return .none

            case .addHabitTapped:
                state.showingAddHabit = true
                return .none

            case .saveNewHabit(let title, let category, let phase):
                state.showingAddHabit = false
                return .run { send in
                    let habit = Habit(
                        id: uuid(),
                        title: title,
                        category: category,
                        defaultPhase: phase,
                        isActive: true,
                        buildingType: BuildingType.forCategory(category),
                        createdAt: date.now
                    )

                    try await swiftDataClient.saveHabit(habit)
                    await send(.habitSaved)
                }

            case .habitSaved:
                return .send(.refresh)

            case .deleteHabit(let id):
                return .run { send in
                    try await swiftDataClient.deleteHabit(id)
                    await send(.habitDeleted)
                }

            case .habitDeleted:
                return .send(.refresh)
            }
        }
    }
}

// MARK: - Habits View

public struct HabitsView: View {
    @Bindable var store: StoreOf<HabitsFeature>

    public init(store: StoreOf<HabitsFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            List {
                ForEach(store.habits) { habit in
                    HStack {
                        Image(systemName: habit.category.icon)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text(habit.title)
                                .font(.headline)
                            Text(habit.defaultPhase.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        store.send(.deleteHabit(store.habits[index].id))
                    }
                }
            }
            .navigationTitle("Habits")
            .toolbar {
                Button {
                    store.send(.addHabitTapped)
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $store.showingAddHabit) {
                AddHabitView(store: store)
            }
        }
        .onAppear {
            store.send(.refresh)
        }
    }
}

struct AddHabitView: View {
    let store: StoreOf<HabitsFeature>
    @State private var title: String = ""
    @State private var selectedCategory: HabitCategory = .general
    @State private var selectedPhase: PhaseName = .morning

    var body: some View {
        NavigationStack {
            Form {
                TextField("Habit Name", text: $title)

                Picker("Category", selection: $selectedCategory) {
                    ForEach(HabitCategory.allCases, id: \.self) { category in
                        Text(category.displayName).tag(category)
                    }
                }

                Picker("Default Phase", selection: $selectedPhase) {
                    ForEach(PhaseName.allCases, id: \.self) { phase in
                        Text(phase.displayName).tag(phase)
                    }
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.send(.addHabitTapped)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.send(.saveNewHabit(title, selectedCategory, selectedPhase))
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
