import Foundation
import SwiftData
import Testing
@testable import SorryGains

@Suite("Persistence Tests")
struct PersistenceTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([DrinkRecord.self, DailyTrainingStatus.self, UserProfile.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - DrinkRecord

    @Test("Insert and fetch drink record")
    func insertAndFetchDrinkRecord() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let record = DrinkRecord(
            drinkType: .beer,
            volumeML: 350,
            alcoholPercent: 5.0
        )
        context.insert(record)
        try context.save()

        let descriptor = FetchDescriptor<DrinkRecord>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched.first?.drinkType == .beer)
        #expect(fetched.first?.volumeML == 350)
        #expect(fetched.first?.alcoholPercent == 5.0)
    }

    @Test("Delete drink record")
    func deleteDrinkRecord() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let record = DrinkRecord(drinkType: .wine, volumeML: 125, alcoholPercent: 12.0)
        context.insert(record)
        try context.save()

        context.delete(record)
        try context.save()

        let descriptor = FetchDescriptor<DrinkRecord>()
        let remaining = try context.fetch(descriptor)
        #expect(remaining.isEmpty)
    }

    @Test("Multiple records sorted by timestamp descending")
    func multipleRecordsSorted() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let older = DrinkRecord(
            timestamp: Date(timeIntervalSinceNow: -3600),
            drinkType: .beer,
            volumeML: 350,
            alcoholPercent: 5.0
        )
        let newer = DrinkRecord(
            timestamp: Date(),
            drinkType: .sake,
            volumeML: 180,
            alcoholPercent: 15.0
        )
        context.insert(older)
        context.insert(newer)
        try context.save()

        let descriptor = FetchDescriptor<DrinkRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 2)
        #expect(fetched.first?.drinkType == .sake)
    }

    // MARK: - UserProfile

    @Test("Insert and fetch daily training status")
    func insertAndFetchDailyTrainingStatus() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let status = DailyTrainingStatus(date: .now, didTrain: true)
        context.insert(status)
        try context.save()

        let descriptor = FetchDescriptor<DailyTrainingStatus>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched.first?.didTrain == true)
    }

    @Test("Default profile values")
    func defaultProfileValues() {
        let profile = UserProfile()
        #expect(profile.bodyWeightKG == 65)
        #expect(profile.trainingPerWeek == 3)
        #expect(profile.goal == .maintain)
        #expect(profile.prefersLowMotion == false)
    }

    @Test("Insert and fetch user profile")
    func insertAndFetchProfile() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let profile = UserProfile(
            bodyWeightKG: 75,
            trainingPerWeek: 5,
            goal: .bulk
        )
        context.insert(profile)
        try context.save()

        let descriptor = FetchDescriptor<UserProfile>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched.first?.bodyWeightKG == 75)
        #expect(fetched.first?.trainingPerWeek == 5)
        #expect(fetched.first?.goal == .bulk)
    }
}
