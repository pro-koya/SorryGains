import SwiftUI

enum RecoveryActionType: String, Codable, CaseIterable, Identifiable {
    case workout
    case protein
    case healthyMeal
    case stretching
    case hydration
    case sleep
    case walking

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .workout: String(localized: "recoveryAction.workout")
        case .protein: String(localized: "recoveryAction.protein")
        case .healthyMeal: String(localized: "recoveryAction.healthyMeal")
        case .stretching: String(localized: "recoveryAction.stretching")
        case .hydration: String(localized: "recoveryAction.hydration")
        case .sleep: String(localized: "recoveryAction.sleep")
        case .walking: String(localized: "recoveryAction.walking")
        }
    }

    var symbolName: String {
        switch self {
        case .workout: "dumbbell.fill"
        case .protein: "cup.and.saucer.fill"
        case .healthyMeal: "leaf.fill"
        case .stretching: "figure.yoga"
        case .hydration: "drop.fill"
        case .sleep: "bed.double.fill"
        case .walking: "figure.walk"
        }
    }

    /// 怒り度軽減ポイント（合計 / 3 = 怒り度 -1）
    var forgivenessPoints: Int {
        switch self {
        case .workout: 3
        case .protein: 2
        case .healthyMeal: 2
        case .stretching: 2
        case .hydration: 1
        case .sleep: 1
        case .walking: 1
        }
    }

    /// 影響スコアの軽減量（ポイント）
    var scoreReduction: Double {
        switch self {
        case .workout: 15
        case .protein: 10
        case .healthyMeal: 10
        case .stretching: 8
        case .hydration: 5
        case .sleep: 5
        case .walking: 5
        }
    }

    /// 筋肉キャラのリアクションセリフ（ステージに応じて変化）
    func reactionDialogue(for stage: Int) -> String {
        let suffix = stage >= 3 ? "harsh" : "calm"
        let key = "recoveryAction.reaction.\(rawValue).\(suffix)"
        return String(localized: String.LocalizationValue(key))
    }
}
