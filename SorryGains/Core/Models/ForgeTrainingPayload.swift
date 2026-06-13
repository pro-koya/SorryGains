import Foundation

/// Forge RPC `get_forge_training_summary` 由来のペイロード。
///
/// 仕様: Projects/Muscle360/2026-05-18-types-and-rpc-spec.md §2.6
struct ForgeTrainingPayload: Sendable, Equatable, Codable {
    let sessionCount: Int
    /// `forge_sessions.session_type` の生値配列（"crossfit_wod", "hyrox_race", "strength" 等）
    let sessionTypes: [String]
    /// 全セッションの合計実行秒
    let totalDurationSeconds: Int
    /// 平均 RPE（1〜10）。RPE 入力なしのみのときは nil
    let averageRPE: Double?
    /// 当日に PR 達成セッションがあったか
    let isPRSession: Bool
    /// 当日叩いたベンチマーク識別子（"fran", "murph" 等）
    let benchmarkIDs: [String]
    /// RPC が返す low / medium / high（RPE と duration から導出）
    let intensityLevel: IntensityLevel?
    /// 種目集計
    let movementsSummary: [ForgeMovementCount]
}

/// Forge セッション内の種目集計エントリ。
struct ForgeMovementCount: Sendable, Equatable, Codable {
    /// `forge_movements.id` の生キー。表示時にローカライズする
    let movementName: String
    let totalReps: Int?
    let totalLoadKG: Double?
}
