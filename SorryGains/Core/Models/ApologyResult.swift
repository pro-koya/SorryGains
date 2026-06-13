import Foundation

struct ApologyResult: Equatable, Sendable {
    let pureAlcoholGram: Double

    /// 筋トレした日: トレ成果の何%が無駄になったか (0〜100)
    /// 筋トレしてない日: 筋肉が何%ダウンしたか (0〜100, 小さめの値)
    let wastedPercent: Double

    /// 筋肉怒り度 1〜5
    let angerLevel: Int

    /// 1杯分の影響スコア (0〜100)
    let impactScore: Double

    /// キャプション表示用キー
    let captionKey: String

    /// Rive キャラのしぼみ段階 0〜4
    let characterStage: Int

    /// 今日筋トレしたかどうか
    let didTrainToday: Bool
}
