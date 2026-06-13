import Foundation

struct ApologyCalculator: Sendable {
    private var calculateImplementation: @Sendable (
        _ drink: DrinkRecord,
        _ profile: UserProfile,
        _ didTrainToday: Bool,
        _ trainingSnapshot: TrainingSnapshot?
    ) -> ApologyResult

    init(
        calculate: @escaping @Sendable (
            _ drink: DrinkRecord,
            _ profile: UserProfile,
            _ didTrainToday: Bool,
            _ trainingSnapshot: TrainingSnapshot?
        ) -> ApologyResult
    ) {
        self.calculateImplementation = calculate
    }

    func calculate(
        _ drink: DrinkRecord,
        _ profile: UserProfile,
        _ didTrainToday: Bool,
        _ trainingSnapshot: TrainingSnapshot? = nil
    ) -> ApologyResult {
        calculateImplementation(drink, profile, didTrainToday, trainingSnapshot)
    }

    static let live = ApologyCalculator { drink, profile, didTrainToday, trainingSnapshot in
        let coefficients = LossCoefficients.default
        let alcoholGram = drink.volumeML * (drink.alcoholPercent / 100) * 0.8

        let weightFactor = coefficients.weightCompensation / max(profile.bodyWeightKG, 40)
        let effortFactor = 1 + Double(profile.trainingPerWeek) * coefficients.trainingCompensation

        var lossScore = min(
            100,
            alcoholGram * coefficients.baseAlcoholMultiplier * weightFactor * effortFactor
        )

        // Liftly 連携時: 強度・ボリューム・トレ後経過時間で補正
        if let snapshot = trainingSnapshot, snapshot.hasTraining {
            let intensityMultiplier = snapshot.intensityLevel?.penaltyMultiplier ?? 1.0
            lossScore = min(100, lossScore * intensityMultiplier)

            // トレ後経過時間が短いほどペナルティ増加（ゴールデンタイムの2時間以内は1.3倍）
            if let hours = snapshot.hoursSinceTraining(at: drink.timestamp) {
                let timePenalty: Double = switch hours {
                case ..<1: 1.4
                case ..<2: 1.3
                case ..<4: 1.1
                default: 1.0
                }
                lossScore = min(100, lossScore * timePenalty)
            }
        }

        // 筋トレした日: トレ成果の何%が無駄に (lossScore をそのまま使う)
        // 筋トレしてない日: 筋肉が何%ダウン (小さめに抑える、飲んだだけのマイナス)
        let wastedPercent: Double
        if didTrainToday {
            wastedPercent = lossScore
        } else {
            wastedPercent = min(30, alcoholGram * 0.3 * weightFactor)
        }

        let thresholds = coefficients.apologyThresholds
        let angerLevel = min(5, thresholds.filter { $0 <= lossScore }.count + 1)

        // 影響スコア (0〜100): 1杯分の影響度。上限キャップで日次リセットと整合。
        let impactScore = min(100, alcoholGram * coefficients.impactScoreScale + lossScore * 0.3)

        let captionKey = "result.caption.lv\(angerLevel)"
        let characterStage = min(4, angerLevel - 1)

        return ApologyResult(
            pureAlcoholGram: alcoholGram,
            wastedPercent: wastedPercent,
            angerLevel: angerLevel,
            impactScore: impactScore,
            captionKey: captionKey,
            characterStage: characterStage,
            didTrainToday: didTrainToday
        )
    }
}
