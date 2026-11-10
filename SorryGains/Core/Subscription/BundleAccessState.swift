import Foundation

enum BundlePurchaseEnvironment: String {
    case production = "Production"
    case sandbox = "Sandbox"

    var statusRPC: String {
        self == .sandbox ? "get_sandbox_bundle_status" : "get_bundle_status"
    }
}

/// StoreKit の端末権利と、ログイン中の本人に属するサーバー権利を分けて扱う。
struct BundleAccessState {
    private(set) var userID: UUID?
    private(set) var environment: BundlePurchaseEnvironment?
    private(set) var localExpiresAt: Date?
    private(set) var serverExpiresAt: Date?
    private var requestGeneration = 0

    mutating func changeUser(to userID: UUID?) {
        guard self.userID != userID else { return }
        requestGeneration += 1
        self.userID = userID
        serverExpiresAt = nil
    }

    mutating func changeEnvironment(to environment: BundlePurchaseEnvironment?) {
        guard self.environment != environment else { return }
        requestGeneration += 1
        self.environment = environment
        serverExpiresAt = nil
    }

    mutating func updateLocal(expiresAt: Date?) {
        localExpiresAt = expiresAt
    }

    mutating func beginRequest() -> Int {
        requestGeneration += 1
        return requestGeneration
    }

    func isCurrentRequest(_ generation: Int) -> Bool {
        requestGeneration == generation
    }

    mutating func updateServer(active: Bool, expiresAt: Date?, for userID: UUID, request: Int, environment: BundlePurchaseEnvironment?) {
        guard self.userID == userID, isCurrentRequest(request) else { return }
        serverExpiresAt = active && self.environment != nil && self.environment == environment ? expiresAt : nil
    }

    static func localExpiration(
        transactionExpiresAt: Date?, verifiedGraceExpiresAt: Date?,
        isInGracePeriod: Bool, now: Date
    ) -> Date? {
        [transactionExpiresAt, isInGracePeriod ? verifiedGraceExpiresAt : nil]
            .compactMap { $0 }.filter { $0 > now }.max()
    }

    func isActive(at now: Date) -> Bool {
        [localExpiresAt, userID == nil ? nil : serverExpiresAt]
            .compactMap { $0 }
            .contains { $0 > now }
    }

    func nextExpiration(after now: Date) -> Date? {
        [localExpiresAt, userID == nil ? nil : serverExpiresAt]
            .compactMap { $0 }
            .filter { $0 > now }
            .min()
    }
}
