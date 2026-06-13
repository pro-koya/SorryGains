import Foundation

/// Liftly RPC `get_training_summary` 由来のペイロード。
/// 既存 `TrainingSnapshot` のフィールドを再構成したサブセット。
///
/// 仕様: Projects/Muscle360/2026-05-18-types-and-rpc-spec.md §2.5
struct LiftlyTrainingPayload: Sendable, Equatable, Codable {
    let sessionCount: Int
    let trainedBodyParts: [String]
    let exerciseCount: Int
    let totalSets: Int
    let totalReps: Int
    let totalVolumeKG: Double
    let intensityLevel: IntensityLevel?
}
