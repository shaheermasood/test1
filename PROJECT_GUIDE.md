# Habit Tracker MVP - iOS App

A sophisticated iOS habit tracking app built with SwiftUI, SwiftData, and The Composable Architecture (TCA). Features adaptive phase-based routines, conditional cascading reminders, intelligent salvage plans, and gentle gamification.

## 📱 Overview

This app helps users build lasting habits through:
- **Phase-based time windows** (Morning/Afternoon/Evening/Night) derived from sunrise/sunset
- **Conditional cascading reminders** (e.g., "eat before supplements")
- **Expiration + salvage plans** with gentle rebalancing
- **Zen coach tone** throughout
- **Local-only storage** (no accounts, no cloud sync)

## 🏗️ Architecture

### The Composable Architecture (TCA)

Modern Point-Free TCA with:
- `@Reducer` macro for feature modules
- `@ObservableState` for reactive state
- `@Dependency` system for testable side effects
- Pure domain logic with dependency injection

### Features

```
AppFeature (Root)
├── OnboardingFeature (First-run setup)
├── TodayFeature (Home: what matters now)
├── TimelineFeature (Phase-based view)
├── HabitsFeature (Manage habits)
└── SettingsFeature (Configuration)
```

### Domain Layer

**Core Models:**
- `Habit`, `Goal`, `Routine`, `Rule`
- `CompletionEvent`, `Reminder`, `DailyLog`
- `Phase`, `DayPhases`, `UserSettings`

**Rule Engine:**
- `RuleTrigger`: When to evaluate
- `RuleCondition`: What must be true
- `RuleAction`: What to do
- `DayContext`: Pure evaluation context
- `SchedulingDecision`: Output intents

### Persistence

**SwiftData Models:**
- All domain models have corresponding `@Model` classes
- Data blobs for complex codable types (rules, conditions, actions)
- Mapping layer between domain ↔ persistence

**SwiftDataClient:**
- TCA dependency for all persistence operations
- Async/await API
- Test-friendly with `.testValue`

### Services (TCA Dependencies)

1. **DayService**: 2am boundary logic for date keys
2. **PhaseService**: Sunrise/sunset → phase intervals
3. **NotificationClient**: UNUserNotificationCenter wrapper
4. **LocationClient**: CoreLocation wrapper
5. **QuoteClient**: Daily motivational quotes

## 📊 Data Flow

```
User Action
    ↓
TCA Reducer
    ↓
Effect (async)
    ↓
Client/Service → SwiftData / System API
    ↓
Effect Result
    ↓
State Update
    ↓
View Re-render
```

## 🎯 Key Features

### 2am Day Boundary

Activities before 2am belong to the previous day. Implemented in `DayService`:

```swift
// 1:30 AM on Jan 5 → "2025-01-04"
// 2:00 AM on Jan 5 → "2025-01-05"
```

### Phase Computation

**Auto Solar Mode:**
- Fetches sunrise/sunset from location
- Morning: sunrise → noon
- Afternoon: noon → sunset
- Evening: sunset → sunset+2h
- Night: evening end → next reset

**Manual Mode:**
- Fixed times (default or user-overridden)
- Morning: 6:00-12:00
- Afternoon: 12:00-18:00
- Evening: 18:00-22:00
- Night: 22:00-6:00

### Rule Engine

**Pure functional evaluation:**

```swift
let engine = RuleEngine()
let decisions = engine.evaluate(rules: rules, context: context, event: .phaseChange(...))
```

**Example rule (Supplements after Meal):**

```swift
Rule(
    trigger: .absoluteTime(hour: 21, minute: 0),
    conditions: [.completedWithinLast(habitId: mealId, minutes: 120)],
    actions: [.notify(templateId: "supplements", habitId: supplementsId, priority: 2)]
)
```

**Throttling:**
- Daily notification cap (default: 8)
- Cooldown between notifications (default: 45 min)
- Priority-based scheduling

### Cascading Dependencies

Rules can chain:
1. User completes "Meal" habit
2. Trigger: `onCompletion(mealId)`
3. Action: Schedule "Supplements" reminder 30 min later
4. Expiration: End of evening phase

### Salvage Plans

When habits expire without completion:
- Generate gentle rebalancing suggestion
- No shame language ("let's adjust" vs "you failed")
- Offer alternative time windows

## 🧪 Testing

**Unit Tests:**
- `DayServiceTests`: 2am boundary edge cases
- `RuleEngineTests`: Condition evaluation, cascading, throttling

**TCA TestStore:**
```swift
let store = TestStore(initialState: TodayFeature.State()) {
    TodayFeature()
}

await store.send(.refresh)
await store.receive(.dataLoaded(...))
```

## 📦 Project Structure

```
HabitTracker/
├── App/
│   ├── HabitTrackerApp.swift (Entry point)
│   └── Info.plist (Permissions, config)
├── Features/
│   ├── App/AppFeature.swift (Root coordinator)
│   ├── Onboarding/OnboardingFeature.swift
│   ├── Today/TodayFeature.swift
│   ├── Timeline/TimelineFeature.swift
│   ├── Habits/HabitsFeature.swift
│   └── Settings/SettingsFeature.swift
├── Domain/
│   ├── Models/ (Pure Swift types)
│   ├── RuleEngine/ (Pure evaluation logic)
│   └── Templates/ (Built-in routines)
├── Persistence/
│   ├── SwiftDataModels.swift (@Model classes)
│   └── SwiftDataClient.swift (TCA dependency)
├── Clients/
│   ├── DayServiceClient.swift
│   ├── PhaseServiceClient.swift
│   ├── NotificationClient.swift
│   ├── LocationClient.swift
│   └── QuoteClient.swift
└── Tests/
    ├── DayServiceTests.swift
    └── RuleEngineTests.swift
```

## 🚀 Getting Started

### Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

### Dependencies

- [swift-composable-architecture](https://github.com/pointfreeco/swift-composable-architecture) 1.15.0+

### Build

1. Clone the repository
2. Open `Package.swift` or create an Xcode project
3. Build and run on simulator or device

### First Run

1. **Onboarding:**
   - Grant notification permission (required)
   - Grant location permission (optional, for sunrise/sunset)
   - Choose a template routine or start blank

2. **Set up habits:**
   - Use a template (Meals+Supplements, Morning Routine, etc.)
   - Or create custom habits

3. **Configure phases:**
   - Auto solar mode (uses location)
   - Manual mode (fixed times)

## 🎨 Design Principles

### Zen Coach Tone

- **Gentle nudges**, not aggressive alerts
- **"Let's rebalance"** instead of "You failed"
- **Progress over perfection**
- Daily motivational quotes

### Privacy First

- All data stays on device
- No accounts, no analytics
- Location only for sunrise/sunset (never uploaded)
- SwiftData in app container

### MVP Scope

**Included:**
- Local notifications with actions (Done/Snooze/Skip)
- Phase-based time windows
- Rule engine for conditionals
- Cascading reminders
- Salvage plans
- Late correction
- Templates

**Deferred (Post-MVP):**
- Apple Health integration
- Widgets, Apple Watch
- Advanced analytics
- Data export
- Multi-device sync

## 🔧 Configuration

### User Settings

- **Reset time**: Default 2:00 AM (configurable)
- **Notification cap**: Default 8/day (1-20)
- **Cooldown**: Default 45 min (15-120)
- **Phase mode**: Auto solar or manual
- **Manual overrides**: Per-phase start/end times

### Templates

Four built-in templates:
1. **Meals + Supplements**: Track meals, conditional supplement reminders
2. **Morning Routine**: Meditation, journaling, hydration
3. **Evening Wind Down**: Hygiene, reflection, sleep prep
4. **Exercise & Movement**: Stretch, workout, walk

## 📝 Example Workflows

### Conditional Supplement Reminder

```
User sets up "Meals + Supplements" template

Evening phase starts (6pm)
├── 6:00 PM: Dinner reminder fires
├── User logs dinner at 6:30 PM
├── 9:00 PM: Rule evaluates
│   ├── Trigger: absoluteTime(21:00)
│   ├── Condition: completedWithinLast(dinner, 120) ✓
│   └── Action: notify("supplements")
└── User gets supplement reminder
```

### Day Boundary

```
User completes habit at 1:30 AM on Jan 5
├── DayService.dateKey(1:30 AM, Jan 5) → "2025-01-04"
├── Habit logged to Jan 4's dateKey
└── At 2:00 AM, new day begins (Jan 5)
```

## 📚 Key Files Reference

- **Rule Engine**: `HabitTracker/Domain/RuleEngine/RuleEngine.swift`
- **Day Service**: `HabitTracker/Clients/DayServiceClient.swift`
- **Phase Service**: `HabitTracker/Clients/PhaseServiceClient.swift`
- **SwiftData Client**: `HabitTracker/Persistence/SwiftDataClient.swift`
- **Templates**: `HabitTracker/Domain/Templates/RoutineTemplates.swift`
- **Tests**: `HabitTracker/Tests/`

## 🧩 Extension Points

To add new features:

1. **New habit category**: Add to `HabitCategory` enum
2. **New rule trigger**: Add case to `RuleTrigger`
3. **New rule condition**: Add case to `RuleCondition`
4. **New rule action**: Add case to `RuleAction`
5. **New template**: Extend `RoutineTemplate.all`
6. **New TCA feature**: Create `@Reducer` struct, add to `AppFeature`

## 🐛 Known Limitations

- Manual sleep/wake times (no automatic detection)
- Basic NL parsing (keyword-based, not LLM)
- Single timezone (device local time)
- No background app refresh for proactive scheduling
- Performance optimized for ~1000 habits max

## 📄 License

See ASSUMPTIONS.md for detailed technical decisions and constraints.

---

Built with ❤️ using SwiftUI, SwiftData, and TCA
