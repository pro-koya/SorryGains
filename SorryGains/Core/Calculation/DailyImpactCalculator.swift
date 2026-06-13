import Foundation

struct DailyImpactCalculator: Sendable {
    private var calculateImplementation: @Sendable (
        _ records: [DrinkRecord],
        _ profile: UserProfile,
        _ didTrainToday: Bool,
        _ trainingSnapshot: TrainingSnapshot?
    ) -> DailyImpactResult

    init(
        calculate: @escaping @Sendable (
            _ records: [DrinkRecord],
            _ profile: UserProfile,
            _ didTrainToday: Bool,
            _ trainingSnapshot: TrainingSnapshot?
        ) -> DailyImpactResult
    ) {
        self.calculateImplementation = calculate
    }

    func calculate(
        _ records: [DrinkRecord],
        _ profile: UserProfile,
        _ didTrainToday: Bool,
        _ trainingSnapshot: TrainingSnapshot? = nil
    ) -> DailyImpactResult {
        calculateImplementation(records, profile, didTrainToday, trainingSnapshot)
    }

    static let live = DailyImpactCalculator { records, profile, didTrainToday, trainingSnapshot in
        guard !records.isEmpty else {
            return .zero
        }

        let coefficients = LossCoefficients.daily

        let totalAlcoholGram = records.reduce(0.0) { sum, record in
            sum + record.volumeML * (record.alcoholPercent / 100) * 0.8
        }

        let weightFactor = coefficients.weightCompensation / max(profile.bodyWeightKG, 40)
        let effortFactor = 1 + Double(profile.trainingPerWeek) * coefficients.trainingCompensation

        var lossScore = min(
            100,
            totalAlcoholGram * coefficients.baseAlcoholMultiplier * weightFactor * effortFactor
        )

        // Liftly 連携時: 強度で補正
        if let snapshot = trainingSnapshot, snapshot.hasTraining {
            let intensityMultiplier = snapshot.intensityLevel?.penaltyMultiplier ?? 1.0
            lossScore = min(100, lossScore * intensityMultiplier)
        }

        let wastedPercent: Double
        if didTrainToday {
            wastedPercent = lossScore
        } else {
            wastedPercent = min(30, totalAlcoholGram * 0.3 * weightFactor)
        }

        let thresholds = coefficients.apologyThresholds
        let angerLevel = min(5, thresholds.filter { $0 <= lossScore }.count + 1)

        // 影響スコア (0〜100): lossScore を基にスケーリング。24h超の矛盾を解消。
        let impactScore = min(100, totalAlcoholGram * coefficients.impactScoreScale + lossScore * 0.3)

        let captionKey = "result.caption.lv\(angerLevel)"
        let characterStage = min(4, angerLevel - 1)

        return DailyImpactResult(
            totalPureAlcoholGram: totalAlcoholGram,
            wastedPercent: wastedPercent,
            angerLevel: angerLevel,
            impactScore: impactScore,
            captionKey: captionKey,
            characterStage: characterStage,
            didTrainToday: didTrainToday,
            drinkCount: records.count
        )
    }
}
