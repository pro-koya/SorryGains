import AppTrackingTransparency
import GoogleMobileAds
import SwiftData
import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // AdMob を必ず起動する（ATT の結果に関わらず）
        MobileAds.shared.start()
        return true
    }
}

@main
struct SorryGainsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    let modelContainer: ModelContainer
    let isUsingInMemoryStore: Bool
    let persistentStoreErrorDescription: String?
    @State private var authService = AuthService()
    @State private var trainingDataService = TrainingDataService()
    @State private var subscriptionManager = SubscriptionManager()
    @State private var bundleEntitlementService = BundleEntitlementService()
    @State private var showPersistenceWarning = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            modelContainer = try Self.makeModelContainer(isStoredInMemoryOnly: false)
            isUsingInMemoryStore = false
            persistentStoreErrorDescription = nil
        } catch {
            do {
                modelContainer = try Self.makeModelContainer(isStoredInMemoryOnly: true)
                isUsingInMemoryStore = true
                persistentStoreErrorDescription = error.localizedDescription
                assertionFailure("Persistent store unavailable. Falling back to in-memory store. Error: \(error)")
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .environment(authService)
                .environment(trainingDataService)
                .environment(subscriptionManager)
                .onOpenURL { url in
                    Task {
                        await authService.handleDeepLink(url)
                    }
                }
                .onChange(of: authService.isSignedIn) { _, isSignedIn in
                    trainingDataService.updateLinkStatus(isSignedIn: isSignedIn)
                    if isSignedIn {
                        // サインイン後にバンドル状態を再取得
                        Task {
                            await bundleEntitlementService.refresh(
                                subscriptionManager: subscriptionManager,
                                forceRefresh: true
                            )
                        }
                    }
                }
                .task {
                    if isUsingInMemoryStore {
                        showPersistenceWarning = true
                    }
                    // Request notification permission on launch
                    _ = await CharacterNotificationManager.shared.requestPermission()
                    // 起動時にバンドル加入状況を取得
                    await bundleEntitlementService.refresh(subscriptionManager: subscriptionManager)
                    // ATT 許可リクエスト（AdMob のパーソナライズ広告に必要）
                    // AdMob.start() は AppDelegate で先に呼んでいるため、ATT 結果に関わらず広告は動作する
                    await requestTrackingAuthorizationIfNeeded()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await bundleEntitlementService.refresh(subscriptionManager: subscriptionManager)
                        }
                    }
                }
                .alert("app.persistence_error.title", isPresented: $showPersistenceWarning) {
                    Button("common.close", role: .cancel) {}
                } message: {
                    Text("app.persistence_error.message")
                }
        }
        .modelContainer(modelContainer)
    }

    // MARK: - ATT

    /// ATT 許可をまだリクエストしていない場合にダイアログを表示する。
    /// iOS 14+ で .notDetermined のときのみダイアログが出る。
    /// 結果に関わらず AdMob は動作する（非パーソナライズ広告にフォールバック）。
    private func requestTrackingAuthorizationIfNeeded() async {
        guard #available(iOS 14, *) else { return }
        let status = ATTrackingManager.trackingAuthorizationStatus
        guard status == .notDetermined else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    private static func makeModelContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
        let schema = Schema([
            DrinkRecord.self,
            DailyTrainingStatus.self,
            UserProfile.self,
            DailyApologyState.self,
            DailyRecoveryLog.self,
            DrinkingSession.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
}
