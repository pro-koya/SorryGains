import Foundation

/// 各ソース固有のペイロードを束ねる discriminated union。
///
/// 仕様: Projects/Muscle360/2026-05-18-types-and-rpc-spec.md §2.4
enum TrainingPayload: Sendable, Equatable {
    case liftly(LiftlyTrainingPayload)
    case forge(ForgeTrainingPayload)

    var source: TrainingSource {
        switch self {
        case .liftly: .liftly
        case .forge:  .forge
        }
    }
}
