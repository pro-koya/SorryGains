import Foundation

struct DrinkTypeSummary: Identifiable {
    let drinkType: DrinkType
    let records: [DrinkRecord]

    var id: String { drinkType.rawValue }

    var count: Int {
        records.count
    }

    var totalVolumeML: Double {
        records.reduce(0) { $0 + $1.volumeML }
    }

    var latestRecord: DrinkRecord? {
        records.max { lhs, rhs in
            lhs.timestamp < rhs.timestamp
        }
    }
}

struct DrinkDaySummary: Identifiable {
    let date: Date
    let records: [DrinkRecord]
    let explicitTrainingStatus: Bool?

    var id: Date { date }

    var totalCount: Int {
        records.count
    }

    var didTrain: Bool {
        explicitTrainingStatus ?? records.contains { $0.didTrainToday }
    }

    var hasTrainingStatus: Bool {
        explicitTrainingStatus != nil || !records.isEmpty
    }

    var drinkSummaries: [DrinkTypeSummary] {
        let grouped = Dictionary(grouping: records) { $0.drinkType }

        return grouped
            .map { drinkType, groupedRecords in
                DrinkTypeSummary(
                    drinkType: drinkType,
                    records: groupedRecords.sorted { $0.timestamp > $1.timestamp }
                )
            }
            .sorted { lhs, rhs in
                let lhsDate = lhs.latestRecord?.timestamp ?? .distantPast
                let rhsDate = rhs.latestRecord?.timestamp ?? .distantPast
                return lhsDate > rhsDate
            }
    }
}

enum DrinkAnalytics {
    static func makeDaySummaries(
        records: [DrinkRecord],
        statuses: [DailyTrainingStatus],
        calendar: Calendar = .current
    ) -> [DrinkDaySummary] {
        let normalizedRecords = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.timestamp)
        }
        let normalizedStatuses = Dictionary(uniqueKeysWithValues: statuses.map { status in
            (calendar.startOfDay(for: status.date), status)
        })

        let allDates = Set(normalizedRecords.keys).union(normalizedStatuses.keys)

        return allDates
            .sorted(by: >)
            .map { date in
                DrinkDaySummary(
                    date: date,
                    records: (normalizedRecords[date] ?? []).sorted { $0.timestamp > $1.timestamp },
                    explicitTrainingStatus: normalizedStatuses[date]?.didTrain
                )
            }
    }

    static func makeDrinkTypeSummaries(from records: [DrinkRecord]) -> [DrinkTypeSummary] {
        makeDaySummaries(records: records, statuses: [])
            .first?
            .drinkSummaries ?? []
    }
}
