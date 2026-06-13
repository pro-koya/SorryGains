import Foundation

/// 共通 Training 連携状態。
/// Liftly / Forge ともに同一 Supabase Auth (`auth.users`) を共有するため、
/// リンク状態は 3 アプリ横断で 1 本化できる。
///
/// 仕様: Projects/Muscle360/2026-05-18-types-and-rpc-spec.md §2.9
enum TrainingLinkStatus: Sendable, Equatable {
    /// 未連携（未ログイン）
    case notLinked
    /// 連携済み（ログイン済み、データ取得可能）
    case linked
    /// 連携エラー（ログイン済みだがデータ取得に失敗）
    case error(String)

    var isLinked: Bool {
        if case .linked = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .notLinked: String(localized: "liftly.status.notLinked")
        case .linked: String(localized: "liftly.status.linked")
        case .error: String(localized: "liftly.status.error")
        }
    }
}

// MARK: - 旧 API 互換性
//
// Phase 2 完了時に削除予定。
// 既存コードが `LiftlyLinkStatus.notLinked` 等を参照しているため、
// typealias で逃がす（破壊変更を避ける）。

/// 旧名。`TrainingLinkStatus` に renamed。
@available(*, deprecated, renamed: "TrainingLinkStatus")
typealias LiftlyLinkStatus = TrainingLinkStatus
