import SwiftUI
import ComposableArchitecture

// MARK: - Onboarding Feature

@Reducer
public struct OnboardingFeature {
    @ObservableState
    public struct State: Equatable {
        var currentStep: Step = .welcome
        var notificationsAuthorized: Bool = false
        var locationAuthorized: Bool = false
        var selectedTemplate: RoutineTemplate?

        public init() {}

        public enum Step: Equatable {
            case welcome
            case permissions
            case templateSelection
            case completion
        }
    }

    public enum Action {
        case start
        case nextStep
        case previousStep
        case requestNotifications
        case notificationsResponse(Bool)
        case requestLocation
        case locationResponse(Bool)
        case selectTemplate(RoutineTemplate)
        case createRoutine
        case routineCreated
        case complete
    }

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.locationClient) var locationClient
    @Dependency(\.swiftDataClient) var swiftDataClient
    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .start:
                state.currentStep = .welcome
                return .none

            case .nextStep:
                switch state.currentStep {
                case .welcome:
                    state.currentStep = .permissions
                case .permissions:
                    state.currentStep = .templateSelection
                case .templateSelection:
                    state.currentStep = .completion
                case .completion:
                    return .send(.complete)
                }
                return .none

            case .previousStep:
                switch state.currentStep {
                case .welcome:
                    return .none
                case .permissions:
                    state.currentStep = .welcome
                case .templateSelection:
                    state.currentStep = .permissions
                case .completion:
                    state.currentStep = .templateSelection
                }
                return .none

            case .requestNotifications:
                return .run { send in
                    let authorized = try await notificationClient.requestAuthorization()
                    await send(.notificationsResponse(authorized))
                } catch: { _, send in
                    await send(.notificationsResponse(false))
                }

            case .notificationsResponse(let authorized):
                state.notificationsAuthorized = authorized
                return .none

            case .requestLocation:
                return .run { send in
                    let authorized = try await locationClient.requestAuthorization()
                    await send(.locationResponse(authorized))
                } catch: { _, send in
                    await send(.locationResponse(false))
                }

            case .locationResponse(let authorized):
                state.locationAuthorized = authorized
                return .none

            case .selectTemplate(let template):
                state.selectedTemplate = template
                return .send(.createRoutine)

            case .createRoutine:
                guard let template = state.selectedTemplate else {
                    return .none
                }

                return .run { send in
                    let instantiator = TemplateInstantiator()
                    let result = instantiator.instantiate(template: template)

                    // Save to database
                    for habit in result.habits {
                        try await swiftDataClient.saveHabit(habit)
                    }

                    for goal in result.goals {
                        try await swiftDataClient.saveGoal(goal)
                    }

                    try await swiftDataClient.saveRoutine(result.routine)

                    for rule in result.rules {
                        try await swiftDataClient.saveRule(rule)
                    }

                    await send(.routineCreated)
                }

            case .routineCreated:
                state.currentStep = .completion
                return .none

            case .complete:
                return .none
            }
        }
    }
}

// MARK: - Onboarding View

public struct OnboardingView: View {
    let store: StoreOf<OnboardingFeature>

    public init(store: StoreOf<OnboardingFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack {
            switch store.currentStep {
            case .welcome:
                WelcomeStepView(store: store)
            case .permissions:
                PermissionsStepView(store: store)
            case .templateSelection:
                TemplateSelectionView(store: store)
            case .completion:
                CompletionStepView(store: store)
            }
        }
    }
}

// MARK: - Welcome Step

struct WelcomeStepView: View {
    let store: StoreOf<OnboardingFeature>

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "leaf.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("Welcome to Habit Tracker")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Build lasting routines with gentle guidance")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button("Get Started") {
                store.send(.nextStep)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

// MARK: - Permissions Step

struct PermissionsStepView: View {
    let store: StoreOf<OnboardingFeature>

    var body: some View {
        VStack(spacing: 32) {
            Text("Permissions")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(spacing: 24) {
                PermissionRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    description: "Get gentle reminders for your habits",
                    isAuthorized: store.notificationsAuthorized
                ) {
                    store.send(.requestNotifications)
                }

                PermissionRow(
                    icon: "location.fill",
                    title: "Location (Optional)",
                    description: "Adjust phases based on sunrise/sunset",
                    isAuthorized: store.locationAuthorized
                ) {
                    store.send(.requestLocation)
                }
            }

            Spacer()

            Button("Continue") {
                store.send(.nextStep)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!store.notificationsAuthorized)
        }
        .padding()
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isAuthorized: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isAuthorized {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Allow") {
                    action()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Template Selection

struct TemplateSelectionView: View {
    let store: StoreOf<OnboardingFeature>

    var body: some View {
        VStack(spacing: 24) {
            Text("Choose a Starting Routine")
                .font(.largeTitle)
                .fontWeight(.bold)

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(RoutineTemplate.all, id: \.id) { template in
                        TemplateCard(template: template) {
                            store.send(.selectTemplate(template))
                        }
                    }

                    Button("Skip for now") {
                        store.send(.nextStep)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

struct TemplateCard: View {
    let template: RoutineTemplate
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: template.icon)
                    .font(.title)
                    .foregroundColor(.blue)
                    .frame(width: 50)

                VStack(alignment: .leading) {
                    Text(template.name)
                        .font(.headline)
                    Text(template.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Completion Step

struct CompletionStepView: View {
    let store: StoreOf<OnboardingFeature>

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("You're All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your journey to better habits begins now")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button("Start") {
                store.send(.complete)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}
