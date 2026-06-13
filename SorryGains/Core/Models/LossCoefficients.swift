import Foundation

struct LossCoefficients: Sendable {
    let baseAlcoholMultiplier: Double
    let weightCompensation: Double
    let trainingCompensation: Double
    let impactScoreScale: Double
    let apologyThresholds: [Double]

    static let `default` = LossCoefficients(
        baseAlcoholMultiplier: 2.2,
        weightCompensation: 70.0,
        trainingCompensation: 0.08,
        impactScoreScale: 1.5,
        apologyThresholds: [10, 25, 45, 70]
    )

    /// 日次集計用: per-drink より緩めの係数
    /// 目安(65kg/週3): ビール1杯→Lv1, 2杯→Lv2, 4杯→Lv4, 5杯→Lv5
    /// 体重・トレ頻度を問わず anger 4-5 に到達可能な閾値設定
    static let daily = LossCoefficients(
        baseAlcoholMultiplier: 1.0,
        weightCompensation: 70.0,
        trainingCompensation: 0.08,
        impactScoreScale: 1.5,
        apologyThresholds: [20, 40, 60, 80]
    )
}
