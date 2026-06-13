import XCTest
@testable import SorryGains

/// `TrainingDataService` の統合テスト。
///
/// Supabase RPC 呼び出しを `MockTrainingFetchStrategy` でモックし、
/// 並列フェッチ・部分的成功・両方失敗の各シナリオを検証する。
///
/// 仕様: Projects/Muscle360/2026-05-18-types-and-rpc-spec.md §4 / §7.2
@MainActor
final class TrainingDataServiceTests: XCTestCase {

    // MARK: - ケース 1: 両方成功（Liftly + Forge 両方データあり）

    func testFetchTodayTraining_bothSucceed_buildsUnifiedSnapshot() async {
        // Arrange
        let liftlyPayload = makeLiftlyPayload()
        let forgePayload = makeForgePayload()
        let strategy = MockTrainingFetchStrategy(liftlyResult: liftlyPayload, forgeResult: forgePayload)
        let sut = TrainingDataService(fetchStrategy: strategy)

        // Act
        let snapshot = await sut.fetchTodayTraining()

        // Assert
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.sources, [.liftly, .forge])
        XCTAssertEqual(snapshot?.entries.count, 2)
        XCTAssertNotNil(sut.todayLiftlyPayload)
        XCTAssertNotNil(sut.todayForgePayload)
        XCTAssertNotNil(sut.todayUnifiedSnapshot)
        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - ケース 2: Forge 失敗・Liftly 成功（部分的成功）

    func testFetchTodayTraining_forgeFailsLiftlySucceeds_returnsLiftlyOnlySnapshot() async {
        // Arrange
        let liftlyPayload = makeLiftlyPayload()
        let strategy = MockTrainingFetchStrategy(liftlyResult: liftlyPayload, forgeResult: nil)
        let sut = TrainingDataService(fetchStrategy: strategy)

        // Act
        let snapshot = await sut.fetchTodayTraining()

        // Assert
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.sources, [.liftly])
        XCTAssertEqual(snapshot?.entries.count, 1)
        XCTAssertEqual(snapshot?.entries.first?.source, .liftly)
        XCTAssertNotNil(sut.todayLiftlyPayload)
        XCTAssertNil(sut.todayForgePayload)
        // linkStatus はエラーにならない（ネットワーク系エラーは linkStatus を維持）
        XCTAssertEqual(sut.linkStatus, .linked)
    }

    // MARK: - ケース 3: Liftly 失敗・Forge 成功（部分的成功）

    func testFetchTodayTraining_liftlyFailsForgeSucceeds_returnsForgeOnlySnapshot() async {
        // Arrange
        let forgePayload = makeForgePayload()
        let strategy = MockTrainingFetchStrategy(liftlyResult: nil, forgeResult: forgePayload)
        let sut = TrainingDataService(fetchStrategy: strategy)

        // Act
        let snapshot = await sut.fetchTodayTraining()

        // Assert
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.sources, [.forge])
        XCTAssertEqual(snapshot?.entries.count, 1)
        XCTAssertEqual(snapshot?.entries.first?.source, .forge)
        XCTAssertNil(sut.todayLiftlyPayload)
        XCTAssertNotNil(sut.todayForgePayload)
    }

    // MARK: - ケース 4: 両方ネットワークエラー（空 Snapshot でアプリ継続）

    func testFetchTodayTraining_bothFail_returnsEmptySnapshotAndAppContinues() async {
        // Arrange
        let strategy = MockTrainingFetchStrategy(liftlyResult: nil, forgeResult: nil)
        let sut = TrainingDataService(fetchStrategy: strategy)

        // Act
        let snapshot = await sut.fetchTodayTraining()

        // Assert: 空 Snapshot が返り、アプリはクラッシュしない
        XCTAssertNotNil(snapshot, "両方失敗時も nil ではなく空 Snapshot を返すこと")
        XCTAssertFalse(snapshot!.hasTraining)
        XCTAssertTrue(snapshot!.entries.isEmpty)
        XCTAssertNil(sut.todayLiftlyPayload)
        XCTAssertNil(sut.todayForgePayload)
        // linkStatus はネットワークエラーのため変化しない
        XCTAssertEqual(sut.linkStatus, .linked)
    }

    // MARK: - ケース 5: linkStatus が .notLinked のとき fetchTodayTraining は nil を返す

    func testFetchTodayTraining_notLinked_returnsNilWithoutFetching() async {
        // Arrange
        let strategy = MockTrainingFetchStrategy(liftlyResult: makeLiftlyPayload(), forgeResult: makeForgePayload())
        let sut = TrainingDataService(fetchStrategy: strategy)
        sut.updateLinkStatus(isSignedIn: false) // .notLinked に設定

        // Act
        let snapshot = await sut.fetchTodayTraining()

        // Assert: 未ログイン状態では nil を返し、フェッチも呼ばれない
        XCTAssertNil(snapshot)
        XCTAssertEqual(strategy.liftlyFetchCallCount, 0, "未リンク時はフェッチが呼ばれないこと")
        XCTAssertEqual(strategy.forgeFetchCallCount, 0, "未リンク時はフェッチが呼ばれないこと")
    }

    // MARK: - ケース 6: キャッシュ機能（同日は再フェッチしない）

    func testFetchTodayTraining_sameDay_returnsCachedSnapshot() async {
        // Arrange
        let liftlyPayload = makeLiftlyPayload()
        let strategy = MockTrainingFetchStrategy(liftlyResult: liftlyPayload, forgeResult: nil)
        let sut = TrainingDataService(fetchStrategy: strategy)

        // Act: 1 回目
        let first = await sut.fetchTodayTraining()
        // Act: 2 回目（キャッシュが効く）
        let second = await sut.fetchTodayTraining()

        // Assert: 同じ snapshot が返り、フェッチは 1 回だけ
        XCTAssertEqual(first, second)
        XCTAssertEqual(strategy.liftlyFetchCallCount, 1, "キャッシュが効いていればフェッチは 1 回のみ")
    }

    // MARK: - ケース 7: forceRefresh でキャッシュを無視する

    func testFetchTodayTraining_forceRefresh_bypassesCache() async {
        // Arrange
        let liftlyPayload = makeLiftlyPayload()
        let strategy = MockTrainingFetchStrategy(liftlyResult: liftlyPayload, forgeResult: nil)
        let sut = TrainingDataService(fetchStrategy: strategy)

        // Act
        _ = await sut.fetchTodayTraining()
        _ = await sut.fetchTodayTraining(forceRefresh: true)

        // Assert: forceRefresh なので 2 回フェッチされる
        XCTAssertEqual(strategy.liftlyFetchCallCount, 2)
    }

    // MARK: - ケース 8: todaySnapshot 後方互換 computed property

    func testTodaySnapshot_liftlyDataPresent_returnsLegacySnapshot() async {
        // Arrange
        let liftlyPayload = makeLiftlyPayload(volumeKG: 2000)
        let strategy = MockTrainingFetchStrategy(liftlyResult: liftlyPayload, forgeResult: nil)
        let sut = TrainingDataService(fetchStrategy: strategy)

        // Act
        await sut.fetchTodayTraining()
        let legacySnapshot = sut.todaySnapshot

        // Assert: 後方互換 API が動作する
        XCTAssertNotNil(legacySnapshot)
        XCTAssertEqual(legacySnapshot?.totalVolumeKG, 2000)
    }

    // MARK: - ケース 9: updateLinkStatus が notLinked になるとキャッシュがクリアされる

    func testUpdateLinkStatus_signedOut_clearsAllCachedData() async {
        // Arrange
        let strategy = MockTrainingFetchStrategy(liftlyResult: makeLiftlyPayload(), forgeResult: makeForgePayload())
        let sut = TrainingDataService(fetchStrategy: strategy)
        _ = await sut.fetchTodayTraining()
        XCTAssertNotNil(sut.todayUnifiedSnapshot)

        // Act
        sut.updateLinkStatus(isSignedIn: false)

        // Assert
        XCTAssertNil(sut.todayUnifiedSnapshot)
        XCTAssertNil(sut.todayLiftlyPayload)
        XCTAssertNil(sut.todayForgePayload)
        XCTAssertEqual(sut.linkStatus, .notLinked)
    }

    // MARK: - ケース 10: 両認証エラー → linkStatus が .error に遷移

    func testFetchTodayTraining_bothAuthError_setsLinkStatusError() async {
        // Arrange
        let strategy = MockTrainingFetchStrategy(
            liftlyResult: nil,
            forgeResult: nil,
            authError: "not_authenticated"
        )
        let sut = TrainingDataService(fetchStrategy: strategy)

        // Act
        let snapshot = await sut.fetchTodayTraining()

        // Assert: 認証エラーなら linkStatus が .error になり nil を返す
        XCTAssertNil(snapshot, "認証エラー時は nil を返すこと")
        if case .error(let msg) = sut.linkStatus {
            XCTAssertFalse(msg.isEmpty, "エラーメッセージが空でないこと")
        } else {
            XCTFail("linkStatus が .error でなく \(sut.linkStatus) になっている")
        }
    }

    // MARK: - ケース 11: Forge 単独認証エラー → linkStatus が .error に遷移
    // 注: 現実装では strategy レベルで全体の authErrorToInject を使うため、
    //     「Forge のみ認証エラー」はサービス内部の fetchForgeSummary パスで処理される。
    //     ここでは実際の fetchForgeSummary が authError を返す場合のモデルテストとして、
    //     両方エラーと同様に strategy 経由で検証する。
    func testFetchTodayTraining_forgeAuthError_setsLinkStatusError() async {
        // Arrange: Forge 認証エラーを模倣（strategy 全体で注入）
        let strategy = MockTrainingFetchStrategy(
            liftlyResult: nil,
            forgeResult: nil,
            authError: "forge_not_authenticated"
        )
        let sut = TrainingDataService(fetchStrategy: strategy)

        // Act
        let snapshot = await sut.fetchTodayTraining()

        // Assert
        XCTAssertNil(snapshot)
        guard case .error = sut.linkStatus else {
            XCTFail("linkStatus が .error でなく \(sut.linkStatus) になっている")
            return
        }
    }

    // MARK: - Helpers

    private func makeLiftlyPayload(volumeKG: Double = 1500) -> LiftlyTrainingPayload {
        LiftlyTrainingPayload(
            sessionCount: 1,
            trainedBodyParts: ["chest", "shoulders"],
            exerciseCount: 4,
            totalSets: 12,
            totalReps: 80,
            totalVolumeKG: volumeKG,
            intensityLevel: .medium
        )
    }

    private func makeForgePayload() -> ForgeTrainingPayload {
        ForgeTrainingPayload(
            sessionCount: 1,
            sessionTypes: ["crossfit_wod"],
            totalDurationSeconds: 2400,
            averageRPE: 8.0,
            isPRSession: false,
            benchmarkIDs: [],
            intensityLevel: .high,
            movementsSummary: [
                ForgeMovementCount(movementName: "thruster", totalReps: 21, totalLoadKG: nil)
            ]
        )
    }
}

// MARK: - MockTrainingFetchStrategy

/// テスト用 `TrainingFetchStrategy` 実装。
/// 各フェッチメソッドの返却値を事前に指定し、呼び出し回数もカウントする。
/// `authError` を設定すると `authErrorToInject` 経由で認証エラーを注入できる。
final class MockTrainingFetchStrategy: TrainingFetchStrategy, @unchecked Sendable {

    private let liftlyStubResult: LiftlyTrainingPayload?
    private let forgeStubResult: ForgeTrainingPayload?
    let authErrorToInject: String?

    private(set) var liftlyFetchCallCount = 0
    private(set) var forgeFetchCallCount = 0

    init(
        liftlyResult: LiftlyTrainingPayload?,
        forgeResult: ForgeTrainingPayload?,
        authError: String? = nil
    ) {
        self.liftlyStubResult = liftlyResult
        self.forgeStubResult = forgeResult
        self.authErrorToInject = authError
    }

    func fetchLiftlySummary(for dayStart: Date) async -> LiftlyTrainingPayload? {
        liftlyFetchCallCount += 1
        return liftlyStubResult
    }

    func fetchForgeSummary(for dayStart: Date) async -> ForgeTrainingPayload? {
        forgeFetchCallCount += 1
        return forgeStubResult
    }
}
