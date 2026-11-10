import Foundation
import StoreKit
import Supabase

/// ローカルの検証済み購入と、本人に紐付いたアプリ間共有を管理する。
@Observable
@MainActor
final class SubscriptionManager {
    private(set) var products: [Product] = []
    private(set) var isBundleActive = false
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    private(set) var errorMessage: String?

    static let bundleProductIdentifiers: Set<String> = [
        "com.sorrygains.bundle.pro.monthly",
        "com.sorrygains.bundle.pro.yearly"
    ]
    static let productIdentifiers = bundleProductIdentifiers
    private static let bundleID = "com.sorrygains.SorryGains"
    private static let serverCacheTTL: TimeInterval = 5 * 60

    private let client: SupabaseClient
    private let log = SorryGainsLogger(category: "Subscription")
    private var access = BundleAccessState()
    private var lastServerCheck: Date?
    private var entitlementGeneration = 0
    private var transactionListener: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    init(client: SupabaseClient = SupabaseConfig.client) {
        self.client = client

        transactionListener = listenForTransactions()
        refreshTask = periodicallyRefreshServer()
        Task {
            await loadProducts()
            await refreshEntitlements()
            await refreshBundleStatus()
        }
    }

    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: Self.productIdentifiers)
                .sorted { $0.price < $1.price }
        } catch {
            log.warning("product lookup failed")
            errorMessage = "サブスクリプション情報の取得に失敗しました。"
        }
    }

    @discardableResult
    func purchaseBundleMonthly() async -> Bool {
        await purchaseProduct(id: "com.sorrygains.bundle.pro.monthly")
    }

    @discardableResult
    func purchaseBundleYearly() async -> Bool {
        await purchaseProduct(id: "com.sorrygains.bundle.pro.yearly")
    }

    private func purchaseProduct(id: String) async -> Bool {
        guard let product = products.first(where: { $0.id == id }) else {
            errorMessage = "商品が見つかりません。"
            return false
        }
        return await purchase(product: product)
    }

    @discardableResult
    func purchase(product: Product) async -> Bool {
        guard !isPurchasing, Self.bundleProductIdentifiers.contains(product.id) else { return false }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        let session: Session
        do {
            session = try await client.auth.session
        } catch {
            errorMessage = "バンドルを購入する前にログインしてください。"
            return false
        }
        do {
            let result = try await product.purchase(options: [.appAccountToken(session.user.id)])
            return try await handlePurchaseResult(result)
        } catch {
            log.warning("purchase verification failed")
            errorMessage = "購入に失敗しました。"
            return false
        }
    }

    private func handlePurchaseResult(_ result: Product.PurchaseResult) async throws -> Bool {
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await recordSignedPurchase(verification.jwsRepresentation)
            await transaction.finish()
            await refreshEntitlements()
            return true
        case .userCancelled:
            return false
        case .pending:
            errorMessage = "保護者承認等の確認待ちです。"
            return false
        @unknown default:
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            await refreshBundleStatus(forceRefresh: true)
        } catch {
            log.warning("purchase restore failed")
            errorMessage = "復元に失敗しました。"
        }
    }

    /// 端末に有効な購入がある場合、共有の保留や通信障害で端末権利を消さない。
    func refreshEntitlements() async {
        entitlementGeneration += 1
        let generation = entitlementGeneration
        var expiresAt: Date?
        var proofs: [String] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.bundleProductIdentifiers.contains(transaction.productID),
                  transaction.revocationDate == nil, !transaction.isUpgraded,
                  let expiry = await localExpiration(for: transaction) else { continue }
            expiresAt = max(expiresAt ?? expiry, expiry)
            proofs.append(result.jwsRepresentation)
        }
        guard generation == entitlementGeneration else { return }
        synchronizeUser()
        access.updateLocal(expiresAt: expiresAt)
        updateAccess()
        for proof in proofs {
            await recordSignedPurchase(proof)
        }
    }

    func refreshBundleStatus(forceRefresh: Bool = false) async {
        guard let context = await prepareServerContext() else { return }
        let (userID, environment, generation) = context
        if !forceRefresh, let lastServerCheck,
           Date().timeIntervalSince(lastServerCheck) < (environment == .sandbox ? 30 : Self.serverCacheTTL) { return }
        do {
            let response: BundleStatusResponse = try await client
                .rpc(environment.statusRPC).execute().value
            guard access.isCurrentRequest(generation),
                  client.auth.currentUser?.id == userID else { return }
            applyServer(response, userID: userID, environment: environment, generation: generation)
        } catch {
            log.warning("bundle status lookup failed")
        }
    }

    /// サインアウト/アカウント切替時に、前の利用者の共有状態だけを即時破棄する。
    func accountDidChange() {
        synchronizeUser()
        updateAccess()
    }

    private func synchronizeUser() {
        let userID = client.auth.currentUser?.id
        guard access.userID != userID else { return }
        access.changeUser(to: userID)
        lastServerCheck = nil
        updateAccess()
    }

    private func recordSignedPurchase(_ proof: String) async {
        do {
            let session = try await client.auth.session
            guard let (userID, environment, generation) = await prepareServerContext(),
                  userID == session.user.id else { return }
            let response: BundleStatusResponse = try await client.functions.invoke(
                "verify-bundle-purchase",
                options: FunctionInvokeOptions(
                    headers: ["Authorization": "Bearer \(session.accessToken)"],
                    body: VerifyBundlePurchaseRequest(bundleId: Self.bundleID, signedTransaction: proof)
                )
            )
            guard access.isCurrentRequest(generation),
                  client.auth.currentUser?.id == session.user.id else { return }
            applyServer(response, userID: session.user.id, environment: environment, generation: generation)
        } catch {
            // 旧購入/家族共有/別アカウントは共有を保留。JWSやサーバーの生エラーは記録しない。
            log.warning("bundle purchase sharing not confirmed")
            errorMessage = "端末の購入は維持されています。アプリ間共有を確認できない場合は、購入時のアカウントでログインして復元してください。"
        }
    }

    /// OS evidence chooses only which isolated sharing realm to read; the server verifies the purchase independently.
    private func prepareServerContext() async -> (UUID, BundlePurchaseEnvironment, Int)? {
        synchronizeUser()
        guard access.userID != nil else { return nil }
        let lookup = access.beginRequest()
        let environment = await Self.purchaseEnvironment()
        guard access.isCurrentRequest(lookup) else { return nil }
        synchronizeUser()
        guard access.isCurrentRequest(lookup) else { return nil }
        if access.environment != environment {
            access.changeEnvironment(to: environment)
            lastServerCheck = nil
            updateAccess()
        }
        guard let userID = access.userID, let environment else { return nil }
        return (userID, environment, access.beginRequest())
    }

    private static func purchaseEnvironment() async -> BundlePurchaseEnvironment? {
        do {
            let result = try await AppTransaction.shared
            guard case .verified(let transaction) = result else { return nil }
            switch transaction.environment {
            case .production: return .production
            case .sandbox: return .sandbox
            default: return nil
            }
        } catch {
            // A missing sandbox receipt is not evidence of Production. Retry on the next refresh/purchase/restore.
            guard let receipt = Bundle.main.appStoreReceiptURL,
                  FileManager.default.fileExists(atPath: receipt.path) else { return nil }
            switch receipt.lastPathComponent {
            case "sandboxReceipt": return .sandbox
            case "receipt": return .production
            default: return nil
            }
        }
    }

    private func applyServer(_ response: BundleStatusResponse, userID: UUID,
                             environment: BundlePurchaseEnvironment, generation: Int) {
        synchronizeUser()
        guard access.userID == userID, access.environment == environment, access.isCurrentRequest(generation) else { return }
        let expiry = response.bundleExpiresAt.map { Date(timeIntervalSince1970: Double($0)) }
        access.updateServer(active: response.bundleActive, expiresAt: expiry, for: userID, request: generation,
                            environment: response.environment.flatMap(BundlePurchaseEnvironment.init(rawValue:)))
        lastServerCheck = response.environment == environment.rawValue ? Date() : nil
        updateAccess()
    }

    private func updateAccess() {
        let now = Date()
        isBundleActive = access.isActive(at: now)
        expiryTask?.cancel()
        guard let expiry = access.nextExpiration(after: now) else { return }
        let delay = min(expiry.timeIntervalSince(now), 24 * 60 * 60)
        expiryTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch { return }
            guard let self else { return }
            self.updateAccess()
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self, case .verified(let transaction) = result,
                      Self.bundleProductIdentifiers.contains(transaction.productID) else { continue }
                await self.recordSignedPurchase(result.jwsRepresentation)
                await transaction.finish()
                await self.refreshEntitlements()
            }
        }
    }

    /// 猶予を自己加算せず、Apple が検証した同一購入の更新情報から期限を得る。
    private func localExpiration(for transaction: Transaction) async -> Date? {
        let now = Date()
        if let expiry = transaction.expirationDate, expiry > now { return expiry }
        guard let status = await transaction.subscriptionStatus,
              status.state == .inGracePeriod,
              case .verified(let current) = status.transaction,
              current.originalID == transaction.originalID,
              Self.bundleProductIdentifiers.contains(current.productID),
              current.revocationDate == nil,
              case .verified(let renewal) = status.renewalInfo else { return nil }
        return BundleAccessState.localExpiration(
            transactionExpiresAt: transaction.expirationDate,
            verifiedGraceExpiresAt: renewal.gracePeriodExpirationDate,
            isInGracePeriod: true, now: now
        )
    }

    private func periodicallyRefreshServer() -> Task<Void, Never> {
        Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(30))
                } catch { return }
                guard let self else { return }
                await self.refreshBundleStatus()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified(_, let error): throw error
        }
    }
}

private struct VerifyBundlePurchaseRequest: Encodable {
    let bundleId: String
    let signedTransaction: String
}

private struct BundleStatusResponse: Decodable {
    let environment: String?
    let bundleActive: Bool
    let bundleProductId: String?
    let bundleExpiresAt: Int?
    let checkedAt: Int

    enum CodingKeys: String, CodingKey {
        case environment
        case bundleActive = "bundle_active"
        case bundleProductId = "bundle_product_id"
        case bundleExpiresAt = "bundle_expires_at"
        case checkedAt = "checked_at"
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

