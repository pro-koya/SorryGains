import Foundation
import StoreKit
import Supabase

// MARK: - SubscriptionManager (SorryGains)
//
// SorryGains は単独サブスクなし。バンドル限定 Pro 機能のみ。
// Supabase RPC `get_bundle_status` でバンドル加入を確認し、
// isBundleActive を公開する。
//
// 商品 ID（StoreKit エンタイトルメント確認用）:
//   com.muscle360.bundle.pro.monthly  - バンドル月額 ¥250
//   com.muscle360.bundle.pro.yearly   - バンドル年額 ¥2,500
//
// 参照:
//   - Forge/SubscriptionManager.swift（設計パターン共通）
//   - Supabase: bundle_status.sql

@Observable
@MainActor
final class SubscriptionManager {

    // MARK: - State

    /// バンドルが有効かどうか（Supabase + StoreKit の OR 判定）。
    private(set) var isBundleActive: Bool = false

    /// ロード状態。
    private(set) var isLoading: Bool = false

    /// エラーメッセージ（UI 表示用）。
    private(set) var errorMessage: String?

    // MARK: - Product IDs

    static let bundleProductIdentifiers: Set<String> = [
        "com.muscle360.bundle.pro.monthly",
        "com.muscle360.bundle.pro.yearly"
    ]

    // MARK: - Private

    private let client: SupabaseClient
    private let log = SorryGainsLogger(category: "Subscription")
    private var transactionListener: Task<Void, Never>?

    // MARK: - Init

    init(client: SupabaseClient = SupabaseConfig.client) {
        self.client = client
        transactionListener = listenForTransactions()
        Task {
            await refreshEntitlements()
        }
    }

    // transactionListener は Task で管理。deinit での cancel は MainActor 制約で不可のため
    // listenForTransactions() 内の [weak self] ガードで自動解放される。

    // MARK: - Bundle Status from Supabase

    /// Supabase RPC `get_bundle_status` からバンドル加入状況を取得して更新する。
    func refreshBundleStatus() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let response: BundleStatusResponse = try await client
                .rpc("get_bundle_status")
                .execute()
                .value

            isBundleActive = response.bundleActive
            log.info("bundle status refreshed: active=\(response.bundleActive)")
        } catch {
            // 未サインイン or ネットワークエラーは無視（既存状態を維持）
            log.warning("bundle status refresh failed: \(error.localizedDescription)")
        }
    }

    // MARK: - StoreKit Entitlement (補完)

    /// StoreKit のエンタイトルメントを確認してバンドル状態を補完する。
    /// App Store 購入直後など、Supabase より StoreKit が先に更新される場合に使う。
    func refreshEntitlements() async {
        var hasBundle = false
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if Self.bundleProductIdentifiers.contains(transaction.productID) {
                    hasBundle = true
                }
            } catch {
                log.warning("entitlement verification failed: \(error.localizedDescription)")
            }
        }
        if hasBundle {
            isBundleActive = true
        }
    }

    /// 外部から直接バンドル状態を更新する（BundleEntitlementService 経由）。
    func updateBundleActive(_ active: Bool) {
        isBundleActive = active
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { continue }
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    self.log.warning("transaction listener error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw error
        }
    }
}

// MARK: - Response DTO

private struct BundleStatusResponse: Decodable {
    let bundleActive: Bool
    let bundleProductId: String?
    let bundleExpiresAt: Int?
    let checkedAt: Int

    enum CodingKeys: String, CodingKey {
        case bundleActive    = "bundle_active"
        case bundleProductId = "bundle_product_id"
        case bundleExpiresAt = "bundle_expires_at"
        case checkedAt       = "checked_at"
    }
}
