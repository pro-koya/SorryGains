import Foundation

/// 助言のカテゴリ
enum SageAdviceCategory: String, Sendable, CaseIterable {
    case drankTooMuch        // 飲みすぎ
    case drankALittle        // 少し飲んだ
    case goodJob             // よく頑張った（トレーニング済み・飲んでない）
    case neutral             // 一般的な励まし
    case streak              // 連続飲酒
    // Liftly 連携時の追加カテゴリ
    case hardTrainHeavyDrink // 高強度トレ + 多量飲酒
    case hardTrainLightDrink // 高強度トレ + 軽い飲酒
    case lightTrainHeavyDrink // 軽いトレ + 多量飲酒
}

/// 助言のトーン
enum SageAdviceTone: String, Sendable {
    case stern       // 厳しめ
    case warm        // 温かい
    case firedUp     // 熱血
    case calm        // 落ち着き
}

/// 仙人の助言データ
struct SageAdvice: Equatable, Sendable {
    let category: SageAdviceCategory
    let tone: SageAdviceTone
    let message: String          // メインの助言テキスト
    let followUp: String?        // 追加の一言（オプション）
}
