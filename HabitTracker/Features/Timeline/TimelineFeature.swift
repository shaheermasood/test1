import SwiftUI
import ComposableArchitecture

// MARK: - Timeline Feature

@Reducer
public struct TimelineFeature {
    @ObservableState
    public struct State: Equatable {
        var phases: DayPhases?
        var habits: [Habit] = []
        var completions: [CompletionEvent] = []

        public init() {}
    }

    public enum Action {
        case refresh
        case dataLoaded(phases: DayPhases, habits: [Habit], completions: [CompletionEvent])
    }

    @Dependency(\.swiftDataClient) var swiftDataClient
    @Dependency(\.phaseService) var phaseService
    @Dependency(\.dayService) var dayService
    @Dependency(\.locationClient) var locationClient
    @Dependency(\.date) var date

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .refresh:
                return .run { send in
                    let settings = try await swiftDataClient.fetchSettings()
                    let currentDate = date.now
                    let dateKey = dayService.dateKey(currentDate, settings)

                    let location = try? await locationClient.getCurrentLocation()
                    let phases = await phaseService.computePhases(currentDate, settings, location)

                    let habits = try await swiftDataClient.fetchHabits()
                    let completions = try await swiftDataClient.fetchCompletionEvents(dateKey)

                    await send(.dataLoaded(phases: phases, habits: habits, completions: completions))
                }

            case .dataLoaded(let phases, let habits, let completions):
                state.phases = phases
                state.habits = habits
                state.completions = completions
                return .none
            }
        }
    }
}

// MARK: - Timeline View

public struct TimelineView: View {
    let store: StoreOf<TimelineFeature>

    public init(store: StoreOf<TimelineFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                if let phases = store.phases {
                    VStack(spacing: 16) {
                        ForEach(phases.intervals, id: \.phase) { interval in
                            PhaseCard(
                                interval: interval,
                                habits: store.habits.filter { $0.defaultPhase == interval.phase },
                                completions: store.completions
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Timeline")
            .refreshable {
                store.send(.refresh)
            }
        }
        .onAppear {
            store.send(.refresh)
        }
    }
}

struct PhaseCard: View {
    let interval: PhaseInterval
    let habits: [Habit]
    let completions: [CompletionEvent]

    var completedHabitIds: Set<UUID> {
        Set(completions.map(\.habitId))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: interval.phase.icon)
                    .foregroundColor(.blue)
                Text(interval.phase.displayName)
                    .font(.headline)
                Spacer()
                Text("\(habits.filter { completedHabitIds.contains($0.id) }.count)/\(habits.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(habits) { habit in
                HStack {
                    Image(systemName: completedHabitIds.contains(habit.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(completedHabitIds.contains(habit.id) ? .green : .gray)
                    Text(habit.title)
                    Spacer()
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
