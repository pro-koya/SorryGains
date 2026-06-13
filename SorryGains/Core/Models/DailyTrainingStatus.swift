import Foundation
import SwiftData

@Model
final class DailyTrainingStatus {
    @Attribute(.unique) var date: Date
    var didTrain: Bool

    init(date: Date = .now, didTrain: Bool = false) {
        self.date = Calendar.current.startOfDay(for: date)
        self.didTrain = didTrain
    }
}
