import Foundation
import Supabase

/// Liftly / Forge の両ソースからトレーニングデータを取得するサービス。
///
/// ## 設計概要
/// - `fetchTodayTraining(forceRefresh:)` が外部 API。内部で Liftly / Forge を `async let` 並列発火。
/// - 両ソースが揃ったら `UnifiedTrainingSnapshot` に組み立てて返す。
/// - 片方が失敗しても fail-soft でもう片方の結果を返す。
/// - `todaySnapshot` は後方互換 computed property として維持（旧呼び出し元が壊れない）。
///
/// ## linkStatus について
/// Supabase Auth を Liftly / Forge が共有するため、サインイン済み = 両ソース到達可能と仮定する。
/// Forge アカウント固有の連携判定が必要になった時点でここに追加すること。
/// TODO: Forge 側で独自アカウント連携 (forgeUserId != nil 等) が導入されたら
///       `linkedSources` の Forge 判定を更新する。
@MainActor
@Observable
final class TrainingDataService {

    // MARK: - Public State

    private(set) var linkStatus: TrainingLinkStatus = .notLinked
    private(set) var todayLiftlyPayload: LiftlyTrainingPayload?
    private(set) var todayForgePayload: ForgeTrainingPayload?
    private(set) var todayUnifiedSnapshot: UnifiedTrainingSnapshot?
    private(set) var isLoading: Bool = false

    // MARK: - 後方互換 API

    /// [Deprecated] 旧型 `TrainingSnapshot` を返す computed property。
    /// Liftly エントリが存在する場合のみ値を返す。
    /// 既存の呼び出し元（HomeView / SettingsView / DrinkEntryView / SageView）向け互換。
    var todaySnapshot: TrainingSnapshot? {
        guard let unified = todayUnifiedSnapshot else { return nil }
        return liftlySnapshot(from: unified)
    }

    // MARK: - Private

    private let client: SupabaseClient
    /// テスト用フック。nil のとき実 RPC を使う（本番デフォルト）。
    /// `fetchLiftlySummary` / `fetchForgeSummary` をオーバーライドするために使用。
    /// `@ObservationIgnored`: 監視不要（テスト専用、UI バインディング不要）。
    @ObservationIgnored
    var _fetchStrategyOverride: TrainingFetchStrategy?
    private var cachedDate: Date?

    init(client: SupabaseClient = SupabaseConfig.client) {
        self.client = client
    }

    /// テスト専用イニシャライザ。モック戦略を差し込むときに使う。
    init(fetchStrategy: TrainingFetchStrategy) {
        self.client = SupabaseConfig.client
        self._fetchStrategyOverride = fetchStrategy
        self.linkStatus = .linked
    }

    // MARK: - Public Methods

    /// 連携状態を更新（AuthService のログイン状態に連動）
    func updateLinkStatus(isSignedIn: Bool) {
        if isSignedIn {
            linkStatus = .linked
        } else {
            linkStatus = .notLinked
            todayLiftlyPayload = nil
            todayForgePayload = nil
            todayUnifiedSnapshot = nil
            cachedDate = nil
        }
    }

    /// 当日のトレーニングサマリーを Liftly / Forge 並列取得して返す。
    /// キャッシュがある場合はキャッシュを返す（同一日内）。
    /// 片方が失敗しても fail-soft でもう片方の結果を返す。
    @discardableResult
    func fetchTodayTraining(forceRefresh: Bool = false) async -> UnifiedTrainingSnapshot? {
        let today = DayBoundary.startOfToday()

        if !forceRefresh,
           let cached = todayUnifiedSnapshot,
           let cachedDate,
           cachedDate == today {
            return cached
        }

        guard case .linked = linkStatus else {
            return nil
        }

        isLoading = true
        defer { isLoading = false }

        // テスト用認証エラー注入: strategy が認証エラーを持つ場合は linkStatus に伝播
        if let strategy = _fetchStrategyOverride,
           let authError = strategy.authErrorToInject {
            linkStatus = .error(authError)
            return nil
        }

        // Liftly / Forge を並列発火
        async let liftlyResult = fetchLiftlySummary(for: today)
        async let forgeResult = fetchForgeSummary(for: today)

        let (liftlyPayload, forgePayload) = await (liftlyResult, forgeResult)

        // 両方 nil なら noTraining の unified snapshot を返す
        var entries: [TrainingEntry] = []

        if let lp = liftlyPayload {
            let entry = TrainingEntry.fromLiftly(
                payload: lp,
                startedAt: nil,
                endedAt: nil
            )
            entries.append(entry)
        }

        if let fp = forgePayload {
            let entry = TrainingEntry.fromForge(
                payload: fp,
                startedAt: nil,
                endedAt: nil
            )
            entries.append(entry)
        }

        // userId は Liftly ペイロードから取れないため空文字（既存挙動と同一）
        let unified = UnifiedTrainingSnapshot(
            userId: "",
            trainingDate: today,
            entries: entries
        )

        todayLiftlyPayload = liftlyPayload
        todayForgePayload = forgePayload
        todayUnifiedSnapshot = unified
        cachedDate = today
        return unified
    }

    /// 指定日の Liftly サマリーを取得する。
    /// 旧 `fetchTodayTraining` のコアロジックを切り出したもの。
    /// 認証エラー時は `linkStatus` を `.error` に更新しつつ nil を返す（fail-soft）。
    func fetchLiftlySummary(for dayStart: Date) async -> LiftlyTrainingPayload? {
        if let strategy = _fetchStrategyOverride {
            return await strategy.fetchLiftlySummary(for: dayStart)
        }
        do {
            let snapshot = try await fetchTrainingSummary(for: dayStart)
            if snapshot.hasTraining {
                return LiftlyTrainingPayload(
                    sessionCount: snapshot.sessionCount,
                    trainedBodyParts: snapshot.trainedBodyParts,
                    exerciseCount: snapshot.exerciseCount,
                    totalSets: snapshot.totalSets,
                    totalReps: snapshot.totalReps,
                    totalVolumeKG: snapshot.totalVolumeKG,
                    intensityLevel: snapshot.intensityLevel
                )
            } else {
                return nil
            }
        } catch let authError as TrainingFetchError {
            linkStatus = .error(authError.localizedDescription)
            return nil
        } catch {
            // ネットワーク等一時エラー: linkStatus は維持して nil を返す
            return nil
        }
    }

    /// 指定日の Forge サマリーを Supabase RPC `get_forge_training_summary` から取得する。
    /// 失敗時は nil を返す（fail-soft）。
    func fetchForgeSummary(for dayStart: Date) async -> ForgeTrainingPayload? {
        if let strategy = _fetchStrategyOverride {
            return await strategy.fetchForgeSummary(for: dayStart)
        }
        let calendar = Calendar.current
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }

        let startEpoch = Int(dayStart.timeIntervalSince1970)
        let endEpoch = Int(dayEnd.timeIntervalSince1970)

        let response: AnyJSON
        do {
            response = try await client.rpc(
                "get_forge_training_summary",
                params: ["start_epoch": startEpoch, "end_epoch": endEpoch]
            ).execute().value
        } catch {
            // RPC が未デプロイ or ネットワークエラー → Forge なしで続行
            return nil
        }

        // 認証エラーレスポンスを検出して linkStatus に伝播
        if let jsonDict = response.value as? [String: Any],
           let errorMsg = jsonDict["error"] as? String {
            linkStatus = .error(errorMsg)
            return nil
        }

        return parseForgeRPCResponse(response)
    }

    // MARK: - Liftly RPC (既存ロジック維持)

    /// 指定日のトレーニングサマリーを旧型 `TrainingSnapshot` で取得。
    /// 内部的には epoch 範囲版を優先し、未デプロイなら旧 DATE 版にフォールバック。
    func fetchTrainingSummary(for dayStart: Date) async throws -> TrainingSnapshot {
        if let snapshot = try await fetchWithEpochRange(dayStart: dayStart) {
            return snapshot
        }
        return try await fetchWithDateString(dayStart: dayStart)
    }

    // MARK: - Private: Liftly RPC 内部実装

    private func fetchWithEpochRange(dayStart: Date) async throws -> TrainingSnapshot? {
        let calendar = Calendar.current
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }

        let startEpoch = Int(dayStart.timeIntervalSince1970)
        let endEpoch = Int(dayEnd.timeIntervalSince1970)

        let response: AnyJSON
        do {
            response = try await client.rpc(
                "get_training_summary",
                params: ["start_epoch": startEpoch, "end_epoch": endEpoch]
            ).execute().value
        } catch {
            return nil
        }

        return try parseLiftlyRPCResponse(response, fallbackDate: dayStart)
    }

    private func fetchWithDateString(dayStart: Date) async throws -> TrainingSnapshot {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: dayStart)

        let response: AnyJSON = try await client.rpc(
            "get_training_summary",
            params: ["target_date": dateString]
        ).execute().value

        return try parseLiftlyRPCResponse(response, fallbackDate: dayStart) ?? .noTraining(for: dayStart)
    }

    private func parseLiftlyRPCResponse(_ response: AnyJSON, fallbackDate: Date) throws -> TrainingSnapshot? {
        guard let jsonDict = response.value as? [String: Any] else {
            return .noTraining(for: fallbackDate)
        }

        if let errorMsg = jsonDict["error"] as? String {
            throw TrainingFetchError.authenticationFailed(errorMsg)
        }

        return TrainingSnapshot(from: jsonDict)
    }

    // MARK: - Private: Forge RPC パース

    /// `get_forge_training_summary` RPC レスポンスを `ForgeTrainingPayload` に変換する。
    ///
    /// 期待レスポンス形式（仕様: Projects/Muscle360/2026-05-18-types-and-rpc-spec.md §3.2）:
    /// ```json
    /// {
    ///   "session_count": 2,
    ///   "session_types": ["crossfit_wod", "strength"],
    ///   "total_duration_seconds": 3600,
    ///   "average_rpe": 7.5,
    ///   "is_pr_session": false,
    ///   "benchmark_ids": ["fran"],
    ///   "intensity_level": "high",
    ///   "movements_summary": [
    ///     { "movement_name": "thruster", "total_reps": 45, "total_load_kg": null }
    ///   ]
    /// }
    /// ```
    private func parseForgeRPCResponse(_ response: AnyJSON) -> ForgeTrainingPayload? {
        guard let jsonDict = response.value as? [String: Any] else {
            return nil
        }

        // セッションなし → nil (noTraining 扱い)
        let sessionCount = parseIntFlexible(jsonDict["session_count"]) ?? 0
        guard sessionCount > 0 else { return nil }

        let sessionTypes = jsonDict["session_types"] as? [String] ?? []
        let totalDurationSeconds = parseIntFlexible(jsonDict["total_duration_seconds"]) ?? 0
        let averageRPE = parseDoubleFlexible(jsonDict["average_rpe"])
        let isPRSession = jsonDict["is_pr_session"] as? Bool ?? false
        let benchmarkIDs = jsonDict["benchmark_ids"] as? [String] ?? []

        let intensityLevel: IntensityLevel?
        if let levelStr = jsonDict["intensity_level"] as? String {
            intensityLevel = IntensityLevel(rawValue: levelStr)
        } else {
            intensityLevel = nil
        }

        let movementsSummary: [ForgeMovementCount]
        if let rawMovements = jsonDict["movements_summary"] as? [[String: Any]] {
            movementsSummary = rawMovements.compactMap { dict -> ForgeMovementCount? in
                guard let name = dict["movement_name"] as? String else { return nil }
                return ForgeMovementCount(
                    movementName: name,
                    totalReps: parseIntFlexible(dict["total_reps"]),
                    totalLoadKG: parseDoubleFlexible(dict["total_load_kg"])
                )
            }
        } else {
            movementsSummary = []
        }

        return ForgeTrainingPayload(
            sessionCount: sessionCount,
            sessionTypes: sessionTypes,
            totalDurationSeconds: totalDurationSeconds,
            averageRPE: averageRPE,
            isPRSession: isPRSession,
            benchmarkIDs: benchmarkIDs,
            intensityLevel: intensityLevel,
            movementsSummary: movementsSummary
        )
    }

    // MARK: - Private: 後方互換変換

    /// `UnifiedTrainingSnapshot` から Liftly エントリを探して旧 `TrainingSnapshot` に変換する。
    private func liftlySnapshot(from unified: UnifiedTrainingSnapshot) -> TrainingSnapshot? {
        guard let liftlyEntry = unified.entries.first(where: { $0.source == .liftly }),
              case .liftly(let payload) = liftlyEntry.payload else {
            // Liftly エントリがなければ noTraining
            return unified.hasTraining ? nil : .noTraining(for: unified.trainingDate)
        }

        let startAt = liftlyEntry.startedAt.map { Int($0.timeIntervalSince1970) }
        let endAt = liftlyEntry.endedAt.map { Int($0.timeIntervalSince1970) }

        return TrainingSnapshot(
            trainingDate: unified.trainingDate,
            sessionCount: payload.sessionCount,
            trainingStartAt: startAt,
            trainingEndAt: endAt,
            trainedBodyParts: payload.trainedBodyParts,
            exerciseCount: payload.exerciseCount,
            totalSets: payload.totalSets,
            totalReps: payload.totalReps,
            totalVolumeKG: payload.totalVolumeKG,
            intensityLevel: payload.intensityLevel
        )
    }

    // MARK: - Private: 数値パーサー（型揺れ吸収）

    private func parseIntFlexible(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let d = value as? Double { return Int(d) }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String { return Int(s) }
        return nil
    }

    private func parseDoubleFlexible(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    // MARK: - Cache

    func clearCache() {
        todayLiftlyPayload = nil
        todayForgePayload = nil
        todayUnifiedSnapshot = nil
        cachedDate = nil
    }
}

// MARK: - TrainingFetchError

enum TrainingFetchError: LocalizedError {
    case authenticationFailed(String)

    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let message):
            String(format: String(localized: "auth.error.format"), message)
        }
    }
}

// MARK: - TrainingFetchStrategy

/// テスト時に Supabase RPC 呼び出しを差し替えるためのプロトコル。
/// 本番コードでは `TrainingDataService` が直接 Supabase を呼ぶ。
/// テストでは `MockTrainingFetchStrategy` を注入する。
protocol TrainingFetchStrategy: Sendable {
    func fetchLiftlySummary(for dayStart: Date) async -> LiftlyTrainingPayload?
    func fetchForgeSummary(for dayStart: Date) async -> ForgeTrainingPayload?
    /// 認証エラー状態を注入するためのオプション。nil の場合は通常動作。
    /// テスト専用。本番実装では nil を返す。
    var authErrorToInject: String? { get }
}

extension TrainingFetchStrategy {
    /// デフォルト実装: 認証エラーなし。
    var authErrorToInject: String? { nil }
}
