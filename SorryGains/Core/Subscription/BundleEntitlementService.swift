import Foundation

/// 起動・復帰時に端末購入と本人の共有状態を再評価する。
@Observable
@MainActor
final class BundleEntitlementService {
    private var refreshCount = 0
    private var forceNextRefresh = false
    var isRefreshing: Bool { refreshCount > 0 }

    func refresh(subscriptionManager: SubscriptionManager, forceRefresh: Bool = false) async {
        subscriptionManager.accountDidChange()
        let force = forceRefresh || forceNextRefresh
        forceNextRefresh = false
        refreshCount += 1
        defer { refreshCount -= 1 }
        await subscriptionManager.refreshEntitlements()
        await subscriptionManager.refreshBundleStatus(forceRefresh: force)
    }

    func invalidateCache() {
        forceNextRefresh = true
    }
}
