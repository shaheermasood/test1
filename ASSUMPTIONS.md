# iOS Habit Tracker MVP - Assumptions & Technical Decisions

## Platform Requirements
- **iOS Minimum Version**: iOS 17.0+ (required for SwiftData)
- **Xcode Version**: Xcode 15.0+
- **Swift Version**: Swift 5.9+

## Dependencies
- **TCA Version**: swift-composable-architecture 1.15.0+
- **Point-Free TCA**: Using modern @Reducer macro, @ObservableState, Dependency system
- **SwiftData**: Native framework (iOS 17+)
- **UNUserNotificationCenter**: For local notifications

## Architecture Decisions

### TCA Structure
- Using modern Point-Free TCA with @Reducer macro
- @ObservableState for observable state
- @Dependency for dependency injection
- TestStore for unit testing
- ContinuousClock for time-based testing

### Persistence Strategy
- **SwiftData** for all persistence (UserSettings, Habits, Goals, Routines, Rules, Logs, Events, Reminders)
- **Local-only**: No iCloud, no accounts, no backend
- **Data stored** in app's container, cleared on uninstall
- **Migration strategy**: Not required for MVP (v1 schema)

### Domain Model Separation
- **Domain types**: Pure Swift structs/enums (Codable, Equatable, Sendable)
- **SwiftData models**: @Model classes for persistence
- **Mapping layer**: Extensions to convert between domain ↔ persistence

### Day Boundary Logic
- **Reset time**: 2:00 AM local time (configurable in settings)
- **Date key format**: "yyyy-MM-dd" computed with 2am boundary
- **Example**: Activity at 1:30 AM on Jan 5 belongs to Jan 4's dateKey

### Phase Computation
- **Mode 1 - Auto Solar**: Use location to compute sunrise/sunset
  - Morning: sunrise → noon
  - Afternoon: noon → sunset
  - Evening: sunset → sunset+2h
  - Night: evening end → 2am boundary
- **Mode 2 - Manual**: Use default times with user overrides
  - Morning: 6:00 - 12:00
  - Afternoon: 12:00 - 18:00
  - Evening: 18:00 - 22:00
  - Night: 22:00 - 6:00 (next day)
- **Fallback**: If location denied, use manual mode

### Notification Strategy
- **Daily cap**: Default 8 notifications/day (configurable)
- **Cooldown**: Default 45 minutes between notifications (configurable)
- **Priority system**:
  1. Dependency/cascade reminders (high priority)
  2. Phase-critical reminders (medium)
  3. General habit reminders (low)
- **Actions**: Done, Snooze (5/15/60 min), Skip Today
- **Expiration**: Each reminder has expiration; expired = missed (gentle)

### Rule Engine Design
- **Pure functional**: No side effects in evaluation
- **Deterministic**: Same input → same output
- **Testable**: All dependencies injected
- **Output**: SchedulingDecisions (schedule/cancel intents)
- **Throttling applied** after rule evaluation

### Location & Privacy
- **Location**: Optional, only for sunrise/sunset computation
- **No tracking**: Location never leaves device
- **Privacy-first**: All data local, no analytics, no telemetry

### Testing Strategy
- **Unit tests** for:
  - DayService (2am boundary edge cases)
  - RuleEngine (condition evaluation, cascading logic)
  - Scheduling decisions (throttling, expiration, priority)
- **TCA TestStore** for feature reducers
- **Deterministic testing**: Using injected Clock, UUID, Date dependencies

## MVP Scope Decisions

### Included
- Local notifications with interactive actions
- Phase-based time windows
- Rule engine for conditional reminders
- Cascading dependencies (e.g., "eat before supplements")
- Salvage plans (gentle rebalancing)
- Late correction (mark yesterday's completion)
- Simple city gamification
- Basic insights (streaks, consistency)
- Templates (Meals+Supplements, Morning routine)
- Natural language intake (simple parser)

### Deferred (Post-MVP)
- Apple Health integration
- Widgets
- Apple Watch app
- Siri shortcuts
- Advanced analytics
- Social features
- Data export
- Custom themes beyond system light/dark
- Advanced NL parsing (keep simple regex-based parser)

## File Structure

```
HabitTracker/
├── App/
│   ├── HabitTrackerApp.swift
│   └── Info.plist
├── Features/
│   ├── App/
│   │   └── AppFeature.swift
│   ├── Onboarding/
│   │   └── OnboardingFeature.swift
│   ├── Today/
│   │   └── TodayFeature.swift
│   ├── Timeline/
│   │   └── TimelineFeature.swift
│   ├── Habits/
│   │   └── HabitsFeature.swift
│   ├── RoutineBuilder/
│   │   ├── RoutineBuilderFeature.swift
│   │   ├── TemplateChooser.swift
│   │   └── NLIntake.swift
│   ├── Salvage/
│   │   └── SalvageFeature.swift
│   ├── City/
│   │   └── CityFeature.swift
│   ├── Insights/
│   │   └── InsightsFeature.swift
│   └── Settings/
│       └── SettingsFeature.swift
├── Domain/
│   ├── Models/
│   │   ├── Phase.swift
│   │   ├── Habit.swift
│   │   ├── Goal.swift
│   │   ├── Routine.swift
│   │   ├── Rule.swift
│   │   ├── CompletionEvent.swift
│   │   └── Reminder.swift
│   ├── RuleEngine/
│   │   ├── RuleEngine.swift
│   │   ├── RuleTrigger.swift
│   │   ├── RuleCondition.swift
│   │   ├── RuleAction.swift
│   │   ├── DayContext.swift
│   │   └── SchedulingDecision.swift
│   └── Templates/
│       └── RoutineTemplates.swift
├── Persistence/
│   ├── SwiftDataModels.swift
│   └── SwiftDataClient.swift
├── Clients/
│   ├── NotificationClient.swift
│   ├── PhaseService.swift
│   ├── DayService.swift
│   ├── LocationClient.swift
│   └── QuoteClient.swift
├── UIComponents/
│   ├── PhaseCard.swift
│   ├── HabitCard.swift
│   ├── ReturnHookCard.swift
│   └── SalvagePlanCard.swift
└── Tests/
    ├── DayServiceTests.swift
    ├── RuleEngineTests.swift
    └── FeatureTests/
```

## Copy Tone
- **Zen Coach**: Gentle, non-judgmental, growth-focused
- **No shame**: Never use "failed", "you missed", etc.
- **Salvage language**: "Let's rebalance your evening" vs "You failed morning routine"
- **Motivational**: Daily quote, gentle nudges

## Known Limitations
- Manual sleep/wake times (no automatic detection for MVP)
- Basic NL parsing (keyword matching, not LLM)
- Single timezone support (device local time)
- No multi-device sync
- Limited to ~1000 habits (performance not optimized beyond that)

## Future Considerations
- Background app refresh for proactive scheduling
- More sophisticated NL understanding
- ML-based habit prediction
- Smarter salvage plan generation
- Adaptive notification timing based on engagement patterns
