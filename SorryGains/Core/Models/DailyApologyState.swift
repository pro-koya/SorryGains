import Foundation
import SwiftData

@Model
final class DailyApologyState {
    var date: Date
    var apologyCount: Int
    var savedHours: Double
    var currentAngerLevel: Int?

    init(
        date: Date = Calendar.current.startOfDay(for: .now),
        apologyCount: Int = 0,
        savedHours: Double = 0,
        currentAngerLevel: Int? = nil
    ) {
        self.date = date
        self.apologyCount = apologyCount
        self.savedHours = savedHours
        self.currentAngerLevel = currentAngerLevel
    }
}
