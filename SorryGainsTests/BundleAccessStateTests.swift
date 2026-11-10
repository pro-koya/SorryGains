import Foundation
import Testing
@testable import SorryGains

@Suite("SorryGains purchase access isolation and expiry")
struct SorryGainsBundleAccessStateTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let first = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    let second = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!

    @Test func serverInactiveKeepsVerifiedLocalPurchase() {
        var state = BundleAccessState()
        state.changeUser(to: first)
        state.changeEnvironment(to: .production)
        let request = state.beginRequest()
        state.updateLocal(expiresAt: now.addingTimeInterval(60))
        state.updateServer(active: false, expiresAt: nil, for: first, request: request, environment: .production)
        #expect(state.isActive(at: now))
    }

    @Test func localAndServerExpireAtTheirOwnDeadlines() {
        var state = BundleAccessState()
        state.changeUser(to: first)
        state.changeEnvironment(to: .production)
        let request = state.beginRequest()
        state.updateLocal(expiresAt: now.addingTimeInterval(60))
        state.updateServer(active: true, expiresAt: now.addingTimeInterval(30), for: first, request: request, environment: .production)
        #expect(state.isActive(at: now.addingTimeInterval(31)))
        #expect(!state.isActive(at: now.addingTimeInterval(60)))
        #expect(state.nextExpiration(after: now) == now.addingTimeInterval(30))
    }

    @Test func missingExpiryDoesNotGrantServerAccess() {
        var state = BundleAccessState()
        state.changeUser(to: first)
        state.changeEnvironment(to: .production)
        let request = state.beginRequest()
        state.updateServer(active: true, expiresAt: nil, for: first, request: request, environment: .production)
        #expect(!state.isActive(at: now))
    }

    @Test func accountSwitchClearsServerAndRejectsOldResponse() {
        var state = BundleAccessState()
        state.changeUser(to: first)
        state.changeEnvironment(to: .production)
        let request = state.beginRequest()
        state.updateServer(active: true, expiresAt: now.addingTimeInterval(60), for: first, request: request, environment: .production)
        #expect(state.isActive(at: now))
        state.changeUser(to: second)
        state.changeEnvironment(to: .production)
        state.updateServer(active: true, expiresAt: now.addingTimeInterval(60), for: first, request: request, environment: .production)
        #expect(!state.isActive(at: now))
        #expect(state.serverExpiresAt == nil)
    }

    @Test func signOutKeepsOnlyDevicePurchase() {
        var state = BundleAccessState()
        state.changeUser(to: first)
        state.changeEnvironment(to: .production)
        let request = state.beginRequest()
        state.updateLocal(expiresAt: now.addingTimeInterval(60))
        state.updateServer(active: true, expiresAt: now.addingTimeInterval(120), for: first, request: request, environment: .production)
        state.changeUser(to: nil)
        #expect(state.isActive(at: now))
        #expect(!state.isActive(at: now.addingTimeInterval(60)))
    }

    @Test func storeRevocationClearsLocalButKeepsIndependentServerLease() {
        var state = BundleAccessState()
        state.changeUser(to: first)
        state.changeEnvironment(to: .production)
        let request = state.beginRequest()
        state.updateLocal(expiresAt: now.addingTimeInterval(60))
        state.updateServer(active: true, expiresAt: now.addingTimeInterval(30), for: first, request: request, environment: .production)
        state.updateLocal(expiresAt: nil)
        #expect(state.isActive(at: now))
        state.updateServer(active: false, expiresAt: nil, for: first, request: request, environment: .production)
        #expect(!state.isActive(at: now))
    }
    @Test func verifiedGracePeriodKeepsExpiredTransactionActive() {
        let grace = now.addingTimeInterval(600)
        #expect(BundleAccessState.localExpiration(
            transactionExpiresAt: now.addingTimeInterval(-60),
            verifiedGraceExpiresAt: grace, isInGracePeriod: true, now: now
        ) == grace)
    }

    @Test func noGraceStateNeverExtendsAnExpiredPurchase() {
        #expect(BundleAccessState.localExpiration(
            transactionExpiresAt: now.addingTimeInterval(-60),
            verifiedGraceExpiresAt: now.addingTimeInterval(600),
            isInGracePeriod: false, now: now
        ) == nil)
        #expect(BundleAccessState.localExpiration(
            transactionExpiresAt: now.addingTimeInterval(-60),
            verifiedGraceExpiresAt: now, isInGracePeriod: true, now: now
        ) == nil)
    }
    @Test func staleActiveVerificationCannotReviveLatestInactiveRead() {
        var state = BundleAccessState()
        state.changeUser(to: first)
        state.changeEnvironment(to: .production)
        let oldVerification = state.beginRequest()
        let latestRead = state.beginRequest()
        state.updateServer(active: false, expiresAt: nil, for: first, request: latestRead, environment: .production)
        state.updateServer(active: true, expiresAt: now.addingTimeInterval(60), for: first, request: oldVerification, environment: .production)
        #expect(!state.isActive(at: now))
    }

    @Test func staleReadCannotOverrideLatestVerification() {
        var state = BundleAccessState()
        state.changeUser(to: first)
        state.changeEnvironment(to: .production)
        let oldRead = state.beginRequest()
        let latestVerification = state.beginRequest()
        state.updateServer(active: false, expiresAt: nil, for: first, request: latestVerification, environment: .production)
        state.updateServer(active: true, expiresAt: now.addingTimeInterval(60), for: first, request: oldRead, environment: .production)
        #expect(!state.isActive(at: now))
    }
    @Test func sandboxAndProductionUseDifferentRPCs() {
        #expect(BundlePurchaseEnvironment.sandbox.statusRPC == "get_sandbox_bundle_status")
        #expect(BundlePurchaseEnvironment.production.statusRPC == "get_bundle_status")
        #expect(BundlePurchaseEnvironment(rawValue: "Xcode") == nil)
    }

    @Test func environmentChangeDropsServerAndRejectsOldRealmResponse() {
        var state = BundleAccessState()
        state.changeUser(to: first)
        state.changeEnvironment(to: .production)
        let production = state.beginRequest()
        state.updateServer(active: true, expiresAt: now.addingTimeInterval(60), for: first, request: production, environment: .production)
        #expect(state.isActive(at: now))
        state.changeEnvironment(to: .sandbox)
        #expect(!state.isActive(at: now))
        state.updateServer(active: true, expiresAt: now.addingTimeInterval(60), for: first, request: production, environment: .production)
        #expect(!state.isActive(at: now))
    }

    @Test func mismatchedOrMissingEnvironmentCannotGrantServerRights() {
        var state = BundleAccessState()
        state.changeUser(to: first)
        state.changeEnvironment(to: .sandbox)
        let request = state.beginRequest()
        for environment: BundlePurchaseEnvironment? in [.production, nil] {
            state.updateServer(active: true, expiresAt: now.addingTimeInterval(60), for: first, request: request, environment: environment)
            #expect(!state.isActive(at: now))
        }
        state.updateServer(active: true, expiresAt: now.addingTimeInterval(60), for: first, request: request, environment: .sandbox)
        #expect(state.isActive(at: now))
    }

    @Test func unknownEnvironmentKeepsOnlyVerifiedDevicePurchase() {
        var state = BundleAccessState()
        state.changeUser(to: first)
        state.changeEnvironment(to: .sandbox)
        state.updateLocal(expiresAt: now.addingTimeInterval(30))
        state.changeEnvironment(to: nil)
        let request = state.beginRequest()
        state.updateServer(active: true, expiresAt: now.addingTimeInterval(60), for: first, request: request, environment: .sandbox)
        #expect(state.isActive(at: now))
        #expect(!state.isActive(at: now.addingTimeInterval(30)))
    }
}
