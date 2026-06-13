import Foundation

/// ローカル（テンプレ）助言プロバイダー。
/// 「冒頭・本論・締め」の3断片をランダムに組み合わせて多様なメッセージを生成する。
/// - 直近3件のメッセージは記憶し、被りを避ける（同じカテゴリでも毎回違う印象に）
/// - Liftly 連携情報があれば、文中に部位名・強度を動的挿入する
struct LocalSageAdviceProvider: SageAdviceProvider {

    /// 直近に生成したメッセージ（最大 recentHistoryLimit 件）。
    /// actor でスレッドセーフに保持する。
    actor History {
        static let limit = 3
        var recent: [String] = []

        func remember(_ message: String) {
            recent.append(message)
            if recent.count > Self.limit {
                recent.removeFirst()
            }
        }

        func contains(_ message: String) -> Bool {
            recent.contains(message)
        }

        func reset() {
            recent = []
        }
    }

    // internal(set) で外部（テスト等）からリセット可能にする
    static let history = History()

    func provideAdvice(for context: SageContext) async -> SageAdvice {
        let category = Self.determineCategory(for: context)
        let tone = Self.toneForCategory[category, default: .calm]
        let bundle = SageAdviceFragments.fragments[category]
            ?? SageAdviceFragments.fragments[.neutral]!

        let baseSeed = SeededRandomNumberGenerator.seed(for: context)
        let message = await Self.composeMessage(bundle: bundle, context: context, baseSeed: baseSeed)
        await Self.history.remember(message)

        let followUp = Self.buildFollowUp(category: category, context: context)
        return SageAdvice(
            category: category,
            tone: tone,
            message: message,
            followUp: followUp
        )
    }
}

// MARK: - Category Determination

private extension LocalSageAdviceProvider {

    static func determineCategory(for context: SageContext) -> SageAdviceCategory {
        if context.consecutiveDrinkingDays >= 3 {
            return .streak
        }

        let isDrinkingHeavy = context.todayDrinkCount >= 3
            || context.todayTotalAlcoholGram >= 40
        let isDrinkingLight = context.todayDrinkCount >= 1

        if context.hasAnyLinkedSource, let intensity = context.trainingIntensity {
            let isHighIntensity = intensity == .high || intensity == .medium
            if isHighIntensity && isDrinkingHeavy { return .hardTrainHeavyDrink }
            if isHighIntensity && isDrinkingLight { return .hardTrainLightDrink }
            if !isHighIntensity && isDrinkingHeavy { return .lightTrainHeavyDrink }
        }

        if isDrinkingHeavy { return .drankTooMuch }
        if isDrinkingLight { return .drankALittle }
        if context.todayDidTrain && context.todayDrinkCount == 0 { return .goodJob }
        return .neutral
    }
}

// MARK: - Message Composition

private extension LocalSageAdviceProvider {

    /// 直近履歴と被らないようにランダム生成。最大8回試行して、それでも被るなら諦めて返す。
    /// `baseSeed` を使うため同日・同コンテキスト + 同履歴状態なら同じ結果になる。
    static func composeMessage(
        bundle: SageAdviceFragments.Bundle,
        context: SageContext,
        baseSeed: UInt64
    ) async -> String {
        for attempt in 0..<8 {
            // 試行ごとにシードをずらすことで履歴回避用の別候補を生成できる
            var rng = SeededRandomNumberGenerator(seed: baseSeed &+ UInt64(attempt))
            let candidate = randomComposition(bundle: bundle, context: context, rng: &rng)
            if await !history.contains(candidate) {
                return candidate
            }
        }
        // 全試行で被った場合は先頭シードの結果を返す（最悪ケース）
        var rng = SeededRandomNumberGenerator(seed: baseSeed)
        return randomComposition(bundle: bundle, context: context, rng: &rng)
    }

    static func randomComposition(
        bundle: SageAdviceFragments.Bundle,
        context: SageContext,
        rng: inout SeededRandomNumberGenerator
    ) -> String {
        var pieces: [String] = []
        if let opening = bundle.localizedOpenings.randomElement(using: &rng) {
            pieces.append(opening)
        }
        if let body = bundle.localizedBodies.randomElement(using: &rng) {
            pieces.append(injectContext(into: body, context: context, rng: &rng))
        }
        if let closing = bundle.localizedClosings.randomElement(using: &rng) {
            pieces.append(closing)
        }
        return pieces.joined(separator: SageAdviceFragments.separator)
    }

    /// 連続飲酒日数や鍛えた部位を本文に動的挿入。
    /// ロケールに応じて挿入文と置換ターゲットを切替える。
    static func injectContext(into body: String, context: SageContext, rng: inout SeededRandomNumberGenerator) -> String {
        var result = body

        if context.consecutiveDrinkingDays >= 3,
           Bool.random(using: &rng),
           !result.contains(consecutiveDaysMarker) {
            let template = String(localized: "sage.injection.consecutiveDays")
            let prefix = String(format: template, context.consecutiveDrinkingDays)
            result = prefix + result
        }

        if context.hasAnyLinkedSource,
           let parts = context.trainedBodyParts,
           !parts.isEmpty,
           Bool.random(using: &rng) {
            let separator = String(localized: "bodyParts.separator")
            let partsText = parts
                .map(bodyPartLocalizedName(_:))
                .joined(separator: separator)
            let target = String(localized: "sage.injection.muscleTarget")
            let template = String(localized: "sage.injection.muscleReplacement")
            let replacement = String(format: template, partsText)
            result = result.replacingOccurrences(of: target, with: replacement)
        }

        if context.isForgeLinked,
           !context.trainedDomains.isEmpty,
           Bool.random(using: &rng) {
            let separator = String(localized: "bodyParts.separator")
            let domainsText = context.trainedDomains
                .sorted(by: { $0.rawValue < $1.rawValue })
                .map(domainLocalizedName(_:))
                .joined(separator: separator)
            let template = String(localized: "sage.injection.forgeDomains")
            if !template.isEmpty {
                let prefix = String(format: template, domainsText)
                result = prefix + result
            }
        }

        return result
    }

    /// JA: `"日"` / EN: `"days"` — used to skip duplicated consecutive-day phrasing.
    static var consecutiveDaysMarker: String {
        String(localized: "sage.injection.consecutiveDaysMarker")
    }
}

// MARK: - Follow-up

private extension LocalSageAdviceProvider {

    static func buildFollowUp(
        category: SageAdviceCategory,
        context: SageContext
    ) -> String? {
        if context.hasAnyLinkedSource,
           let parts = context.trainedBodyParts,
           !parts.isEmpty {
            return buildLinkedFollowUp(
                category: category,
                bodyParts: parts,
                intensity: context.trainingIntensity
            )
        }
        if !context.hasAnyLinkedSource,
           context.todayDrinkCount >= 1,
           context.todayDidTrain {
            return unlinkedTrainingFollowUp
        }
        return defaultFollowUp(for: category)
    }

    static func buildLinkedFollowUp(
        category: SageAdviceCategory,
        bodyParts: [String],
        intensity: IntensityLevel?
    ) -> String {
        let separator = String(localized: "bodyParts.separator")
        let partsText = bodyParts
            .map(bodyPartLocalizedName(_:))
            .joined(separator: separator)

        let key: String
        switch category {
        case .hardTrainHeavyDrink: key = "sage.followUp.linked.hardTrainHeavyDrink"
        case .hardTrainLightDrink: key = "sage.followUp.linked.hardTrainLightDrink"
        case .lightTrainHeavyDrink: key = "sage.followUp.linked.lightTrainHeavyDrink"
        case .drankTooMuch: key = "sage.followUp.linked.drankTooMuch"
        case .drankALittle: key = "sage.followUp.linked.drankALittle"
        case .goodJob: key = "sage.followUp.linked.goodJob"
        default:
            return defaultFollowUp(for: category) ?? ""
        }
        let template = String(localized: String.LocalizationValue(key))
        return String(format: template, partsText)
    }

    static func defaultFollowUp(for category: SageAdviceCategory) -> String? {
        let key: String
        switch category {
        case .drankTooMuch: key = "sage.followUp.default.drankTooMuch"
        case .goodJob: key = "sage.followUp.default.goodJob"
        case .streak: key = "sage.followUp.default.streak"
        case .hardTrainHeavyDrink: key = "sage.followUp.default.hardTrainHeavyDrink"
        case .hardTrainLightDrink: key = "sage.followUp.default.hardTrainLightDrink"
        case .lightTrainHeavyDrink: key = "sage.followUp.default.lightTrainHeavyDrink"
        default: return nil
        }
        return String(localized: String.LocalizationValue(key))
    }

    static var unlinkedTrainingFollowUp: String {
        String(localized: "sage.followUp.unlinkedTraining")
    }
}

// MARK: - Tone & Body Part Names

private extension LocalSageAdviceProvider {

    static let toneForCategory: [SageAdviceCategory: SageAdviceTone] = [
        .drankTooMuch: .stern,
        .drankALittle: .warm,
        .goodJob: .firedUp,
        .neutral: .calm,
        .streak: .stern,
        .hardTrainHeavyDrink: .stern,
        .hardTrainLightDrink: .warm,
        .lightTrainHeavyDrink: .stern,
    ]

    /// Resolves a body-part key (e.g. "chest") to its localized name via
    /// the shared `bodyPart.*` keys added in Phase B. Falls back to the raw
    /// key if no localization exists (e.g. unknown part).
    static func bodyPartLocalizedName(_ key: String) -> String {
        let lookupKey = "bodyPart.\(key.lowercased())"
        let localized = String(localized: String.LocalizationValue(lookupKey))
        // String(localized:) returns the key itself when no entry exists; in
        // that case, fall back to the raw user-supplied key.
        return localized == lookupKey ? key : localized
    }

    /// Resolves a `TrainingDomain` to its localized display name via `domain.*` keys.
    static func domainLocalizedName(_ domain: TrainingDomain) -> String {
        let key = "domain.\(domain.rawValue)"
        let localized = String(localized: String.LocalizationValue(key))
        return localized == key ? domain.rawValue : localized
    }
}
