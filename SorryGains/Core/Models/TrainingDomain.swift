import Foundation

/// トレーニングのドメイン（消費側のプロンプト分岐で使う抽象）。
/// 1 セッションが複数ドメインを跨ぐこともあるため Set で扱う。
///
/// 仕様: Projects/Muscle360/2026-05-18-types-and-rpc-spec.md §2.3
enum TrainingDomain: String, Codable, Sendable, CaseIterable {
    /// 重量×レップ系（Liftly の中心、Forge の strength セッション）
    case strength
    /// CrossFit WOD（Forge の crossfit_wod / benchmark）
    case crossfit
    /// Hyrox（Forge の hyrox_* 系）
    case hyrox
    /// ラン / 有酸素（Forge の run、Liftly の cardio body_part）
    case cardio
    /// 上記の混合
    case mixed
}
