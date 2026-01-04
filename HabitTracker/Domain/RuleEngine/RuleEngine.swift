import Foundation

// MARK: - Rule Engine

/// Pure functional rule engine - evaluates rules and produces scheduling decisions
public struct RuleEngine {
    public init() {}

    // MARK: - Main Evaluation

    /// Evaluate all rules for a given context and event
    public func evaluate(
        rules: [Rule],
        context: DayContext,
        event: TriggerEvent?
    ) -> [SchedulingDecision] {
        var decisions: [SchedulingDecision] = []

        for rule in rules {
            guard rule.shouldEvaluate(at: context.currentDate, context: context, event: event) else {
                continue
            }

            // Check conditions
            if evaluateConditions(rule.conditions, context: context) {
                // Execute actions
                let actionDecisions = executeActions(
                    rule.actions,
                    ruleId: rule.id,
                    context: context
                )
                decisions.append(contentsOf: actionDecisions)
            }
        }

        // Apply throttling
        return applyThrottling(decisions: decisions, context: context)
    }

    // MARK: - Condition Evaluation

    private func evaluateConditions(_ conditions: [RuleCondition], context: DayContext) -> Bool {
        // Empty conditions = always pass
        guard !conditions.isEmpty else { return true }

        // All conditions must pass (implicit AND)
        return conditions.allSatisfy { evaluateCondition($0, context: context) }
    }

    private func evaluateCondition(_ condition: RuleCondition, context: DayContext) -> Bool {
        switch condition {
        case .completedWithinLast(let habitId, let minutes):
            return context.isCompletedWithinLast(habitId: habitId, minutes: minutes)

        case .completedToday(let habitId):
            return context.isCompleted(habitId)

        case .notCompletedToday(let habitId):
            return !context.isCompleted(habitId)

        case .completedInPhaseWindow(let habitId, let phase):
            return context.isCompletedInPhase(habitId: habitId, phase: phase)

        case .countCompletedToday(let habitId, let atLeast):
            return context.completionCount(for: habitId) >= atLeast

        case .sleepWakeKnown:
            // For MVP, always return false (not implemented)
            return false

        case .returnHookExists:
            return !context.pendingReturnHooks().isEmpty

        case .withinPhase(let phase):
            return context.currentPhase() == phase

        case .all(let subconditions):
            return subconditions.allSatisfy { evaluateCondition($0, context: context) }

        case .any(let subconditions):
            return subconditions.contains { evaluateCondition($0, context: context) }

        case .not(let subcondition):
            return !evaluateCondition(subcondition, context: context)
        }
    }

    // MARK: - Action Execution

    private func executeActions(
        _ actions: [RuleAction],
        ruleId: UUID,
        context: DayContext
    ) -> [SchedulingDecision] {
        var decisions: [SchedulingDecision] = []

        for action in actions {
            switch action {
            case .notify(let templateId, let habitId, let priority):
                // Schedule for immediate delivery
                let decision = SchedulingDecision.scheduleReminder(
                    id: UUID(),
                    habitId: habitId,
                    ruleId: ruleId,
                    fireDate: context.currentDate,
                    expirationDate: context.currentDate.addingTimeInterval(3600), // 1 hour default
                    templateId: templateId,
                    priority: priority
                )
                decisions.append(decision)

            case .scheduleNotifyAt(let date, let expiration, let templateId, let habitId, let priority):
                // Only schedule if not already past expiration
                if date < expiration && context.currentDate < expiration {
                    let decision = SchedulingDecision.scheduleReminder(
                        id: UUID(),
                        habitId: habitId,
                        ruleId: ruleId,
                        fireDate: date,
                        expirationDate: expiration,
                        templateId: templateId,
                        priority: priority
                    )
                    decisions.append(decision)
                }

            case .cancelNotifications(let tag):
                // Find reminders matching tag
                let remindersToCancel = findRemindersToCancel(tag: tag, context: context)
                for reminder in remindersToCancel {
                    decisions.append(.cancelReminder(reminderId: reminder.id))
                }

            case .createReturnHook(let prompt):
                decisions.append(.createReturnHook(prompt: prompt))

            case .triggerSalvage(let planId):
                // Generate salvage plan
                let plan = generateSalvagePlan(planId: planId, context: context)
                decisions.append(.createSalvagePlan(plan: plan))
            }
        }

        return decisions
    }

    // MARK: - Helper Methods

    private func findRemindersToCancel(tag: CancelTag, context: DayContext) -> [Reminder] {
        switch tag {
        case .byHabitId(let habitId):
            return context.existingReminders.filter { $0.habitId == habitId && $0.state == .scheduled }
        case .byRuleId(let ruleId):
            return context.existingReminders.filter { $0.ruleId == ruleId && $0.state == .scheduled }
        case .byDateKey(let dateKey):
            return context.existingReminders.filter { $0.dateKey == dateKey && $0.state == .scheduled }
        case .all:
            return context.existingReminders.filter { $0.state == .scheduled }
        }
    }

    private func generateSalvagePlan(planId: String, context: DayContext) -> SalvagePlan {
        // Simple salvage plan generation for MVP
        // In production, this would be more sophisticated
        return SalvagePlan(
            id: UUID(),
            dateKey: context.dateKey,
            createdAt: context.currentDate,
            title: "Let's rebalance your day",
            message: "Some items didn't fit into their usual time. Here's a gentle adjustment.",
            rebalancedItems: []
        )
    }

    // MARK: - Throttling

    private func applyThrottling(
        decisions: [SchedulingDecision],
        context: DayContext
    ) -> [SchedulingDecision] {
        // Filter only schedule decisions
        let scheduleDecisions = decisions.compactMap { decision -> (SchedulingDecision, Int, Date)? in
            if case .scheduleReminder(_, _, _, let fireDate, _, _, let priority) = decision {
                return (decision, priority, fireDate)
            }
            return nil
        }

        let otherDecisions = decisions.filter {
            if case .scheduleReminder = $0 { return false }
            return true
        }

        // Check daily cap
        let currentScheduledCount = context.scheduledReminderCount()
        let cap = context.settings.notificationCapPerDay
        let slotsAvailable = max(0, cap - currentScheduledCount)

        // Sort by priority (higher first), then by fire date (earlier first)
        let sorted = scheduleDecisions.sorted { lhs, rhs in
            if lhs.1 != rhs.1 {
                return lhs.1 > rhs.1 // Higher priority first
            }
            return lhs.2 < rhs.2 // Earlier time first
        }

        // Take top N decisions
        let throttled = sorted.prefix(slotsAvailable).map { $0.0 }

        // Apply cooldown check
        let withCooldown = applyCooldown(
            decisions: throttled,
            context: context
        )

        return withCooldown + otherDecisions
    }

    private func applyCooldown(
        decisions: [SchedulingDecision],
        context: DayContext
    ) -> [SchedulingDecision] {
        let cooldownMinutes = context.settings.notificationCooldownMinutes
        let cooldownInterval = TimeInterval(cooldownMinutes * 60)

        // Get most recent scheduled reminder
        let mostRecent = context.existingReminders
            .filter { $0.state == .scheduled }
            .max(by: { $0.fireDate < $1.fireDate })

        guard let lastFireDate = mostRecent?.fireDate else {
            return decisions // No cooldown needed
        }

        // Filter decisions that respect cooldown
        return decisions.filter { decision in
            if case .scheduleReminder(_, _, _, let fireDate, _, _, _) = decision {
                return fireDate.timeIntervalSince(lastFireDate) >= cooldownInterval
            }
            return true
        }
    }
}
