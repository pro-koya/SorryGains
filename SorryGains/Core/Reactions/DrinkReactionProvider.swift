import Foundation

/// Provides character reaction dialogues based on the drink count for the day.
///
/// Each drink triggers a different reaction, escalating in drama and humor.
/// Multiple variants per count prevent staleness on repeated use.
enum DrinkReactionProvider {

    /// Returns a random reaction for the given drink count.
    static func reaction(forDrinkNumber count: Int) -> DrinkReaction {
        let clamped = min(max(count, 1), reactionData.count)
        let variants = reactionData[clamped - 1]
        let data = variants[Int.random(in: 0..<variants.count)]
        return DrinkReaction(
            dialogue: String(localized: String.LocalizationValue(data.key)),
            emoji: data.emoji,
            intensity: data.intensity
        )
    }

    private struct ReactionData {
        let key: String
        let emoji: String
        let intensity: DrinkReaction.Intensity
    }

    /// All reaction metadata. Index 0 = 1st drink, index 1 = 2nd drink, etc.
    /// Dialogue is resolved via `String(localized:)` at access time so it
    /// follows the current locale.
    private static let reactionData: [[ReactionData]] = [
        // 1杯目 — 渋々許容
        [
            ReactionData(key: "drinkReaction.1.0", emoji: "😑", intensity: .mild),
            ReactionData(key: "drinkReaction.1.1", emoji: "🤨", intensity: .mild),
            ReactionData(key: "drinkReaction.1.2", emoji: "😮‍💨", intensity: .mild),
            ReactionData(key: "drinkReaction.1.3", emoji: "🙏", intensity: .mild),
        ],
        // 2杯目 — 疑念
        [
            ReactionData(key: "drinkReaction.2.0", emoji: "😠", intensity: .moderate),
            ReactionData(key: "drinkReaction.2.1", emoji: "🤔", intensity: .moderate),
            ReactionData(key: "drinkReaction.2.2", emoji: "😤", intensity: .moderate),
            ReactionData(key: "drinkReaction.2.3", emoji: "💢", intensity: .moderate),
        ],
        // 3杯目 — 焦り
        [
            ReactionData(key: "drinkReaction.3.0", emoji: "💪", intensity: .high),
            ReactionData(key: "drinkReaction.3.1", emoji: "📉", intensity: .high),
            ReactionData(key: "drinkReaction.3.2", emoji: "💸", intensity: .high),
            ReactionData(key: "drinkReaction.3.3", emoji: "🚰", intensity: .high),
        ],
        // 4杯目 — 激怒
        [
            ReactionData(key: "drinkReaction.4.0", emoji: "😭", intensity: .severe),
            ReactionData(key: "drinkReaction.4.1", emoji: "🙇", intensity: .severe),
            ReactionData(key: "drinkReaction.4.2", emoji: "🔥", intensity: .severe),
            ReactionData(key: "drinkReaction.4.3", emoji: "⬇️", intensity: .severe),
        ],
        // 5杯目以上 — 絶望・自暴自棄
        [
            ReactionData(key: "drinkReaction.5.0", emoji: "😢", intensity: .critical),
            ReactionData(key: "drinkReaction.5.1", emoji: "🪦", intensity: .critical),
            ReactionData(key: "drinkReaction.5.2", emoji: "👻", intensity: .critical),
            ReactionData(key: "drinkReaction.5.3", emoji: "💀", intensity: .critical),
        ],
    ]
}

// MARK: - DrinkReaction Model

struct DrinkReaction: Sendable, Equatable {
    let dialogue: String
    let emoji: String
    let intensity: Intensity

    enum Intensity: Int, Sendable {
        case mild = 1
        case moderate = 2
        case high = 3
        case severe = 4
        case critical = 5
    }
}
