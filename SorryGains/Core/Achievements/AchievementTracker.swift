import Foundation
import SwiftData

/// Checks achievement conditions against current data and manages unlock state.
///
/// Unlock state is persisted in UserDefaults. The tracker is designed to be
/// called periodically (e.g., after recording drinks or completing recovery).
@MainActor
final class AchievementTracker: ObservableObject {

    @Published private(set) var unlockedAchievements: Set<Achievement> = []
    @Published var newlyUnlocked: Achievement?

    private let storageKey = "unlockedAchievements"

    init() {
        loadUnlocked()
    }

    // MARK: - Check All

    /// Checks all achievements against current data. Call after significant events.
    func checkAll(context: ModelContext) {
        let records = fetchAllRecords(context: context)
        let recoveryLogs = fetchAllRecoveryLogs(context: context)
        let sessions = fetchAllSessions(context: context)

        for achievement in Achievement.allCases {
            guard !unlockedAchievements.contains(achievement) else { continue }

            if isConditionMet(achievement, records: records, recoveryLogs: recoveryLogs, sessions: sessions) {
                unlock(achievement)
            }
        }
    }

    // MARK: - Condition Checks

    private func isConditionMet(
        _ achievement: Achievement,
        records: [DrinkRecord],
        recoveryLogs: [DailyRecoveryLog],
        sessions: [DrinkingSession]
    ) -> Bool {
        let calendar = Calendar.current

        switch achievement {
        case .steelWill:
            return consecutiveSoberDays(records: records, calendar: calendar) >= 7

        case .ironResolve:
            return consecutiveSoberDays(records: records, calendar: calendar) >= 14

        case .soberWeek:
            return checkSoberWeek(records: records, calendar: calendar)

        case .proteinMaster:
            let proteinCount = recoveryLogs.reduce(0) { total, log in
                total + (log.hasCompleted(.protein) ? 1 : 0)
            }
            return proteinCount >= 10

        case .recoveryPro:
            return checkConsecutiveFullRecovery(recoveryLogs: recoveryLogs, records: records, calendar: calendar)

        case .firstRecovery:
            return !recoveryLogs.isEmpty && recoveryLogs.contains { !$0.completedActionRawValues.isEmpty }

        case .muscleFriend:
            return checkLowAngerStreak(records: records, calendar: calendar)

        case .forgivenTenTimes:
            let forgivenCount = recoveryLogs.filter { $0.angerReduction >= 1 }.count
            return forgivenCount >= 10

        case .nightOfCarnage:
            return checkHighImpactDay(records: records, calendar: calendar)

        case .fiveDrinkNight:
            return checkFiveDrinkDay(records: records, calendar: calendar)

        case .sageDisciple:
            let viewCount = UserDefaults.standard.integer(forKey: "sageAdviceViewCount")
            return viewCount >= 10

        case .firstSession:
            return !sessions.isEmpty

        case .centuryDrinker:
            return records.count >= 100
        }
    }

    // MARK: - Specific Checks

    private func consecutiveSoberDays(records: [DrinkRecord], calendar: Calendar) -> Int {
        let drinkingDays = Set(
            records.map { DayBoundary.startOfDay(containing: $0.timestamp, calendar: calendar) }
        )

        var count = 0
        var checkDate = DayBoundary.startOfToday(calendar: calendar)

        // Go back from today, counting consecutive days WITHOUT drinking
        while !drinkingDays.contains(checkDate) {
            count += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay

            // Safety limit
            if count > 365 { break }
        }

        return count
    }

    private func checkSoberWeek(records: [DrinkRecord], calendar: Calendar) -> Bool {
        let weekStart = DayBoundary.startOfThisWeek(calendar: calendar)
        let todayStart = DayBoundary.startOfToday(calendar: calendar)
        let weekEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart

        let weekRecords = records.filter {
            $0.timestamp >= weekStart && $0.timestamp < weekEnd
        }
        return weekRecords.isEmpty
    }

    private func checkConsecutiveFullRecovery(
        recoveryLogs: [DailyRecoveryLog],
        records: [DrinkRecord],
        calendar: Calendar
    ) -> Bool {
        let totalActionCount = RecoveryActionType.allCases.count
        let sortedLogs = recoveryLogs.sorted { $0.date < $1.date }

        var consecutive = 0
        for log in sortedLogs {
            if log.completedActionRawValues.count == totalActionCount {
                consecutive += 1
                if consecutive >= 5 { return true }
            } else {
                consecutive = 0
            }
        }
        return false
    }

    private func checkLowAngerStreak(records: [DrinkRecord], calendar: Calendar) -> Bool {
        // Check if the last 7 days all had anger level <= 1
        let todayStart = DayBoundary.startOfToday(calendar: calendar)

        for dayOffset in 0..<7 {
            guard let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: todayStart) else {
                return false
            }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let dayRecords = records.filter {
                $0.timestamp >= dayStart && $0.timestamp < nextDay
            }

            // If there are drinks, check anger level
            if !dayRecords.isEmpty {
                let maxAnger = dayRecords.compactMap(\.currentAngerLevel).max() ?? 0
                if maxAnger > 1 { return false }
            }
        }
        return true
    }

    private func checkHighImpactDay(records: [DrinkRecord], calendar: Calendar) -> Bool {
        let grouped = Dictionary(grouping: records) { record in
            DayBoundary.startOfDay(containing: record.timestamp, calendar: calendar)
        }

        let calculator = DailyImpactCalculator.live
        let profile = UserProfile()

        for (_, dayRecords) in grouped {
            let result = calculator.calculate(dayRecords, profile, false, nil)
            if result.impactScore >= 90 { return true }
        }
        return false
    }

    private func checkFiveDrinkDay(records: [DrinkRecord], calendar: Calendar) -> Bool {
        let grouped = Dictionary(grouping: records) { record in
            DayBoundary.startOfDay(containing: record.timestamp, calendar: calendar)
        }
        return grouped.values.contains { $0.count >= 5 }
    }

    // MARK: - Persistence

    private func loadUnlocked() {
        let stored = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        unlockedAchievements = Set(stored.compactMap { Achievement(rawValue: $0) })
    }

    private func unlock(_ achievement: Achievement) {
        unlockedAchievements.insert(achievement)
        newlyUnlocked = achievement

        let stored = unlockedAchievements.map(\.rawValue)
        UserDefaults.standard.set(stored, forKey: storageKey)
    }

    // MARK: - Data Fetching

    private func fetchAllRecords(context: ModelContext) -> [DrinkRecord] {
        let descriptor = FetchDescriptor<DrinkRecord>(sortBy: [SortDescriptor(\.timestamp)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchAllRecoveryLogs(context: ModelContext) -> [DailyRecoveryLog] {
        let descriptor = FetchDescriptor<DailyRecoveryLog>(sortBy: [SortDescriptor(\.date)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchAllSessions(context: ModelContext) -> [DrinkingSession] {
        let descriptor = FetchDescriptor<DrinkingSession>(sortBy: [SortDescriptor(\.startedAt)])
        return (try? context.fetch(descriptor)) ?? []
    }
}

// MARK: - Increment Sage View Count

extension AchievementTracker {
    /// Call this when the user views sage advice to track the sageDisciple achievement.
    static func incrementSageViewCount() {
        let key = "sageAdviceViewCount"
        let current = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(current + 1, forKey: key)
    }
}
