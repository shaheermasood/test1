import SwiftUI
import ComposableArchitecture

// MARK: - Settings Feature

@Reducer
public struct SettingsFeature {
    @ObservableState
    public struct State: Equatable {
        var settings: UserSettings = UserSettings()

        public init() {}
    }

    public enum Action {
        case refresh
        case settingsLoaded(UserSettings)
        case updateResetTime(hour: Int, minute: Int)
        case updateNotificationCap(Int)
        case updateCooldown(Int)
        case updatePhaseMode(PhaseMode)
        case settingsSaved
    }

    @Dependency(\.swiftDataClient) var swiftDataClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .refresh:
                return .run { send in
                    let settings = try await swiftDataClient.fetchSettings()
                    await send(.settingsLoaded(settings))
                }

            case .settingsLoaded(let settings):
                state.settings = settings
                return .none

            case .updateResetTime(let hour, let minute):
                state.settings.resetHourMinute = (hour, minute)
                return .run { [settings = state.settings] send in
                    try await swiftDataClient.saveSettings(settings)
                    await send(.settingsSaved)
                }

            case .updateNotificationCap(let cap):
                state.settings.notificationCapPerDay = cap
                return .run { [settings = state.settings] send in
                    try await swiftDataClient.saveSettings(settings)
                    await send(.settingsSaved)
                }

            case .updateCooldown(let cooldown):
                state.settings.notificationCooldownMinutes = cooldown
                return .run { [settings = state.settings] send in
                    try await swiftDataClient.saveSettings(settings)
                    await send(.settingsSaved)
                }

            case .updatePhaseMode(let mode):
                state.settings.phaseMode = mode
                return .run { [settings = state.settings] send in
                    try await swiftDataClient.saveSettings(settings)
                    await send(.settingsSaved)
                }

            case .settingsSaved:
                return .none
            }
        }
    }
}

// MARK: - Settings View

public struct SettingsView: View {
    let store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Day Boundary") {
                    Stepper("Reset Time: \(String(format: "%02d:%02d", store.settings.resetHourMinute.hour, store.settings.resetHourMinute.minute))",
                            value: .constant(store.settings.resetHourMinute.hour),
                            in: 0...23)
                }

                Section("Notifications") {
                    Stepper("Daily Cap: \(store.settings.notificationCapPerDay)",
                            value: .constant(store.settings.notificationCapPerDay),
                            in: 1...20) {
                        store.send(.updateNotificationCap($0))
                    }

                    Stepper("Cooldown: \(store.settings.notificationCooldownMinutes) min",
                            value: .constant(store.settings.notificationCooldownMinutes),
                            in: 15...120,
                            step: 15) {
                        store.send(.updateCooldown($0))
                    }
                }

                Section("Phases") {
                    Picker("Mode", selection: .constant(store.settings.phaseMode)) {
                        Text("Auto (Sunrise/Sunset)").tag(PhaseMode.autoSolar)
                        Text("Manual").tag(PhaseMode.manual)
                    }
                    .onChange(of: store.settings.phaseMode) { _, newValue in
                        store.send(.updatePhaseMode(newValue))
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear {
            store.send(.refresh)
        }
    }
}
