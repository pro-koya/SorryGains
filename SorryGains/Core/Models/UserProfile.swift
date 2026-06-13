import Foundation
import SwiftData

@Model
final class UserProfile {
    var bodyWeightKG: Double
    var trainingPerWeek: Int
    var goal: TrainingGoal
    var prefersLowMotion: Bool

    init(
        bodyWeightKG: Double = 65,
        trainingPerWeek: Int = 3,
        goal: TrainingGoal = .maintain,
        prefersLowMotion: Bool = false
    ) {
        self.bodyWeightKG = bodyWeightKG
        self.trainingPerWeek = trainingPerWeek
        self.goal = goal
        self.prefersLowMotion = prefersLowMotion
    }
}
