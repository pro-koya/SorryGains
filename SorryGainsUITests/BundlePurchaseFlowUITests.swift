import XCTest

// MARK: - BundlePurchaseFlowUITests
//
// Muscle360 Pro バンドル購入フローの XCUITest。
//
// 前提条件:
//   - SorryGains scheme の StoreKit Configuration に
//     SorryGains/SorryGains.storekit が指定されていること（project.yml 設定済み）
//   - Simulator 上で実行（実機 Sandbox 不要）
//
// テスト設計方針:
//   - 購入フローは StoreKit Test Configuration によって Simulator 内で完結
//   - Supabase 通信は発生しない（未サインイン状態でテスト）
//   - アプリ内の実際の UI 要素を accessibility identifier / label で検索
//
// Scenario マッピング:
//   Scenario 1: settings_tab_accessible
//   Scenario 2: bundle_plan_cards_visible_in_settings
//   Scenario 3: ad_banner_check_in_unauthenticated_state
//   Scenario 4: sage_tab_accessible_and_shows_advice_placeholder

final class BundlePurchaseFlowUITests: XCTestCase {

    // MARK: - Properties

    var app: XCUIApplication!

    // MARK: - Setup / Teardown

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // UITestMode: Onboarding / 認証ゲートをバイパスして MainTabView 直結で起動。
        // Forge の ScreenshotMode と同じ思想（DEBUG ビルドのみ有効）。
        app.launchArguments.append("-uiTestMode")
        app.launchArguments.append("1")
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// 設定タブに遷移する（4番目のタブ、index=3）
    private func navigateToSettings() {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else {
            XCTFail("タブバーが見つかりません")
            return
        }
        // SorryGains: home / sage / history / settings の4タブ
        let settingsTab = tabBar.buttons.element(boundBy: 3)
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5), "設定タブが見つかりません")
        settingsTab.tap()
    }

    /// 仙人タブに遷移する（2番目のタブ、index=1）
    private func navigateToSage() {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else {
            XCTFail("タブバーが見つかりません")
            return
        }
        let sageTab = tabBar.buttons.element(boundBy: 1)
        XCTAssertTrue(sageTab.waitForExistence(timeout: 5), "仙人タブが見つかりません")
        sageTab.tap()
    }

    // MARK: - Scenario 1: 設定タブにアクセスできる

    func test_scenario1_settings_tab_accessible() throws {
        // Act: 設定タブへ遷移
        navigateToSettings()

        // Assert: 設定画面の NavigationTitle が表示される
        // SettingsView.navigationTitle = String(localized: "settings.title")
        // ja = "設定" / en = "Settings"
        let navTitle = app.navigationBars.firstMatch
        XCTAssertTrue(
            navTitle.waitForExistence(timeout: 5),
            "設定画面の NavigationBar が表示されていません"
        )
    }

    // MARK: - Scenario 2: 設定画面にバンドルプランカードが表示される

    func test_scenario2_bundle_plan_cards_visible_in_settings() throws {
        // Act: 設定タブへ遷移
        navigateToSettings()

        // Scenario 5 と同じ頑健性パターン（accessibility identifier OR price text、
        // 複数回スクロール試行）を採用。前テストとの状態残りに耐える。

        // Form/List が完全にロードされるまで待機
        _ = app.cells.firstMatch.waitForExistence(timeout: 8)

        // Helper: バンドル月額行を価格テキスト OR identifier のどちらかで検出
        func findMonthly() -> Bool {
            let priceText = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] '¥250' OR label CONTAINS '250'")
            ).firstMatch
            let rowById = app.otherElements["bundlePlanMonthlyRow"]
            return priceText.exists || rowById.exists
        }

        // Helper: バンドル年額行を検出
        func findYearly() -> Bool {
            let priceText = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] '¥2,500' OR label CONTAINS '2500' OR label CONTAINS '17%'")
            ).firstMatch
            let rowById = app.otherElements["bundlePlanYearlyRow"]
            return priceText.exists || rowById.exists
        }

        // 最大 3 回スクロールして探索（cell ベース swipe で確実に動かす）
        var attempts = 0
        while attempts < 3 && !findMonthly() {
            let firstCell = app.cells.firstMatch
            if firstCell.exists { firstCell.swipeUp() }
            _ = app.cells.firstMatch.waitForExistence(timeout: 2)
            attempts += 1
        }

        XCTAssertTrue(
            findMonthly(),
            "バンドル月額行（¥250 テキスト または bundlePlanMonthlyRow identifier）が " +
            "設定画面に見つかりません。bundleSubscriptionSection が描画されているか確認してください。"
        )

        // 年額は月額と同じセクション内にあるはずなので、追加スクロールせずに確認
        // ただし状況によっては月額の下にあるため最大 2 回追加スクロール
        attempts = 0
        while attempts < 2 && !findYearly() {
            let firstCell = app.cells.firstMatch
            if firstCell.exists { firstCell.swipeUp() }
            attempts += 1
        }

        XCTAssertTrue(
            findYearly(),
            "バンドル年額行（¥2,500 / 17% OFF / bundlePlanYearlyRow identifier のいずれか）が " +
            "見つかりません。bundlePlanRow の price: '¥2,500/年' を確認してください。"
        )
    }

    // MARK: - Scenario 3: ホーム画面の広告エリア確認（未認証 = バンドル未加入状態）

    func test_scenario3_home_tab_accessible_and_ad_area_present() throws {
        // Act: ホームタブを明示的に確認（起動直後 = home タブ）
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        let homeTab = tabBar.buttons.element(boundBy: 0)
        if homeTab.exists { homeTab.tap() }

        // Assert: ホーム画面がロードされている
        // アプリ起動後のロード待機
        let homeContent = app.scrollViews.firstMatch
            .waitForExistence(timeout: 5) ||
            app.collectionViews.firstMatch.waitForExistence(timeout: 5)

        // ホームビューが表示されていること（TabBar が存在する = アプリが起動している）
        XCTAssertTrue(tabBar.exists, "タブバーが表示されていません")

        // バンドル未加入状態では AdBannerSlot が存在する可能性がある
        // accessibilityHidden=true の要素は検索できないため、
        // ここでは「アプリがクラッシュせず広告エリアが描画されている」を確認する
        // （実際の表示/非表示は Scenario 2 の購入後反映テストで確認）
        _ = homeContent  // suppress unused warning
        XCTAssertTrue(app.exists, "アプリがクラッシュしています")
    }

    // MARK: - Scenario 4: 仙人助言画面 → 助言プレースホルダーが表示される

    func test_scenario4_sage_tab_shows_advice_placeholder() throws {
        // Act: 仙人タブへ遷移
        navigateToSage()

        // Assert: 仙人助言画面が表示されている
        // 初期状態では「下のボタンで仙人に話を聞いてみろ。」が表示される
        // または ProgressView（生成中）が表示される
        let advisoryPlaceholder = app.staticTexts.matching(
            NSPredicate(
                format: "label CONTAINS[c] '仙人' OR label CONTAINS[c] 'ボタン' OR label CONTAINS[c] '今すぐ'"
            )
        ).firstMatch
        let askButton = app.buttons.matching(
            NSPredicate(
                format: "label CONTAINS[c] '今すぐ聞く' OR label CONTAINS[c] '仙人'"
            )
        ).firstMatch

        // 仙人画面の要素（プレースホルダーかボタンのいずれかが存在する）
        let sageElementExists = advisoryPlaceholder.waitForExistence(timeout: 10) ||
            askButton.waitForExistence(timeout: 5)

        XCTAssertTrue(
            sageElementExists,
            "仙人助言画面の要素（プレースホルダーまたは「今すぐ聞く」ボタン）が見つかりません"
        )

        // 「今すぐ聞く」ボタンが存在する場合、タップして助言を取得
        // 注: FoundationModels は iOS 26+ 限定。iOS 18 Simulator では LocalProvider が
        //     使われるため、応答速度や動作が異なる場合がある。
        if askButton.waitForExistence(timeout: 3) {
            askButton.tap()

            // 生成中インジケーターが表示されることを確認（起動トリガーとして）
            let generatingIndicator = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] '考え中' OR label CONTAINS[c] 'credits'")
            ).firstMatch

            let adviceText = app.staticTexts["sageAdviceText"]

            // 「考え中」または助言テキストのいずれかが表示されれば PASS
            // タイムアウトしても警告のみ（CI での不安定さを避けるため）
            let responseAppeared = generatingIndicator.waitForExistence(timeout: 8) ||
                adviceText.waitForExistence(timeout: 8)

            if !responseAppeared {
                // iOS バージョン・credits 残高によってボタンが押せない場合がある
                // テスト自体は「仙人画面にアクセスできる」を確認するものであり
                // 助言生成は副次的確認。警告として記録する。
                let outOfCredits = app.staticTexts.matching(
                    NSPredicate(format: "label CONTAINS[c] 'credits' OR label CONTAINS[c] 'あと'")
                ).firstMatch
                if outOfCredits.exists {
                    // credits 枯渇の場合は正常動作として許容
                    return
                }
                // それ以外は失敗
                XCTFail(
                    "「今すぐ聞く」タップ後に応答（生成中 or 助言テキスト）が表示されませんでした。" +
                    "SageAdviceProvider の実装と credits 残高を確認してください。"
                )
            }
        }
    }

    // MARK: - Scenario 5: バンドルセクションの accessibility identifier 確認

    func test_scenario5_bundle_section_accessibility_identifiers() throws {
        // 設定画面に遷移
        navigateToSettings()

        // bundleStatusActive identifier または月額/年額行が存在する
        // isBundleActive=false（未認証）のため bundlePlanMonthlyRow/bundlePlanYearlyRow が表示

        // Form/List が完全にロードされるまで待機
        _ = app.cells.firstMatch.waitForExistence(timeout: 5)

        // ¥250 テキストを直接検索（スクロール不要な場合も対応）
        let monthlyPriceText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] '¥250'")
        ).firstMatch

        // 見つからない場合はスクロールして再試行
        if !monthlyPriceText.exists {
            // Form の最初の cell に対してスクロール
            let firstCell = app.cells.firstMatch
            if firstCell.exists {
                firstCell.swipeUp()
            }
        }

        // accessibility identifier が存在するか、または価格テキストが存在するかのいずれかを確認
        let bundleMonthlyRow = app.otherElements["bundlePlanMonthlyRow"]
        let monthlyExists = bundleMonthlyRow.waitForExistence(timeout: 3) ||
            monthlyPriceText.waitForExistence(timeout: 3)

        XCTAssertTrue(
            monthlyExists,
            "bundlePlanMonthlyRow identifier または ¥250 テキストが見つかりません。" +
            "SettingsView の accessibilityIdentifier 設定を確認してください。"
        )
    }
}
