import Foundation

/// Muscle360 統合論理モデルの中心型。
/// Liftly / Forge の両ソースを束ね、消費側（SageContext）が直接見るスナップショット。
///
/// 仕様: Projects/Muscle360/2026-05-18-types-and-rpc-spec.md §2.7
struct UnifiedTrainingSnapshot: Sendable, Equatable {
    let userId: String
    let trainingDate: Date
    let entries: [TrainingEntry]

    // MARK: - 派生メトリクス

    var hasTraining: Bool { !entries.isEmpty }

    var sources: Set<TrainingSource> { Set(entries.map(\.source)) }

    var trainedDomains: Set<TrainingDomain> {
        entries.reduce(into: Set<TrainingDomain>()) { $0.formUnion($1.domains) }
    }

    /// 強度の集約ルール: 各 entry の intensity の max を採用。
    /// `high > medium > low > nil` の順序。
    var aggregatedIntensity: IntensityLevel? {
        let levels = entries.compactMap(\.intensity)
        if levels.contains(.high) { return .high }
        if levels.contains(.medium) { return .medium }
        if levels.contains(.low) { return .low }
        return nil
    }

    /// Liftly の `trainedBodyParts` と Forge sessionTypes 由来の部位ラベルを統合。
    /// 重複は順序保持で排除。
    var aggregatedBodyParts: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for entry in entries {
            switch entry.payload {
            case .liftly(let payload):
                for part in payload.trainedBodyParts where seen.insert(part).inserted {
                    result.append(part)
                }
            case .forge(let payload):
                for part in Self.bodyParts(forForgeSessionTypes: payload.sessionTypes)
                where seen.insert(part).inserted {
                    result.append(part)
                }
            }
        }
        return result
    }

    /// 最後のトレ終了からの経過時間（時間単位）。Forge は ended_at、Liftly は trainingEndAt を採用。
    func hoursSinceTraining(at referenceTime: Date = .now) -> Double? {
        guard let end = entries.compactMap(\.endedAt).max() else { return nil }
        let interval = referenceTime.timeIntervalSince(end)
        return interval >= 0 ? interval / 3600.0 : nil
    }

    static func empty(for date: Date) -> UnifiedTrainingSnapshot {
        .init(userId: "", trainingDate: date, entries: [])
    }

    // MARK: - Forge session_type → body parts マッピング
    //
    // 仕様: Projects/Muscle360/2026-05-18-types-and-rpc-spec.md §2.7 派生メトリクス
    private static func bodyParts(forForgeSessionTypes types: [String]) -> [String] {
        var result: [String] = []
        for type in types {
            switch type {
            case "crossfit_wod", "benchmark":
                result.append("crossfit")
            case "hyrox_race", "hyrox_simulation", "hyrox_compromised", "hyrox_station_specific":
                result.append("hyrox")
            case "strength":
                result.append("strength")
            case "run":
                result.append("cardio")
            case "custom":
                result.append("mixed")
            default:
                continue
            }
        }
        return result
    }
}

/// 1 つのトレーニングソース（Liftly セッション群 / Forge セッション群）に対応するエントリ。
struct TrainingEntry: Sendable, Equatable {
    let source: TrainingSource
    let startedAt: Date?
    let endedAt: Date?
    let payload: TrainingPayload
    let domains: Set<TrainingDomain>
    let intensity: IntensityLevel?
}

// MARK: - Forge session_type → TrainingDomain マッピング（factory helper）

extension TrainingEntry {
    /// Forge ペイロードから TrainingEntry を構築する。session_types からドメインを導出。
    static func fromForge(
        payload: ForgeTrainingPayload,
        startedAt: Date?,
        endedAt: Date?
    ) -> TrainingEntry {
        var domains = Set<TrainingDomain>()
        for type in payload.sessionTypes {
            switch type {
            case "crossfit_wod", "benchmark":
                domains.insert(.crossfit)
            case "hyrox_race", "hyrox_simulation", "hyrox_compromised", "hyrox_station_specific":
                domains.insert(.hyrox)
            case "strength":
                domains.insert(.strength)
            case "run":
                domains.insert(.cardio)
            case "custom":
                domains.insert(.mixed)
            default:
                continue
            }
        }
        if domains.count > 1 {
            // 複数ドメインを跨ぐ場合は .mixed も併記
            domains.insert(.mixed)
        }
        return TrainingEntry(
            source: .forge,
            startedAt: startedAt,
            endedAt: endedAt,
            payload: .forge(payload),
            domains: domains,
            intensity: payload.intensityLevel
        )
    }

    /// Liftly ペイロードから TrainingEntry を構築する。
    static func fromLiftly(
        payload: LiftlyTrainingPayload,
        startedAt: Date?,
        endedAt: Date?
    ) -> TrainingEntry {
        var domains = Set<TrainingDomain>([.strength])
        if payload.trainedBodyParts.contains(where: { $0.lowercased() == "cardio" }) {
            domains.insert(.cardio)
        }
        return TrainingEntry(
            source: .liftly,
            startedAt: startedAt,
            endedAt: endedAt,
            payload: .liftly(payload),
            domains: domains,
            intensity: payload.intensityLevel
        )
    }
}
