import Foundation
import Supabase

// MARK: - BundleEntitlementService (SorryGains)
//
// 起動時 + foreground 復帰時に SubscriptionManager.refreshBundleStatus() を呼び出す
// ライフサイクル管理サービス。
//
// 設計: Forge/BundleEntitlementService と同パターン。
// キャッシュ TTL: 60分。

@Observable
@MainActor
final class BundleEntitlementService {

    // MARK: - Constants

    private static let cacheTTL: TimeInterval = 60 * 60  // 1時間

    // MARK: - State

    private(set) var isRefreshing: Bool = false

    // MARK: - Private

    private let log = SorryGainsLogger(category: "BundleEntitlement")
    private var lastCheckedAt: Date?

    // MARK: - Public API

    /// バンドル加入状況を確認し、SubscriptionManager に反映する。
    func refresh(
        subscriptionManager: SubscriptionManager,
        forceRefresh: Bool = false
    ) async {
        // キャッシュ有効チェック
        if !forceRefresh, let last = lastCheckedAt,
           Date().timeIntervalSince(last) < Self.cacheTTL {
            return
        }

        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        await subscriptionManager.refreshBundleStatus()
        lastCheckedAt = Date()
    }

    /// キャッシュを破棄して次回 refresh 時に強制再取得させる。
    func invalidateCache() {
        lastCheckedAt = nil
    }
}
