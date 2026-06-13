import Foundation

struct DailyImpactResult: Equatable, Sendable {
    /// 1日の純アルコール合計量 (g)
    let totalPureAlcoholGram: Double

    /// 筋トレした日: トレ成果の何%が無駄になったか (0〜100)
    /// 筋トレしてない日: 筋肉が何%ダウンしたか (0〜100, 小さめの値)
    let wastedPercent: Double

    /// 筋肉怒り度 1〜5 (0杯なら 0)
    let angerLevel: Int

    /// 今日の影響スコア (0〜100)。飲酒量・体重・トレ頻度から算出。
    /// 日次リセットと整合するよう上限100でキャップ。
    let impactScore: Double

    /// キャプション表示用キー
    let captionKey: String

    /// キャラのしぼみ段階 0〜4
    let characterStage: Int

    /// 今日筋トレしたかどうか
    let didTrainToday: Bool

    /// 今日の飲酒杯数
    let drinkCount: Int

    static let zero = DailyImpactResult(
        totalPureAlcoholGram: 0,
        wastedPercent: 0,
        angerLevel: 0,
        impactScore: 0,
        captionKey: "result.caption.lv0",
        characterStage: 0,
        didTrainToday: false,
        drinkCount: 0
    )
}
