import Foundation
import StoreKit
import Supabase

// MARK: - SubscriptionManager (SorryGains)
//
// SorryGains は単独サブスクなし。バンドル限定 Pro 機能のみ。
// Supabase RPC `get_bundle_status` でバンドル加入を確認し、
// StoreKit 2 で実際の購入フローを提供する。
//
// 商品 ID:
//   com.sorrygains.bundle.pro.monthly  - バンドル月額 ¥250
//   com.sorrygains.bundle.pro.yearly   - バンドル年額 ¥2,500
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

    /// 取得済みの購入可能なプロダクト一覧。
    private(set) var products: [Product] = []

    /// プロダクトロード中かどうか。
    private(set) var isLoading: Bool = false

    /// 購入処理中かどうか。
    private(set) var isPurchasing: Bool = false

    /// エラーメッセージ（UI 表示用）。
    private(set) var errorMessage: String?

    // MARK: - Product IDs

    static let bundleProductIdentifiers: Set<String> = [
        "com.sorrygains.bundle.pro.monthly",
        "com.sorrygains.bundle.pro.yearly"
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
            await loadProducts()
            await refreshEntitlements()
        }
    }

    // transactionListener は Task で管理。deinit での cancel は MainActor 制約で不可のため
    // listenForTransactions() 内の [weak self] ガードで自動解放される。

    // MARK: - Products

    /// App Store からバンドルプロダクト情報を取得する。
    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await Product.products(for: Self.bundleProductIdentifiers)
            products = fetched.sorted { $0.price < $1.price }
            log.info("loaded \(products.count) bundle products")
        } catch {
            log.error("loadProducts failed: \(error.localizedDescription)")
            // App Store Connect に商品が無い場合でもアプリは継続動作させる
            errorMessage = "サブスクリプション情報の取得に失敗しました。"
        }
    }

    // MARK: - Purchase

    /// バンドル月額を購入する。成功時は isBundleActive が更新される。
    @discardableResult
    func purchaseBundleMonthly() async -> Bool {
        guard let product = products.first(where: {
            $0.id == "com.sorrygains.bundle.pro.monthly"
        }) else {
            errorMessage = "商品が見つかりません。"
            return false
        }
        return await purchase(product: product)
    }

    /// バンドル年額を購入する。成功時は isBundleActive が更新される。
    @discardableResult
    func purchaseBundleYearly() async -> Bool {
        guard let product = products.first(where: {
            $0.id == "com.sorrygains.bundle.pro.yearly"
        }) else {
            errorMessage = "商品が見つかりません。"
            return false
        }
        return await purchase(product: product)
    }

    /// 任意のバンドルプロダクトを購入する。
    @discardableResult
    func purchase(product: Product) async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                await recordPurchaseInSupabase(transaction: transaction)
                log.info("purchased bundle: \(product.id)")
                return true

            case .userCancelled:
                return false

            case .pending:
                errorMessage = "保護者承認等の確認待ちです。"
                return false

            @unknown default:
                return false
            }
        } catch {
            log.error("purchase failed: \(error.localizedDescription)")
            errorMessage = "購入に失敗しました。"
            return false
        }
    }

    /// 別端末での購入を復元する。
    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            log.info("restore completed")
        } catch {
            log.error("restore failed: \(error.localizedDescription)")
            errorMessage = "復元に失敗しました。"
        }
    }

    // MARK: - Bundle Status from Supabase

    /// Supabase RPC `get_bundle_status` からバンドル加入状況を取得して更新する。
    func refreshBundleStatus() async {
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
        var revokedProductID: String?
        var revokedTransactionID: String?

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if Self.bundleProductIdentifiers.contains(transaction.productID) {
                    if transaction.revocationDate != nil {
                        // 返金・取り消し済み
                        revokedProductID = transaction.productID
                        revokedTransactionID = String(transaction.originalID)
                    } else {
                        hasBundle = true
                    }
                }
            } catch {
                log.warning("entitlement verification failed: \(error.localizedDescription)")
            }
        }

        if hasBundle {
            isBundleActive = true
        } else if let _ = revokedProductID {
            // 返金・取り消しを検出したとき Supabase を更新し、ローカル状態もクリア
            isBundleActive = false
            await clearBundleStatusInSupabase()
        }
    }

    /// 外部から直接バンドル状態を更新する（BundleEntitlementService 経由）。
    func updateBundleActive(_ active: Bool) {
        isBundleActive = active
    }

    // MARK: - Supabase RPC Helpers

    /// 購入成功後に Supabase RPC `record_bundle_purchase` を呼び出す。
    /// RPC エラーは fail soft（ログ記録のみ、クラッシュしない）。
    private func recordPurchaseInSupabase(transaction: Transaction) async {
        let expiresAt: Int
        if let expirationDate = transaction.expirationDate {
            expiresAt = Int(expirationDate.timeIntervalSince1970)
        } else {
            expiresAt = Int(Date().addingTimeInterval(60 * 60 * 24 * 30).timeIntervalSince1970)
        }

        do {
            let _: BundleStatusResponse = try await client
                .rpc(
                    "record_bundle_purchase",
                    params: RecordBundlePurchaseParams(
                        pProductId: transaction.productID,
                        pExpiresAt: expiresAt,
                        pOriginalTransactionId: String(transaction.originalID)
                    )
                )
                .execute()
                .value
            log.info("recorded bundle purchase in Supabase: \(transaction.productID)")
        } catch {
            // fail soft: RPC エラーはログのみ。StoreKit エンタイトルメントが真実なので続行する。
            log.warning("record_bundle_purchase RPC failed (non-fatal): \(error.localizedDescription)")
        }
    }

    /// 返金・取り消し検出時に Supabase RPC `clear_bundle_status` を呼び出す。
    /// RPC エラーは fail soft（ログ記録のみ）。
    private func clearBundleStatusInSupabase() async {
        do {
            let _: BundleStatusResponse = try await client
                .rpc("clear_bundle_status")
                .execute()
                .value
            log.info("cleared bundle status in Supabase")
        } catch {
            log.warning("clear_bundle_status RPC failed (non-fatal): \(error.localizedDescription)")
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { continue }
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()

                    if transaction.revocationDate != nil {
                        // 返金・取り消し
                        self.isBundleActive = false
                        await self.clearBundleStatusInSupabase()
                        self.log.info("transaction revoked: \(transaction.productID)")
                    } else {
                        await self.refreshEntitlements()
                    }
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

// MARK: - Display Helpers (UI 表示用)

extension SubscriptionManager {
    /// バンドル月額表示用文字列（"¥250/月" 形式）。プロダクト未取得なら空文字。
    var bundleMonthlyDisplayPrice: String {
        guard let product = products.first(where: {
            $0.id == "com.sorrygains.bundle.pro.monthly"
        }) else { return "" }
        return "\(product.displayPrice)/月"
    }

    /// バンドル年額表示用文字列（"¥2,500/年" 形式）。
    var bundleYearlyDisplayPrice: String {
        guard let product = products.first(where: {
            $0.id == "com.sorrygains.bundle.pro.yearly"
        }) else { return "" }
        return "\(product.displayPrice)/年"
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

// MARK: - Request DTO

private struct RecordBundlePurchaseParams: Encodable {
    let pProductId: String
    let pExpiresAt: Int
    let pOriginalTransactionId: String

    enum CodingKeys: String, CodingKey {
        case pProductId              = "p_product_id"
        case pExpiresAt              = "p_expires_at"
        case pOriginalTransactionId  = "p_original_transaction_id"
    }
}
