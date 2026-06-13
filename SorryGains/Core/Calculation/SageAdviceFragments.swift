import Foundation

/// 仙人助言を「冒頭・本論・締め」の3断片に分けて持つ。
/// テンプレ生成時にランダムに組み合わせることで N×N×N の多様性を生む。
///
/// 各断片はキー文字列で保持し、`Bundle.localized*` でその場でロケール解決する。
/// JA は助詞で繋がるため separator を `""`、EN は `" "` を使う
/// (`sage.fragment.separator` キーで切替)。
enum SageAdviceFragments {

    struct Bundle {
        let openingKeys: [String]
        let bodyKeys: [String]
        let closingKeys: [String]

        var localizedOpenings: [String] { openingKeys.map(Self.localized) }
        var localizedBodies: [String] { bodyKeys.map(Self.localized) }
        var localizedClosings: [String] { closingKeys.map(Self.localized) }

        private static func localized(_ key: String) -> String {
            String(localized: String.LocalizationValue(key))
        }
    }

    /// Locale-aware separator used when joining opening + body + closing.
    /// JA: `""` (no space), EN: `" "` (single space).
    static var separator: String {
        String(localized: "sage.fragment.separator")
    }

    static let fragments: [SageAdviceCategory: Bundle] = [
        .drankTooMuch: Bundle(
            openingKeys: keys("drankTooMuch", "opening", count: 8),
            bodyKeys: keys("drankTooMuch", "body", count: 8),
            closingKeys: keys("drankTooMuch", "closing", count: 7)
        ),
        .drankALittle: Bundle(
            openingKeys: keys("drankALittle", "opening", count: 7),
            bodyKeys: keys("drankALittle", "body", count: 6),
            closingKeys: keys("drankALittle", "closing", count: 5)
        ),
        .goodJob: Bundle(
            openingKeys: keys("goodJob", "opening", count: 7),
            bodyKeys: keys("goodJob", "body", count: 6),
            closingKeys: keys("goodJob", "closing", count: 5)
        ),
        .neutral: Bundle(
            openingKeys: keys("neutral", "opening", count: 6),
            bodyKeys: keys("neutral", "body", count: 5),
            closingKeys: keys("neutral", "closing", count: 4)
        ),
        .streak: Bundle(
            openingKeys: keys("streak", "opening", count: 6),
            bodyKeys: keys("streak", "body", count: 6),
            closingKeys: keys("streak", "closing", count: 5)
        ),
        .hardTrainHeavyDrink: Bundle(
            openingKeys: keys("hardTrainHeavyDrink", "opening", count: 5),
            bodyKeys: keys("hardTrainHeavyDrink", "body", count: 5),
            closingKeys: keys("hardTrainHeavyDrink", "closing", count: 4)
        ),
        .hardTrainLightDrink: Bundle(
            openingKeys: keys("hardTrainLightDrink", "opening", count: 5),
            bodyKeys: keys("hardTrainLightDrink", "body", count: 4),
            closingKeys: keys("hardTrainLightDrink", "closing", count: 4)
        ),
        .lightTrainHeavyDrink: Bundle(
            openingKeys: keys("lightTrainHeavyDrink", "opening", count: 4),
            bodyKeys: keys("lightTrainHeavyDrink", "body", count: 4),
            closingKeys: keys("lightTrainHeavyDrink", "closing", count: 3)
        ),
    ]

    private static func keys(
        _ category: String,
        _ kind: String,
        count: Int
    ) -> [String] {
        (0..<count).map { "sage.fragment.\(category).\(kind).\($0)" }
    }
}
