import Foundation
import Supabase

// MARK: - SageAdviceHistoryService
//
// バンドル加入者の仙人助言を Supabase `sage_advice_history` テーブルに保存する。
//
// 設計方針:
//   - `isBundlePro` が false のときは何もしない（非バンドルユーザーは保存しない）
//   - 保存失敗はサイレントに無視（助言表示をブロックしない）
//   - 履歴の UI 表示は Phase 3 スコープ。本フェーズは蓄積のみ。

struct SageAdviceHistoryService {

    private let client: SupabaseClient
    private let log = SorryGainsLogger(category: "SageAdviceHistory")

    init(client: SupabaseClient = SupabaseConfig.client) {
        self.client = client
    }

    /// バンドル加入者の助言を非同期で保存する。
    /// - Parameters:
    ///   - advice: 保存する助言
    ///   - context: 助言生成時のコンテキスト（バンドルフラグ含む）
    func save(_ advice: SageAdvice, context: SageContext) async {
        // バンドル加入者のみ保存
        guard context.isBundlePro else { return }

        // 未サインイン時はスキップ
        guard let userId = client.auth.currentUser?.id.uuidString else { return }

        let record = SageAdviceHistoryRecord(
            userId: userId,
            category: advice.category.rawValue,
            tone: advice.tone.rawValue,
            message: advice.message,
            followUp: advice.followUp,
            contextSnapshot: buildContextSnapshot(context)
        )

        do {
            try await client
                .from("sage_advice_history")
                .insert(record)
                .execute()
            log.info("advice history saved for user \(userId)")
        } catch {
            // 保存失敗は無視（助言表示をブロックしない）
            log.warning("advice history save failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func buildContextSnapshot(_ context: SageContext) -> [String: Any] {
        var snapshot: [String: Any] = [
            "todayDrinkCount": context.todayDrinkCount,
            "todayTotalAlcoholGram": context.todayTotalAlcoholGram,
            "todayDidTrain": context.todayDidTrain,
            "weekDrinkCount": context.weekDrinkCount,
            "weekTrainingDays": context.weekTrainingDays,
            "consecutiveDrinkingDays": context.consecutiveDrinkingDays,
            "trainingGoal": context.trainingGoal.rawValue,
            "isBundlePro": context.isBundlePro
        ]
        if let angerLevel = context.latestAngerLevel {
            snapshot["latestAngerLevel"] = angerLevel
        }
        return snapshot
    }
}

// MARK: - Insert DTO

private struct SageAdviceHistoryRecord: Encodable {
    let userId: String
    let category: String
    let tone: String
    let message: String
    let followUp: String?
    let contextSnapshot: [String: Any]

    // Encodable の手動実装（[String: Any] は自動合成不可）
    enum CodingKeys: String, CodingKey {
        case userId       = "user_id"
        case category
        case tone
        case message
        case followUp     = "follow_up"
        case contextSnapshot = "context_json"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(category, forKey: .category)
        try container.encode(tone, forKey: .tone)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(followUp, forKey: .followUp)
        // contextSnapshot は JSON にシリアライズしてから埋め込む
        if let jsonData = try? JSONSerialization.data(withJSONObject: contextSnapshot),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try container.encode(jsonString, forKey: .contextSnapshot)
        }
    }
}
