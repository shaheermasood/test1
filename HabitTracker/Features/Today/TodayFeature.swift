import SwiftUI
import ComposableArchitecture

// MARK: - Today Feature

@Reducer
public struct TodayFeature {
    @ObservableState
    public struct State: Equatable {
        var dateKey: String = ""
        var quote: Quote?
        var currentPhase: PhaseName?
        var habits: [Habit] = []
        var completions: [CompletionEvent] = []
        var reminders: [Reminder] = []
        var isLoading: Bool = false

        public init() {}

        var completedHabitIds: Set<UUID> {
            Set(completions.map(\.habitId))
        }
    }

    public enum Action {
        case refresh
        case dataLoaded(habits: [Habit], completions: [CompletionEvent], reminders: [Reminder], quote: Quote, dateKey: String)
        case completeHabit(UUID)
        case habitCompleted
    }

    @Dependency(\.swiftDataClient) var swiftDataClient
    @Dependency(\.dayService) var dayService
    @Dependency(\.quoteClient) var quoteClient
    @Dependency(\.date) var date
    @Dependency(\.uuid) var uuid

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .refresh:
                state.isLoading = true
                return .run { send in
                    let settings = try await swiftDataClient.fetchSettings()
                    let currentDate = date.now
                    let dateKey = dayService.dateKey(currentDate, settings)

                    let habits = try await swiftDataClient.fetchHabits()
                    let completions = try await swiftDataClient.fetchCompletionEvents(dateKey)
                    let reminders = try await swiftDataClient.fetchReminders(dateKey)
                    let quote = await quoteClient.getDailyQuote(dateKey)

                    await send(.dataLoaded(
                        habits: habits,
                        completions: completions,
                        reminders: reminders,
                        quote: quote,
                        dateKey: dateKey
                    ))
                }

            case .dataLoaded(let habits, let completions, let reminders, let quote, let dateKey):
                state.habits = habits
                state.completions = completions
                state.reminders = reminders
                state.quote = quote
                state.dateKey = dateKey
                state.isLoading = false
                return .none

            case .completeHabit(let habitId):
                return .run { [dateKey = state.dateKey] send in
                    let event = CompletionEvent(
                        id: uuid(),
                        habitId: habitId,
                        timestamp: date.now,
                        dateKey: dateKey,
                        metadata: CompletionMetadata()
                    )

                    try await swiftDataClient.saveCompletionEvent(event)
                    await send(.habitCompleted)
                }

            case .habitCompleted:
                return .send(.refresh)
            }
        }
    }
}

// MARK: - Today View

public struct TodayView: View {
    let store: StoreOf<TodayFeature>

    public init(store: StoreOf<TodayFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Quote
                    if let quote = store.quote {
                        QuoteCard(quote: quote)
                    }

                    // Habits for today
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's Habits")
                            .font(.title2)
                            .fontWeight(.bold)

                        ForEach(store.habits) { habit in
                            HabitRow(
                                habit: habit,
                                isCompleted: store.completedHabitIds.contains(habit.id)
                            ) {
                                store.send(.completeHabit(habit.id))
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
            .refreshable {
                store.send(.refresh)
            }
        }
        .onAppear {
            store.send(.refresh)
        }
    }
}

struct QuoteCard: View {
    let quote: Quote

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(quote.text)
                .font(.title3)
                .italic()

            if let author = quote.author {
                Text("— \(author)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct HabitRow: View {
    let habit: Habit
    let isCompleted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isCompleted ? .green : .gray)

                VStack(alignment: .leading) {
                    Text(habit.title)
                        .font(.headline)
                    Text(habit.category.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: habit.category.icon)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
