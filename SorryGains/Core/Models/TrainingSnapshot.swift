import Foundation

/// Liftly から取得したトレーニングサマリーのスナップショット
/// 算出時に参照したデータを保持し、後からの追跡を可能にする
struct TrainingSnapshot: Sendable, Equatable, Codable {
    let userId: String
    let trainingDate: Date
    let sessionCount: Int
    let trainingStartAt: Int?
    let trainingEndAt: Int?
    let trainedBodyParts: [String]
    let exerciseCount: Int
    let totalSets: Int
    let totalReps: Int
    let totalVolumeKG: Double
    let intensityLevel: IntensityLevel?

    /// 実データに基づくトレーニング有無判定
    /// JSON の has_training フラグに依存せず、セッション数 > 0 かつ種目数 > 0 で判定
    var hasTraining: Bool {
        sessionCount > 0 && exerciseCount > 0
    }

    /// Supabase レスポンス JSON からの生成
    init(from json: [String: Any], fetchedAt: Date = .now) {
        self.userId = json["user_id"] as? String ?? ""
        self.sessionCount = Self.parseIntFlexible(json["session_count"]) ?? 0
        self.trainingStartAt = Self.parseIntFlexible(json["training_start_at"])
        self.trainingEndAt = Self.parseIntFlexible(json["training_end_at"])
        self.exerciseCount = Self.parseIntFlexible(json["exercise_count"]) ?? 0
        self.totalSets = Self.parseIntFlexible(json["total_sets"]) ?? 0
        self.totalReps = Self.parseIntFlexible(json["total_reps"]) ?? 0
        self.totalVolumeKG = Self.parseDoubleFlexible(json["total_volume_kg"]) ?? 0
        self.trainedBodyParts = (json["trained_body_parts"] as? [String]) ?? []

        if let dateStr = json["training_date"] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            self.trainingDate = formatter.date(from: dateStr) ?? fetchedAt
        } else {
            self.trainingDate = fetchedAt
        }

        if let level = json["intensity_level"] as? String {
            self.intensityLevel = IntensityLevel(rawValue: level)
        } else {
            self.intensityLevel = nil
        }
    }

    /// JSON の数値型の揺れ（Int, Double, String）を吸収するパーサー
    private static func parseIntFlexible(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let d = value as? Double { return Int(d) }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String { return Int(s) }
        return nil
    }

    private static func parseDoubleFlexible(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    /// トレーニングなしの場合のデフォルト値
    static func noTraining(for date: Date = .now) -> TrainingSnapshot {
        TrainingSnapshot(
            userId: "",
            trainingDate: date,
            sessionCount: 0,
            trainingStartAt: nil,
            trainingEndAt: nil,
            trainedBodyParts: [],
            exerciseCount: 0,
            totalSets: 0,
            totalReps: 0,
            totalVolumeKG: 0,
            intensityLevel: nil
        )
    }

    /// `UnifiedTrainingSnapshot` からの逆変換など、プログラム側で組み立てる用途に公開。
    init(
        userId: String = "",
        trainingDate: Date,
        sessionCount: Int,
        trainingStartAt: Int?,
        trainingEndAt: Int?,
        trainedBodyParts: [String],
        exerciseCount: Int,
        totalSets: Int,
        totalReps: Int,
        totalVolumeKG: Double,
        intensityLevel: IntensityLevel?
    ) {
        self.userId = userId
        self.trainingDate = trainingDate
        self.sessionCount = sessionCount
        self.trainingStartAt = trainingStartAt
        self.trainingEndAt = trainingEndAt
        self.trainedBodyParts = trainedBodyParts
        self.exerciseCount = exerciseCount
        self.totalSets = totalSets
        self.totalReps = totalReps
        self.totalVolumeKG = totalVolumeKG
        self.intensityLevel = intensityLevel
    }

    /// トレ後から指定時刻までの経過時間（時間単位）
    func hoursSinceTraining(at referenceTime: Date = .now) -> Double? {
        guard let endAt = trainingEndAt else { return nil }
        let endDate = Date(timeIntervalSince1970: TimeInterval(endAt))
        let interval = referenceTime.timeIntervalSince(endDate)
        guard interval >= 0 else { return nil }
        return interval / 3600.0
    }

    /// 部位名のローカライズ済み表示文字列
    var bodyPartsDisplayText: String {
        guard !trainedBodyParts.isEmpty else { return "" }
        let localized = trainedBodyParts.map { bodyPartLocalizedName($0) }
        return localized.joined(separator: String(localized: "bodyParts.separator"))
    }
}

// MARK: - IntensityLevel

enum IntensityLevel: String, Sendable, Codable, CaseIterable {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low: String(localized: "intensity.low")
        case .medium: String(localized: "intensity.medium")
        case .high: String(localized: "intensity.high")
        }
    }

    /// ダメージ算出時の強度倍率
    var penaltyMultiplier: Double {
        switch self {
        case .low: 0.7
        case .medium: 1.0
        case .high: 1.4
        }
    }
}

// MARK: - Body Part Localization

private func bodyPartLocalizedName(_ key: String) -> String {
    switch key.lowercased() {
    case "chest": String(localized: "bodyPart.chest")
    case "back": String(localized: "bodyPart.back")
    case "legs": String(localized: "bodyPart.legs")
    case "shoulders": String(localized: "bodyPart.shoulders")
    case "biceps": String(localized: "bodyPart.biceps")
    case "triceps": String(localized: "bodyPart.triceps")
    case "abs": String(localized: "bodyPart.abs")
    case "cardio": String(localized: "bodyPart.cardio")
    default: key
    }
}
