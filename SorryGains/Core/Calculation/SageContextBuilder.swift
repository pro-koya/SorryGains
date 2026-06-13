import Foundation

/// DrinkRecord / DailyTrainingStatus / UserProfile / TrainingSnapshot から SageContext を組み立てるユーティリティ
enum SageContextBuilder {

    static func build(
        records: [DrinkRecord],
        trainingStatuses: [DailyTrainingStatus],
        profile: UserProfile,
        trainingSnapshot: TrainingSnapshot? = nil
    ) -> SageContext {
        let calendar = Calendar.current
        let todayStart = DayBoundary.startOfToday(calendar: calendar)

        let todayRecords = filterRecordsForDay(
            records: records,
            dayStart: todayStart,
            calendar: calendar
        )

        let todayTotalAlcoholGram = calculateTotalAlcoholGram(
            records: todayRecords
        )

        // Liftly 連携時はスナップショットのトレ状態を優先
        let todayDidTrain: Bool
        if let snapshot = trainingSnapshot {
            todayDidTrain = snapshot.hasTraining
        } else {
            todayDidTrain = checkDidTrain(
                statuses: trainingStatuses,
                dayStart: todayStart,
                calendar: calendar
            )
        }

        let weekStart = DayBoundary.startOfThisWeek(calendar: calendar)

        let weekDrinkCount = countDrinkingDays(
            records: records,
            from: weekStart,
            to: todayStart,
            calendar: calendar
        )

        let localWeekTrainingDays = countTrainingDays(
            statuses: trainingStatuses,
            from: weekStart,
            to: todayStart,
            calendar: calendar
        )

        // Liftly 連携: スナップショットで今日トレーニング済みだが
        // ローカル DailyTrainingStatus に記録がない場合を補正
        let todayLocallyTracked = trainingStatuses.contains { status in
            DayBoundary.startOfDay(containing: status.date, calendar: calendar) == todayStart && status.didTrain
        }
        let weekTrainingDays = todayDidTrain && !todayLocallyTracked
            ? localWeekTrainingDays + 1
            : localWeekTrainingDays

        let consecutiveDrinkingDays = calculateConsecutiveDrinkingDays(
            records: records,
            from: todayStart,
            calendar: calendar
        )

        let latestAngerLevel = findLatestAngerLevel(records: todayRecords)

        return SageContext(
            todayDrinkCount: todayRecords.count,
            todayTotalAlcoholGram: todayTotalAlcoholGram,
            todayDidTrain: todayDidTrain,
            weekDrinkCount: weekDrinkCount,
            weekTrainingDays: weekTrainingDays,
            consecutiveDrinkingDays: consecutiveDrinkingDays,
            trainingGoal: profile.goal,
            latestAngerLevel: latestAngerLevel,
            trainingSnapshot: trainingSnapshot
        )
    }
}

// MARK: - Pure Helper Functions

private extension SageContextBuilder {

    static func filterRecordsForDay(
        records: [DrinkRecord],
        dayStart: Date,
        calendar: Calendar
    ) -> [DrinkRecord] {
        let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        return records.filter { $0.timestamp >= dayStart && $0.timestamp < nextDayStart }
    }

    static func calculateTotalAlcoholGram(
        records: [DrinkRecord]
    ) -> Double {
        let alcoholDensity = 0.8
        return records.reduce(0.0) { total, record in
            let pureAlcohol = record.volumeML * (record.alcoholPercent / 100.0)
            return total + pureAlcohol * alcoholDensity
        }
    }

    static func checkDidTrain(
        statuses: [DailyTrainingStatus],
        dayStart: Date,
        calendar: Calendar
    ) -> Bool {
        let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        return statuses.contains { status in
            status.date >= dayStart && status.date < nextDayStart && status.didTrain
        }
    }

    static func countDrinkingDays(
        records: [DrinkRecord],
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) -> Int {
        let rangeEnd = calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate
        let recordsInRange = records.filter { record in
            record.timestamp >= startDate && record.timestamp < rangeEnd
        }
        let uniqueDays = Set(
            recordsInRange.map { DayBoundary.startOfDay(containing: $0.timestamp, calendar: calendar) }
        )
        return uniqueDays.count
    }

    static func countTrainingDays(
        statuses: [DailyTrainingStatus],
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) -> Int {
        let rangeEnd = calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate
        let uniqueDays = Set(
            statuses
                .filter { $0.didTrain && $0.date >= startDate && $0.date < rangeEnd }
                .map { DayBoundary.startOfDay(containing: $0.date, calendar: calendar) }
        )
        return uniqueDays.count
    }

    /// 今日から過去に向かって連続飲酒日数を数える
    static func calculateConsecutiveDrinkingDays(
        records: [DrinkRecord],
        from todayStart: Date,
        calendar: Calendar
    ) -> Int {
        let drinkingDays = Set(
            records.map { DayBoundary.startOfDay(containing: $0.timestamp, calendar: calendar) }
        )

        var count = 0
        var checkDate = todayStart

        while drinkingDays.contains(checkDate) {
            count += 1
            guard let previousDay = calendar.date(
                byAdding: .day, value: -1, to: checkDate
            ) else {
                break
            }
            checkDate = previousDay
        }

        return count
    }

    static func findLatestAngerLevel(
        records: [DrinkRecord]
    ) -> Int? {
        records
            .sorted { $0.timestamp > $1.timestamp }
            .first
            .flatMap { $0.currentAngerLevel }
    }
}
