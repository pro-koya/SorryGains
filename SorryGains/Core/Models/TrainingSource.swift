import Foundation

/// Training データのソースアプリ識別子。
/// Muscle360 統合論理モデルの中心 enum。
///
/// 仕様: Projects/Muscle360/2026-05-18-types-and-rpc-spec.md §2.2
enum TrainingSource: String, Codable, Sendable, CaseIterable {
    case liftly
    case forge
}
