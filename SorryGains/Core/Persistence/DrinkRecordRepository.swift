import Foundation
import SwiftData

protocol DrinkRecordRepository {
    func fetchAll() throws -> [DrinkRecord]
    func fetchByDate(_ date: Date) throws -> [DrinkRecord]
    func save(_ record: DrinkRecord) throws
    func delete(_ record: DrinkRecord) throws
}

@ModelActor
actor SwiftDataDrinkRepository: @preconcurrency DrinkRecordRepository {

    func fetchAll() throws -> [DrinkRecord] {
        let descriptor = FetchDescriptor<DrinkRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchByDate(_ date: Date) throws -> [DrinkRecord] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = #Predicate<DrinkRecord> { record in
            record.timestamp >= startOfDay && record.timestamp < endOfDay
        }
        let descriptor = FetchDescriptor<DrinkRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func save(_ record: DrinkRecord) throws {
        modelContext.insert(record)
        try modelContext.save()
    }

    func delete(_ record: DrinkRecord) throws {
        modelContext.delete(record)
        try modelContext.save()
    }
}
