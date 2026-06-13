import Foundation
import SwiftData

@Model
final class DailyRecoveryLog {
    var date: Date
    var completedActionRawValues: [String]

    init(
        date: Date = Calendar.current.startOfDay(for: .now),
        completedActionRawValues: [String] = []
    ) {
        self.date = date
        self.completedActionRawValues = completedActionRawValues
    }

    // MARK: - Convenience Accessors

    var completedActions: Set<RecoveryActionType> {
        Set(completedActionRawValues.compactMap { RecoveryActionType(rawValue: $0) })
    }

    func hasCompleted(_ action: RecoveryActionType) -> Bool {
        completedActionRawValues.contains(action.rawValue)
    }

    func addAction(_ action: RecoveryActionType) {
        guard !hasCompleted(action) else { return }
        completedActionRawValues.append(action.rawValue)
    }

    func removeAction(_ action: RecoveryActionType) {
        completedActionRawValues.removeAll { $0 == action.rawValue }
    }

    // MARK: - Aggregate Calculations

    var totalForgivenessPoints: Int {
        completedActions.reduce(0) { $0 + $1.forgivenessPoints }
    }

    var totalScoreReduction: Double {
        completedActions.reduce(0) { $0 + $1.scoreReduction }
    }

    var angerReduction: Int {
        totalForgivenessPoints / 3
    }
}
