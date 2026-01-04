import SwiftUI
import ComposableArchitecture

// MARK: - App Feature

@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        var selectedTab: Tab = .today
        var hasCompletedOnboarding: Bool = false

        // Child features
        var onboarding: OnboardingFeature.State?
        var today: TodayFeature.State
        var timeline: TimelineFeature.State
        var habits: HabitsFeature.State
        var settings: SettingsFeature.State

        public init() {
            self.today = TodayFeature.State()
            self.timeline = TimelineFeature.State()
            self.habits = HabitsFeature.State()
            self.settings = SettingsFeature.State()
        }
    }

    public enum Action {
        case onAppear
        case selectedTabChanged(Tab)
        case onboardingCompleted
        case dailyRefresh

        // Child actions
        case onboarding(OnboardingFeature.Action)
        case today(TodayFeature.Action)
        case timeline(TimelineFeature.Action)
        case habits(HabitsFeature.Action)
        case settings(SettingsFeature.Action)
    }

    public enum Tab: String, CaseIterable {
        case today
        case timeline
        case habits
        case settings

        var title: String {
            switch self {
            case .today: return "Today"
            case .timeline: return "Timeline"
            case .habits: return "Habits"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .today: return "house.fill"
            case .timeline: return "clock.fill"
            case .habits: return "list.bullet"
            case .settings: return "gear"
            }
        }
    }

    @Dependency(\.swiftDataClient) var swiftDataClient
    @Dependency(\.dayService) var dayService
    @Dependency(\.notificationClient) var notificationClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Check if onboarding is needed
                return .run { send in
                    // Check for existing settings/data
                    let settings = try await swiftDataClient.fetchSettings()
                    let habits = try await swiftDataClient.fetchHabits()

                    if habits.isEmpty {
                        // Show onboarding
                        await send(.onboarding(.start))
                    } else {
                        // Skip onboarding
                        await send(.onboardingCompleted)
                    }

                    // Register notification categories
                    await notificationClient.registerCategories()

                    // Trigger daily refresh
                    await send(.dailyRefresh)
                }

            case .selectedTabChanged(let tab):
                state.selectedTab = tab
                return .none

            case .onboardingCompleted:
                state.hasCompletedOnboarding = true
                state.onboarding = nil
                return .run { send in
                    await send(.dailyRefresh)
                }

            case .dailyRefresh:
                // Refresh all tabs with latest data
                return .merge(
                    .send(.today(.refresh)),
                    .send(.timeline(.refresh)),
                    .send(.habits(.refresh))
                )

            case .onboarding:
                return .none

            case .today, .timeline, .habits, .settings:
                return .none
            }
        }
        .ifLet(\.onboarding, action: \.onboarding) {
            OnboardingFeature()
        }

        Scope(state: \.today, action: \.today) {
            TodayFeature()
        }

        Scope(state: \.timeline, action: \.timeline) {
            TimelineFeature()
        }

        Scope(state: \.habits, action: \.habits) {
            HabitsFeature()
        }

        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
    }
}

// MARK: - App View

public struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            if let onboardingStore = store.scope(state: \.onboarding, action: \.onboarding) {
                OnboardingView(store: onboardingStore)
            } else {
                TabView(selection: $store.selectedTab.sending(\.selectedTabChanged)) {
                    TodayView(store: store.scope(state: \.today, action: \.today))
                        .tabItem {
                            Label("Today", systemImage: "house.fill")
                        }
                        .tag(AppFeature.Tab.today)

                    TimelineView(store: store.scope(state: \.timeline, action: \.timeline))
                        .tabItem {
                            Label("Timeline", systemImage: "clock.fill")
                        }
                        .tag(AppFeature.Tab.timeline)

                    HabitsView(store: store.scope(state: \.habits, action: \.habits))
                        .tabItem {
                            Label("Habits", systemImage: "list.bullet")
                        }
                        .tag(AppFeature.Tab.habits)

                    SettingsView(store: store.scope(state: \.settings, action: \.settings))
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                        .tag(AppFeature.Tab.settings)
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}
