import Foundation

/// 仙人が助言を生成するために必要なコンテキスト。
///
/// Muscle360 統合論理モデル対応版。
/// 既存 API (`isLiftlyLinked`, `trainedBodyParts`, `trainingIntensity` 等) は
/// computed property または stored property としてそのまま残し、後方互換を維持する。
///
/// 仕様: Projects/Muscle360/2026-05-18-types-and-rpc-spec.md §2.8
struct SageContext: Sendable {
    // MARK: - 既存フィールド（変更なし）

    let todayDrinkCount: Int
    let todayTotalAlcoholGram: Double
    let todayDidTrain: Bool
    let weekDrinkCount: Int
    let weekTrainingDays: Int
    let consecutiveDrinkingDays: Int
    let trainingGoal: TrainingGoal
    let latestAngerLevel: Int?

    // MARK: - 既存フィールド（互換維持。値は unifiedSnapshot から導出）

    /// トレーニングした部位（Liftly + Forge 由来の統合配列）。連携なしのときは nil
    let trainedBodyParts: [String]?

    /// トレーニング強度の集約値（複数ソースの max）
    let trainingIntensity: IntensityLevel?

    /// トレーニング総ボリューム kg（Liftly のみ反映。Forge には volume 概念がないため）
    let trainingVolumeKG: Double?

    /// トレ後からの経過時間
    let hoursSinceTraining: Double?

    // MARK: - バンドルフラグ (Phase 2-2)

    /// Muscle360 Pro バンドル加入中かどうか。
    /// true のとき仙人助言が詳細モードになる。
    let isBundlePro: Bool

    // MARK: - 新規フィールド (Muscle360 統合)

    /// 連携済みソース。Liftly のみ / Forge のみ / 両方 を識別可能
    let linkedSources: Set<TrainingSource>

    /// トレーニングのドメイン（強度・部位より抽象度の高い分類）
    let trainedDomains: Set<TrainingDomain>

    /// Forge 平均 RPE（1-10）。Forge 連携なし or RPE 未入力のみのときは nil
    let forgeAverageRPE: Double?

    /// 当日 Forge セッションで PR 達成があったか
    let forgeIsPRDay: Bool

    /// 当日叩いた Forge ベンチマーク識別子（"fran", "murph" 等）
    let forgeBenchmarkIDs: [String]

    // MARK: - 後方互換 computed API

    /// [既存 API] Liftly 連携済みかどうか。
    /// 内部実装は `linkedSources` に差し替えたが、外部から見ると挙動は変わらない。
    var isLiftlyLinked: Bool { linkedSources.contains(.liftly) }

    /// [新規 API] Forge 連携済みかどうか。
    var isForgeLinked: Bool { linkedSources.contains(.forge) }

    /// [新規 API] 何らかのソースが繋がっているか。
    var hasAnyLinkedSource: Bool { !linkedSources.isEmpty }

    // MARK: - 新規 init: UnifiedTrainingSnapshot から構築

    init(
        todayDrinkCount: Int,
        todayTotalAlcoholGram: Double,
        todayDidTrain: Bool,
        weekDrinkCount: Int,
        weekTrainingDays: Int,
        consecutiveDrinkingDays: Int,
        trainingGoal: TrainingGoal,
        latestAngerLevel: Int?,
        isBundlePro: Bool = false,
        unifiedSnapshot: UnifiedTrainingSnapshot? = nil
    ) {
        self.todayDrinkCount = todayDrinkCount
        self.todayTotalAlcoholGram = todayTotalAlcoholGram
        self.todayDidTrain = todayDidTrain
        self.weekDrinkCount = weekDrinkCount
        self.weekTrainingDays = weekTrainingDays
        self.consecutiveDrinkingDays = consecutiveDrinkingDays
        self.trainingGoal = trainingGoal
        self.latestAngerLevel = latestAngerLevel
        self.isBundlePro = isBundlePro

        if let snapshot = unifiedSnapshot, snapshot.hasTraining {
            self.linkedSources = snapshot.sources
            self.trainedDomains = snapshot.trainedDomains
            let aggregatedParts = snapshot.aggregatedBodyParts
            self.trainedBodyParts = aggregatedParts.isEmpty ? nil : aggregatedParts
            self.trainingIntensity = snapshot.aggregatedIntensity
            self.hoursSinceTraining = snapshot.hoursSinceTraining()

            // Liftly のみ volume を持つ
            let liftlyVolumes = snapshot.entries.compactMap { entry -> Double? in
                if case .liftly(let payload) = entry.payload { return payload.totalVolumeKG }
                return nil
            }
            self.trainingVolumeKG = liftlyVolumes.isEmpty ? nil : liftlyVolumes.reduce(0, +)

            // Forge 派生メトリクス
            let forgePayloads = snapshot.entries.compactMap { entry -> ForgeTrainingPayload? in
                if case .forge(let payload) = entry.payload { return payload }
                return nil
            }
            let rpes = forgePayloads.compactMap(\.averageRPE)
            self.forgeAverageRPE = rpes.isEmpty ? nil : rpes.reduce(0, +) / Double(rpes.count)
            self.forgeIsPRDay = forgePayloads.contains { $0.isPRSession }
            self.forgeBenchmarkIDs = Array(Set(forgePayloads.flatMap(\.benchmarkIDs))).sorted()
        } else {
            self.linkedSources = []
            self.trainedDomains = []
            self.trainedBodyParts = nil
            self.trainingIntensity = nil
            self.trainingVolumeKG = nil
            self.hoursSinceTraining = nil
            self.forgeAverageRPE = nil
            self.forgeIsPRDay = false
            self.forgeBenchmarkIDs = []
        }
    }

    // MARK: - 旧 init: TrainingSnapshot から構築（後方互換、Phase 2 で削除予定）

    /// [Deprecated] 旧 TrainingSnapshot からの構築。
    /// 内部で UnifiedTrainingSnapshot にラップして新 init に委譲する。
    @available(*, deprecated, message: "Use init(unifiedSnapshot:) — Phase 2 完了時に削除予定")
    init(
        todayDrinkCount: Int,
        todayTotalAlcoholGram: Double,
        todayDidTrain: Bool,
        weekDrinkCount: Int,
        weekTrainingDays: Int,
        consecutiveDrinkingDays: Int,
        trainingGoal: TrainingGoal,
        latestAngerLevel: Int?,
        isBundlePro: Bool = false,
        trainingSnapshot: TrainingSnapshot?
    ) {
        let unified: UnifiedTrainingSnapshot?
        if let snap = trainingSnapshot, snap.hasTraining {
            let payload = LiftlyTrainingPayload(
                sessionCount: snap.sessionCount,
                trainedBodyParts: snap.trainedBodyParts,
                exerciseCount: snap.exerciseCount,
                totalSets: snap.totalSets,
                totalReps: snap.totalReps,
                totalVolumeKG: snap.totalVolumeKG,
                intensityLevel: snap.intensityLevel
            )
            let startedAt = snap.trainingStartAt.map {
                Date(timeIntervalSince1970: TimeInterval($0))
            }
            let endedAt = snap.trainingEndAt.map {
                Date(timeIntervalSince1970: TimeInterval($0))
            }
            let entry = TrainingEntry.fromLiftly(
                payload: payload,
                startedAt: startedAt,
                endedAt: endedAt
            )
            unified = UnifiedTrainingSnapshot(
                userId: snap.userId,
                trainingDate: snap.trainingDate,
                entries: [entry]
            )
        } else {
            unified = nil
        }
        self.init(
            todayDrinkCount: todayDrinkCount,
            todayTotalAlcoholGram: todayTotalAlcoholGram,
            todayDidTrain: todayDidTrain,
            weekDrinkCount: weekDrinkCount,
            weekTrainingDays: weekTrainingDays,
            consecutiveDrinkingDays: consecutiveDrinkingDays,
            trainingGoal: trainingGoal,
            latestAngerLevel: latestAngerLevel,
            isBundlePro: isBundlePro,
            unifiedSnapshot: unified
        )
    }
}
