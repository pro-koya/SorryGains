import XCTest
@testable import SorryGains

/// `FoundationModelsSageAdviceProvider` のプロンプト構築ロジックのユニットテスト。
///
/// FoundationModels API（iOS 26+）の実際の出力は検証しない。
/// 「入力プロンプトに正しい情報行が含まれているか」を assert する形で検証する。
///
/// 仕様: Projects/Muscle360/2026-05-18-types-and-rpc-spec.md §5.2 / §7.1 / §7.3
final class FoundationModelsSageAdviceProviderTests: XCTestCase {

    // MARK: - §7.1 SageContext 新 init from UnifiedSnapshot — 5 ケース

    /// ケース 1: Liftly のみ連携 → isLiftlyLinked = true, isForgeLinked = false
    func testSageContext_fromLiftlyOnlySnapshot_hasCorrectSources() {
        let snapshot = makeUnifiedSnapshot(liftly: makeLiftlyPayload(), forge: nil)
        let context = makeSageContext(snapshot: snapshot)

        XCTAssertTrue(context.isLiftlyLinked)
        XCTAssertFalse(context.isForgeLinked)
        XCTAssertTrue(context.hasAnyLinkedSource)
        XCTAssertEqual(context.linkedSources, [.liftly])
    }

    /// ケース 2: Forge のみ連携 → isForgeLinked = true, isLiftlyLinked = false
    func testSageContext_fromForgeOnlySnapshot_hasCorrectSources() {
        let snapshot = makeUnifiedSnapshot(liftly: nil, forge: makeForgePayload())
        let context = makeSageContext(snapshot: snapshot)

        XCTAssertFalse(context.isLiftlyLinked)
        XCTAssertTrue(context.isForgeLinked)
        XCTAssertTrue(context.hasAnyLinkedSource)
        XCTAssertEqual(context.linkedSources, [.forge])
    }

    /// ケース 3: Liftly + Forge 両方 → 両方 linked
    func testSageContext_fromBothSources_hasBothLinked() {
        let snapshot = makeUnifiedSnapshot(liftly: makeLiftlyPayload(), forge: makeForgePayload())
        let context = makeSageContext(snapshot: snapshot)

        XCTAssertTrue(context.isLiftlyLinked)
        XCTAssertTrue(context.isForgeLinked)
        XCTAssertEqual(context.linkedSources, [.liftly, .forge])
    }

    /// ケース 4: トレーニングなし → linkedSources が空
    func testSageContext_fromEmptySnapshot_hasNoLinkedSources() {
        let snapshot = UnifiedTrainingSnapshot.empty(for: Date())
        let context = makeSageContext(snapshot: snapshot)

        XCTAssertFalse(context.hasAnyLinkedSource)
        XCTAssertTrue(context.linkedSources.isEmpty)
        XCTAssertTrue(context.trainedDomains.isEmpty)
        XCTAssertFalse(context.forgeIsPRDay)
        XCTAssertTrue(context.forgeBenchmarkIDs.isEmpty)
    }

    /// ケース 5: Forge PR セッション → forgeIsPRDay = true, forgeBenchmarkIDs が正しい
    func testSageContext_fromForgePRSnapshot_hasPRDayAndBenchmarks() {
        let forgePayload = ForgeTrainingPayload(
            sessionCount: 1,
            sessionTypes: ["benchmark"],
            totalDurationSeconds: 900,
            averageRPE: 9.5,
            isPRSession: true,
            benchmarkIDs: ["fran", "grace"],
            intensityLevel: .high,
            movementsSummary: []
        )
        let snapshot = makeUnifiedSnapshot(liftly: nil, forge: forgePayload)
        let context = makeSageContext(snapshot: snapshot)

        XCTAssertTrue(context.forgeIsPRDay)
        XCTAssertEqual(context.forgeBenchmarkIDs, ["fran", "grace"])
        XCTAssertEqual(context.forgeAverageRPE, 9.5)
    }

    // MARK: - §5.2 プロンプト分岐テスト

    /// Liftly のみ → body parts / intensity 行が含まれ、Forge 行が含まれない
    func testBuildPrompt_liftlyOnly_containsLiftlyLinesNotForgeLines() {
        let snapshot = makeUnifiedSnapshot(liftly: makeLiftlyPayload(), forge: nil)
        let context = makeSageContext(snapshot: snapshot, drinkCount: 0)
        let prompt = buildPrompt(for: context)

        XCTAssertTrue(
            prompt.contains("chest") || prompt.contains("胸") || prompt.contains("shoulders") || prompt.contains("肩"),
            "Liftly body parts が含まれること: \(prompt)"
        )
        XCTAssertFalse(
            prompt.contains("RPE") || prompt.contains("rpe"),
            "Forge RPE 行が含まれないこと"
        )
        XCTAssertFalse(
            prompt.contains("PR") && prompt.contains("セッション"),
            "Forge PR Day 行が含まれないこと"
        )
    }

    /// `hasAnyLinkedSource` が false のとき — body parts 行が含まれない
    func testBuildPrompt_noLinkedSource_noTrainingLines() {
        let context = makeSageContext(snapshot: nil, drinkCount: 3, consecutiveDrinkingDays: 3)
        let prompt = buildPrompt(for: context)

        XCTAssertFalse(
            prompt.contains("body parts") || prompt.contains("鍛えた部位"),
            "未連携時 body parts 行が含まれないこと"
        )
        XCTAssertFalse(
            prompt.contains("RPE"),
            "未連携時 RPE 行が含まれないこと"
        )
    }

    /// trainedDomains が非空 → domains 行が含まれる
    func testBuildPrompt_withTrainedDomains_containsDomainsLine() {
        let forgePayload = makeForgePayload(sessionTypes: ["crossfit_wod"], rpe: 7.5)
        let snapshot = makeUnifiedSnapshot(liftly: nil, forge: forgePayload)
        let context = makeSageContext(snapshot: snapshot)
        let prompt = buildPrompt(for: context)

        XCTAssertTrue(
            prompt.contains("CrossFit") || prompt.contains("クロスフィット"),
            "domains 行にドメイン名が含まれること: \(prompt)"
        )
    }

    /// Forge RPE あり → RPE 行が含まれる
    func testBuildPrompt_withForgeRPE_containsRPELine() {
        let forgePayload = makeForgePayload(rpe: 8.5)
        let snapshot = makeUnifiedSnapshot(liftly: nil, forge: forgePayload)
        let context = makeSageContext(snapshot: snapshot)
        let prompt = buildPrompt(for: context)

        XCTAssertTrue(
            prompt.contains("RPE") || prompt.contains("8.5"),
            "RPE 行が含まれること: \(prompt)"
        )
    }

    /// Forge PR Day → prDay 行が含まれる
    func testBuildPrompt_withForgePRDay_containsPRLine() {
        let forgePayload = ForgeTrainingPayload(
            sessionCount: 1,
            sessionTypes: ["benchmark"],
            totalDurationSeconds: 600,
            averageRPE: 9.0,
            isPRSession: true,
            benchmarkIDs: [],
            intensityLevel: .high,
            movementsSummary: []
        )
        let snapshot = makeUnifiedSnapshot(liftly: nil, forge: forgePayload)
        let context = makeSageContext(snapshot: snapshot)
        let prompt = buildPrompt(for: context)

        XCTAssertTrue(
            prompt.contains("PR"),
            "PR Day 行が含まれること: \(prompt)"
        )
    }

    /// Forge benchmarks あり → benchmarks 行が含まれる
    func testBuildPrompt_withForgeBenchmarks_containsBenchmarksLine() {
        let forgePayload = ForgeTrainingPayload(
            sessionCount: 1,
            sessionTypes: ["benchmark"],
            totalDurationSeconds: 600,
            averageRPE: nil,
            isPRSession: false,
            benchmarkIDs: ["fran"],
            intensityLevel: .high,
            movementsSummary: []
        )
        let snapshot = makeUnifiedSnapshot(liftly: nil, forge: forgePayload)
        let context = makeSageContext(snapshot: snapshot)
        let prompt = buildPrompt(for: context)

        XCTAssertTrue(
            prompt.contains("fran"),
            "benchmarks 行に benchmark 名が含まれること: \(prompt)"
        )
    }

    // MARK: - §7.3 5 パターンのスナップショットテスト

    /// パターン 1: Liftly のみ（重量トレ）+ 飲酒なし
    /// → Liftly 系の行が含まれ、Forge 系の行が含まれない
    func testPromptPattern1_liftlyOnlyNoDrink() {
        let snapshot = makeUnifiedSnapshot(liftly: makeLiftlyPayload(), forge: nil)
        let context = makeSageContext(snapshot: snapshot, drinkCount: 0, alcoholGram: 0)
        let prompt = buildPrompt(for: context)

        // Liftly 由来の情報が含まれること
        XCTAssertTrue(
            prompt.contains("chest") || prompt.contains("shoulders") ||
            prompt.contains("body parts") || prompt.contains("鍛えた部位"),
            "Liftly 系の行が含まれること: \(prompt)"
        )
        // Forge 固有情報は含まれないこと
        XCTAssertFalse(
            prompt.contains("RPE"),
            "Forge RPE 行が含まれないこと (パターン1): \(prompt)"
        )
        XCTAssertFalse(
            prompt.contains("Benchmark WOD") || prompt.contains("ベンチマーク WOD"),
            "benchmarks 行が含まれないこと (パターン1)"
        )
    }

    /// パターン 2: Forge のみ（CrossFit WOD）+ 軽飲酒
    /// → Forge 系の行（domains, rpe あれば）が含まれ、Liftly 系の重量パートが含まれない
    func testPromptPattern2_forgeOnlyCrossFitLightDrink() {
        let forgePayload = makeForgePayload(sessionTypes: ["crossfit_wod"], rpe: 7.0)
        let snapshot = makeUnifiedSnapshot(liftly: nil, forge: forgePayload)
        let context = makeSageContext(snapshot: snapshot, drinkCount: 1, alcoholGram: 14)
        let prompt = buildPrompt(for: context)

        // Forge ドメイン行が含まれること
        XCTAssertTrue(
            prompt.contains("CrossFit") || prompt.contains("クロスフィット"),
            "Forge CrossFit ドメイン行が含まれること (パターン2): \(prompt)"
        )
        // RPE 行が含まれること
        XCTAssertTrue(
            prompt.contains("RPE") || prompt.contains("7.0"),
            "RPE 行が含まれること (パターン2): \(prompt)"
        )
    }

    /// パターン 3: Forge Hyrox レース + PR 達成 + 飲酒なし
    /// → prDay 行と benchmarks 行が含まれる
    func testPromptPattern3_forgeHyroxPRNoDrink() {
        let forgePayload = ForgeTrainingPayload(
            sessionCount: 1,
            sessionTypes: ["hyrox_race"],
            totalDurationSeconds: 4500,
            averageRPE: 9.0,
            isPRSession: true,
            benchmarkIDs: ["hyrox_open"],
            intensityLevel: .high,
            movementsSummary: []
        )
        let snapshot = makeUnifiedSnapshot(liftly: nil, forge: forgePayload)
        let context = makeSageContext(snapshot: snapshot, drinkCount: 0, alcoholGram: 0)
        let prompt = buildPrompt(for: context)

        XCTAssertTrue(
            prompt.contains("PR"),
            "PR Day 行が含まれること (パターン3): \(prompt)"
        )
        XCTAssertTrue(
            prompt.contains("hyrox_open"),
            "benchmarks 行が含まれること (パターン3): \(prompt)"
        )
    }

    /// パターン 4: Liftly + Forge 両方（合宿日）+ 重飲酒
    /// → 両方の行が含まれる
    func testPromptPattern4_bothSourcesHeavyDrink() {
        let liftlyPayload = makeLiftlyPayload()
        let forgePayload = makeForgePayload(sessionTypes: ["crossfit_wod"], rpe: 8.0)
        let snapshot = makeUnifiedSnapshot(liftly: liftlyPayload, forge: forgePayload)
        let context = makeSageContext(snapshot: snapshot, drinkCount: 5, alcoholGram: 70)
        let prompt = buildPrompt(for: context)

        // Liftly 由来
        XCTAssertTrue(
            prompt.contains("chest") || prompt.contains("shoulders") ||
            prompt.contains("body parts") || prompt.contains("鍛えた部位"),
            "Liftly 系の行が含まれること (パターン4): \(prompt)"
        )
        // Forge 由来
        XCTAssertTrue(
            prompt.contains("CrossFit") || prompt.contains("クロスフィット") ||
            prompt.contains("RPE") || prompt.contains("8.0"),
            "Forge 系の行が含まれること (パターン4): \(prompt)"
        )
    }

    /// パターン 5: トレーニングなし + 連続飲酒3日
    /// → トレーニング系の行が一切含まれない
    func testPromptPattern5_noTrainingConsecutiveDrinking() {
        let context = makeSageContext(
            snapshot: nil,
            drinkCount: 2,
            alcoholGram: 28,
            consecutiveDrinkingDays: 3
        )
        let prompt = buildPrompt(for: context)

        XCTAssertFalse(
            prompt.contains("body parts") || prompt.contains("鍛えた部位"),
            "body parts 行が含まれないこと (パターン5): \(prompt)"
        )
        XCTAssertFalse(
            prompt.contains("RPE"),
            "RPE 行が含まれないこと (パターン5): \(prompt)"
        )
        XCTAssertFalse(
            prompt.contains("CrossFit") || prompt.contains("Hyrox") || prompt.contains("Strength"),
            "ドメイン行が含まれないこと (パターン5): \(prompt)"
        )
        XCTAssertFalse(
            prompt.contains("PR"),
            "PR Day 行が含まれないこと (パターン5): \(prompt)"
        )
    }

    // MARK: - Localizable keys 挿入テスト

    /// domains localized key が正しく挿入されること
    func testLocalizedDomainsKey_insertsInPrompt() {
        let forgePayload = makeForgePayload(sessionTypes: ["hyrox_race"])
        let snapshot = makeUnifiedSnapshot(liftly: nil, forge: forgePayload)
        let context = makeSageContext(snapshot: snapshot)
        let prompt = buildPrompt(for: context)

        XCTAssertTrue(
            prompt.contains("Hyrox") || prompt.contains("ハイロックス"),
            "Hyrox ドメインが prompt に含まれること: \(prompt)"
        )
    }

    /// Forge RPE が nil のとき RPE 行が含まれないこと
    func testBuildPrompt_forgeWithNilRPE_noRPELine() {
        let forgePayload = ForgeTrainingPayload(
            sessionCount: 1,
            sessionTypes: ["crossfit_wod"],
            totalDurationSeconds: 1800,
            averageRPE: nil,
            isPRSession: false,
            benchmarkIDs: [],
            intensityLevel: .medium,
            movementsSummary: []
        )
        let snapshot = makeUnifiedSnapshot(liftly: nil, forge: forgePayload)
        let context = makeSageContext(snapshot: snapshot)
        let prompt = buildPrompt(for: context)

        XCTAssertFalse(
            prompt.contains("RPE"),
            "RPE が nil のとき RPE 行が含まれないこと: \(prompt)"
        )
    }

    // MARK: - isLiftlyLinked 後方互換

    /// LiftlyLinkStatus typealias が TrainingLinkStatus として機能すること
    func testLiftlyLinkStatusTypealias_isCompatibleWithTrainingLinkStatus() {
        let status1: LiftlyLinkStatus = .linked
        let status2: TrainingLinkStatus = .linked
        XCTAssertEqual(status1, status2)

        let errorStatus: LiftlyLinkStatus = .error("test")
        if case .error(let msg) = errorStatus {
            XCTAssertEqual(msg, "test")
        } else {
            XCTFail("LiftlyLinkStatus.error typealias が動作しないこと")
        }
    }

    /// isLiftlyLinked computed property が linkedSources から正しく導出されること
    func testIsLiftlyLinked_derivedFromLinkedSources() {
        let liftlyOnly = makeUnifiedSnapshot(liftly: makeLiftlyPayload(), forge: nil)
        let liftlyContext = makeSageContext(snapshot: liftlyOnly)
        XCTAssertTrue(liftlyContext.isLiftlyLinked)

        let forgeOnly = makeUnifiedSnapshot(liftly: nil, forge: makeForgePayload())
        let forgeContext = makeSageContext(snapshot: forgeOnly)
        XCTAssertFalse(forgeContext.isLiftlyLinked)

        let emptyContext = makeSageContext(snapshot: nil)
        XCTAssertFalse(emptyContext.isLiftlyLinked)
    }
}

// MARK: - Helpers

private extension FoundationModelsSageAdviceProviderTests {

    /// プロンプト構築を直接テスト可能にするためのヘルパー。
    /// `SagePromptBuilder`（internal）を @testable import で呼び出す。
    func buildPrompt(for context: SageContext) -> String {
        SagePromptBuilder.buildPrompt(context: context)
    }

    func makeUnifiedSnapshot(
        liftly: LiftlyTrainingPayload?,
        forge: ForgeTrainingPayload?
    ) -> UnifiedTrainingSnapshot {
        var entries: [TrainingEntry] = []
        if let lp = liftly {
            entries.append(TrainingEntry.fromLiftly(payload: lp, startedAt: nil, endedAt: nil))
        }
        if let fp = forge {
            entries.append(TrainingEntry.fromForge(payload: fp, startedAt: nil, endedAt: nil))
        }
        return UnifiedTrainingSnapshot(userId: "test", trainingDate: Date(), entries: entries)
    }

    func makeSageContext(
        snapshot: UnifiedTrainingSnapshot?,
        drinkCount: Int = 1,
        alcoholGram: Double = 14,
        consecutiveDrinkingDays: Int = 1
    ) -> SageContext {
        SageContext(
            todayDrinkCount: drinkCount,
            todayTotalAlcoholGram: alcoholGram,
            todayDidTrain: snapshot?.hasTraining ?? false,
            weekDrinkCount: drinkCount,
            weekTrainingDays: snapshot?.hasTraining == true ? 1 : 0,
            consecutiveDrinkingDays: consecutiveDrinkingDays,
            trainingGoal: .maintain,
            latestAngerLevel: nil,
            unifiedSnapshot: snapshot
        )
    }

    func makeLiftlyPayload() -> LiftlyTrainingPayload {
        LiftlyTrainingPayload(
            sessionCount: 1,
            trainedBodyParts: ["chest", "shoulders"],
            exerciseCount: 4,
            totalSets: 12,
            totalReps: 80,
            totalVolumeKG: 1500,
            intensityLevel: .medium
        )
    }

    func makeForgePayload(
        sessionTypes: [String] = ["crossfit_wod"],
        rpe: Double? = 7.5
    ) -> ForgeTrainingPayload {
        ForgeTrainingPayload(
            sessionCount: 1,
            sessionTypes: sessionTypes,
            totalDurationSeconds: 2400,
            averageRPE: rpe,
            isPRSession: false,
            benchmarkIDs: [],
            intensityLevel: .high,
            movementsSummary: []
        )
    }
}
