import Foundation
import SwiftData

@Model
final class DrinkRecord {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var drinkType: DrinkType
    var volumeML: Double
    var alcoholPercent: Double
    var didTrainToday: Bool
    var note: String?

    // 謝罪記録（結果画面で謝った結果を永続化）
    var apologyCount: Int
    var savedHours: Double
    var currentAngerLevel: Int?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        drinkType: DrinkType,
        volumeML: Double,
        alcoholPercent: Double,
        didTrainToday: Bool = false,
        note: String? = nil,
        apologyCount: Int = 0,
        savedHours: Double = 0,
        currentAngerLevel: Int? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.drinkType = drinkType
        self.volumeML = volumeML
        self.alcoholPercent = alcoholPercent
        self.didTrainToday = didTrainToday
        self.note = note
        self.apologyCount = apologyCount
        self.savedHours = savedHours
        self.currentAngerLevel = currentAngerLevel
    }
}
