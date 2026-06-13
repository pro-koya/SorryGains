import Foundation

/// Compiles weekly statistics from drink records and recovery logs.
///
/// Produces a `WeeklyReport` with per-day breakdowns, pattern analysis,
/// and aggregate metrics for display in the weekly report view.
enum WeeklyReportBuilder {

    static func build(
        records: [DrinkRecord],
        recoveryLogs: [DailyRecoveryLog],
        trainingStatuses: [DailyTrainingStatus]
    ) -> WeeklyReport {
        let calendar = Calendar.current
        let todayStart = DayBoundary.startOfToday(calendar: calendar)
        let weekStart = DayBoundary.startOfThisWeek(calendar: calendar)

        // Build per-day data for the last 4 weeks (28 days)
        let fourWeeksAgo = calendar.date(byAdding: .day, value: -27, to: todayStart) ?? todayStart
        var dailyData: [DayData] = []

        var currentDay = fourWeeksAgo
        while currentDay <= todayStart {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) ?? currentDay
            let dayRecords = records.filter {
                $0.timestamp >= currentDay && $0.timestamp < nextDay
            }
            let dayRecovery = recoveryLogs.first { log in
                DayBoundary.startOfDay(containing: log.date, calendar: calendar) == currentDay
            }
            let didTrain = trainingStatuses.contains { status in
                DayBoundary.startOfDay(containing: status.date, calendar: calendar) == currentDay
                    && status.didTrain
            }

            let totalAlcohol = dayRecords.reduce(0.0) { total, record in
                total + record.volumeML * (record.alcoholPercent / 100) * 0.8
            }

            dailyData.append(DayData(
                date: currentDay,
                drinkCount: dayRecords.count,
                totalAlcoholGram: totalAlcohol,
                didTrain: didTrain,
                recoveryCount: dayRecovery?.completedActionRawValues.count ?? 0
            ))

            currentDay = nextDay
        }

        // This week's data
        let thisWeekData = dailyData.filter { $0.date >= weekStart }
        let drinkingDays = thisWeekData.filter { $0.drinkCount > 0 }.count
        let trainingDays = thisWeekData.filter { $0.didTrain }.count
        let totalDrinks = thisWeekData.reduce(0) { $0 + $1.drinkCount }
        let totalAlcohol = thisWeekData.reduce(0.0) { $0 + $1.totalAlcoholGram }
        let recoveryRate = calculateRecoveryRate(thisWeekData)

        // Pattern analysis
        let patterns = analyzePatterns(dailyData, calendar: calendar)

        // Worst day
        let worstDay = thisWeekData.max(by: { $0.totalAlcoholGram < $1.totalAlcoholGram })

        // Sage comment
        let sageComment = generateSageComment(
            drinkingDays: drinkingDays,
            trainingDays: trainingDays,
            patterns: patterns
        )

        return WeeklyReport(
            dailyData: dailyData,
            drinkingDays: drinkingDays,
            trainingDays: trainingDays,
            totalDrinks: totalDrinks,
            totalAlcoholGram: totalAlcohol,
            recoveryRate: recoveryRate,
            worstDay: worstDay,
            patterns: patterns,
            sageComment: sageComment
        )
    }

    // MARK: - Recovery Rate

    private static func calculateRecoveryRate(_ data: [DayData]) -> Double {
        let drinkingDays = data.filter { $0.drinkCount > 0 }
        guard !drinkingDays.isEmpty else { return 1.0 }
        let recoveredDays = drinkingDays.filter { $0.recoveryCount > 0 }.count
        return Double(recoveredDays) / Double(drinkingDays.count)
    }

    // MARK: - Pattern Analysis

    private static func analyzePatterns(
        _ data: [DayData],
        calendar: Calendar
    ) -> [DrinkingPattern] {
        var patterns: [DrinkingPattern] = []

        // Weekday pattern: which day of week has most drinking?
        var weekdayTotals: [Int: Double] = [:]
        for day in data {
            let weekday = calendar.component(.weekday, from: day.date)
            weekdayTotals[weekday, default: 0] += day.totalAlcoholGram
        }

        if let (worstWeekday, amount) = weekdayTotals.max(by: { $0.value < $1.value }),
           amount > 0 {
            let dayName = calendar.weekdaySymbols[worstWeekday - 1]
            patterns.append(DrinkingPattern(
                type: .heaviestDay,
                description: String(format: String(localized: "report.pattern.heaviestDay"), dayName),
                weekday: worstWeekday
            ))
        }

        // Consecutive drinking detection
        var maxConsecutive = 0
        var currentStreak = 0
        for day in data.sorted(by: { $0.date < $1.date }) {
            if day.drinkCount > 0 {
                currentStreak += 1
                maxConsecutive = max(maxConsecutive, currentStreak)
            } else {
                currentStreak = 0
            }
        }
        if maxConsecutive >= 3 {
            patterns.append(DrinkingPattern(
                type: .consecutiveStreak,
                description: String(format: String(localized: "report.pattern.consecutiveStreak"), maxConsecutive),
                weekday: nil
            ))
        }

        // Training-drinking correlation
        let trainAndDrinkDays = data.filter { $0.didTrain && $0.drinkCount > 0 }.count
        let totalTrainDays = data.filter { $0.didTrain }.count
        if totalTrainDays >= 3 && Double(trainAndDrinkDays) / Double(totalTrainDays) > 0.5 {
            patterns.append(DrinkingPattern(
                type: .trainThenDrink,
                description: String(localized: "report.pattern.trainThenDrink"),
                weekday: nil
            ))
        }

        return patterns
    }

    // MARK: - Sage Comment

    private static func generateSageComment(
        drinkingDays: Int,
        trainingDays: Int,
        patterns: [DrinkingPattern]
    ) -> String {
        // Pattern-based comment
        if let heaviestDay = patterns.first(where: { $0.type == .heaviestDay }) {
            let dayName: String
            if let weekday = heaviestDay.weekday {
                dayName = Calendar.current.weekdaySymbols[weekday - 1]
            } else {
                dayName = String(localized: "report.weekday.specific")
            }
            return String(format: String(localized: "report.sage.heaviestDay"), dayName)
        }

        if drinkingDays == 0 {
            return String(localized: "report.sage.zeroDrinks")
        }

        if drinkingDays <= 2 && trainingDays >= 3 {
            return String(localized: "report.sage.goodBalance")
        }

        if drinkingDays >= 5 {
            return String(localized: "report.sage.tooMany")
        }

        if trainingDays == 0 {
            return String(localized: "report.sage.noTraining")
        }

        return String(localized: "report.sage.soso")
    }
}

// MARK: - Data Types

struct WeeklyReport: Sendable {
    let dailyData: [DayData]
    let drinkingDays: Int
    let trainingDays: Int
    let totalDrinks: Int
    let totalAlcoholGram: Double
    let recoveryRate: Double
    let worstDay: DayData?
    let patterns: [DrinkingPattern]
    let sageComment: String
}

struct DayData: Sendable, Identifiable {
    let date: Date
    let drinkCount: Int
    let totalAlcoholGram: Double
    let didTrain: Bool
    let recoveryCount: Int

    var id: Date { date }

    /// Intensity level 0-4 for heatmap coloring
    var intensityLevel: Int {
        switch totalAlcoholGram {
        case 0: return 0
        case ..<20: return 1
        case ..<40: return 2
        case ..<60: return 3
        default: return 4
        }
    }
}

struct DrinkingPattern: Sendable, Identifiable {
    let type: PatternType
    let description: String
    let weekday: Int?

    var id: String { type.rawValue }

    enum PatternType: String, Sendable {
        case heaviestDay
        case consecutiveStreak
        case trainThenDrink
    }
}
