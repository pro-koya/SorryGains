import SwiftUI

enum TrainingGoal: String, Codable, CaseIterable, Identifiable {
    case bulk
    case cut
    case maintain
    case casual

    var id: String { rawValue }

    var localizedName: String {
        Bundle.main.localizedString(
            forKey: "training_goal.\(rawValue)",
            value: rawValue,
            table: nil
        )
    }
}
