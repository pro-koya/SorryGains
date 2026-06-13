import Foundation
import Testing
@testable import SorryGains

// MARK: - BundleEntitlementTests
//
// A-6 テスト要件:
//   - エンタイトルメント判定: 最低 5 ケース
//   - SagePromptBuilder バンドル分岐: 最低 3 ケース（既存 20 ケースに加えて）

// MARK: - SageContext Bundle Flag Tests

@Suite("SageContext bundle flag")
struct SageContextBundleFlagTests {

    private func makeContext(isBundlePro: Bool) -> SageContext {
        SageContext(
            todayDrinkCount: 1,
            todayTotalAlcoholGram: 14.0,
            todayDidTrain: false,
            weekDrinkCount: 3,
            weekTrainingDays: 2,
            consecutiveDrinkingDays: 1,
            trainingGoal: .maintain,
            latestAngerLevel: nil,
            isBundlePro: isBundlePro
        )
    }

    // ケース 1: デフォルトは isBundlePro = false
    @Test("default isBundlePro is false")
    func defaultBundleProIsFalse() {
        let context = SageContext(
            todayDrinkCount: 0,
            todayTotalAlcoholGram: 0,
            todayDidTrain: false,
            weekDrinkCount: 0,
            weekTrainingDays: 0,
            consecutiveDrinkingDays: 0,
            trainingGoal: .casual,
            latestAngerLevel: nil
        )
        #expect(context.isBundlePro == false)
    }

    // ケース 2: isBundlePro = true が正しく保持される
    @Test("isBundlePro=true is preserved")
    func bundleProTrueIsPreserved() {
        let context = makeContext(isBundlePro: true)
        #expect(context.isBundlePro == true)
    }

    // ケース 3: isBundlePro = false が正しく保持される
    @Test("isBundlePro=false is preserved")
    func bundleProFalseIsPreserved() {
        let context = makeContext(isBundlePro: false)
        #expect(context.isBundlePro == false)
    }

    // ケース 4: バンドルフラグはトレーニング状態と独立している
    @Test("isBundlePro is independent of training state")
    func bundleProIndependentOfTraining() {
        let withTraining = SageContext(
            todayDrinkCount: 0,
            todayTotalAlcoholGram: 0,
            todayDidTrain: true,
            weekDrinkCount: 0,
            weekTrainingDays: 5,
            consecutiveDrinkingDays: 0,
            trainingGoal: .bulk,
            latestAngerLevel: nil,
            isBundlePro: true
        )
        #expect(withTraining.isBundlePro == true)
        #expect(withTraining.todayDidTrain == true)
    }

    // ケース 5: 連続飲酒ストリーク状態でもバンドルフラグが保持される
    @Test("isBundlePro is preserved in streak context")
    func bundleProPreservedInStreak() {
        let context = SageContext(
            todayDrinkCount: 3,
            todayTotalAlcoholGram: 42.0,
            todayDidTrain: false,
            weekDrinkCount: 12,
            weekTrainingDays: 0,
            consecutiveDrinkingDays: 5,
            trainingGoal: .maintain,
            latestAngerLevel: 5,
            isBundlePro: true
        )
        #expect(context.isBundlePro == true)
        #expect(SagePromptBuilder.determineCategory(for: context) == .streak)
    }
}

// MARK: - SagePromptBuilder Bundle Branch Tests

@Suite("SagePromptBuilder bundle branch")
struct SagePromptBuilderBundleTests {

    private func makeContext(isBundlePro: Bool, drinkCount: Int = 2) -> SageContext {
        SageContext(
            todayDrinkCount: drinkCount,
            todayTotalAlcoholGram: Double(drinkCount) * 14.0,
            todayDidTrain: false,
            weekDrinkCount: drinkCount,
            weekTrainingDays: 1,
            consecutiveDrinkingDays: 1,
            trainingGoal: .maintain,
            latestAngerLevel: nil,
            isBundlePro: isBundlePro
        )
    }

    // バンドル分岐ケース 1: isBundlePro=false のときプロンプトに詳細モード行が含まれない
    @Test("no detailed mode line when isBundlePro=false")
    func noDetailedModeWhenBundleInactive() {
        let context = makeContext(isBundlePro: false)
        let prompt = SagePromptBuilder.buildPrompt(context: context)
        #expect(!prompt.contains("sage.llm.prompt.line.bundlePro.detailed"))
        // ローカライズ後の文字列でも確認（ja 環境では「詳細モード」が含まれないこと）
        #expect(!prompt.contains("詳細モード"))
        #expect(!prompt.contains("Detailed mode"))
    }

    // バンドル分岐ケース 2: isBundlePro=true のときプロンプトに詳細モード行が含まれる
    @Test("detailed mode line present when isBundlePro=true")
    func detailedModeLineWhenBundleActive() {
        let context = makeContext(isBundlePro: true)
        let prompt = SagePromptBuilder.buildPrompt(context: context)
        // ローカライズ文字列のどちらかが含まれることを確認
        let hasJaLine = prompt.contains("詳細モード")
        let hasEnLine = prompt.contains("Detailed mode")
        #expect(hasJaLine || hasEnLine)
    }

    // バンドル分岐ケース 3: カテゴリが異なっても詳細モード行の挿入は一貫している
    @Test("detailed mode line consistent across categories")
    func detailedModeLineConsistentAcrossCategories() {
        let categories: [(Int, Int, Int)] = [
            // (drinkCount, alcoholGram, consecutiveDays)
            (0, 0, 0),    // neutral
            (4, 56, 1),   // drankTooMuch
            (1, 14, 4),   // streak
        ]
        for (drinkCount, alcoholGram, consecutive) in categories {
            let context = SageContext(
                todayDrinkCount: drinkCount,
                todayTotalAlcoholGram: Double(alcoholGram),
                todayDidTrain: false,
                weekDrinkCount: drinkCount,
                weekTrainingDays: 0,
                consecutiveDrinkingDays: consecutive,
                trainingGoal: .maintain,
                latestAngerLevel: nil,
                isBundlePro: true
            )
            let prompt = SagePromptBuilder.buildPrompt(context: context)
            let hasDetailedLine = prompt.contains("詳細モード") || prompt.contains("Detailed mode")
            #expect(hasDetailedLine, "Expected detailed mode line in prompt for drinkCount=\(drinkCount)")
        }
    }

    // ケース 4: バンドル ON/OFF でプロンプト行数が変わる（詳細モード行の有無）
    @Test("bundle ON adds one more line to prompt")
    func bundleOnAddsOneLine() {
        let contextOff = makeContext(isBundlePro: false)
        let contextOn = makeContext(isBundlePro: true)
        let promptOff = SagePromptBuilder.buildPrompt(context: contextOff)
        let promptOn = SagePromptBuilder.buildPrompt(context: contextOn)
        let linesOff = promptOff.components(separatedBy: "\n").count
        let linesOn = promptOn.components(separatedBy: "\n").count
        // ON のほうが行数が多い（詳細モード行が追加されているため）
        #expect(linesOn > linesOff)
    }
}

// MARK: - AdMobConfig Bundle Guard Tests

@Suite("AdMobConfig bundle guard")
struct AdMobConfigBundleGuardTests {

    // ケース 1: isBundleActive=false では通常通り広告表示
    @Test("shows banner when bundle is inactive")
    func showsBannerWhenBundleInactive() {
        #expect(AdMobConfig.shouldShowBanner(for: .historyBottom, isBundleActive: false) == true)
        #expect(AdMobConfig.shouldShowBanner(for: .settingsBottom, isBundleActive: false) == true)
        #expect(AdMobConfig.shouldShowBanner(for: .sageInline, isBundleActive: false) == true)
    }

    // ケース 2: isBundleActive=true では全ての配置で広告非表示
    @Test("hides banner for all placements when bundle is active")
    func hidesBannerForAllPlacementsWhenBundleActive() {
        for placement in [AdPlacement.historyBottom, .settingsBottom, .sageInline] {
            #expect(
                AdMobConfig.shouldShowBanner(for: placement, isBundleActive: true) == false,
                "Expected banner to be hidden for placement \(placement) when bundle is active"
            )
        }
    }

    // ケース 3: デフォルト引数 isBundleActive=false は後方互換
    @Test("default isBundleActive=false maintains backward compatibility")
    func defaultBundleActiveIsFalse() {
        #expect(AdMobConfig.shouldShowBanner(for: .historyBottom) == true)
    }
}
