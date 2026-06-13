import Foundation

/// Sage LLM プロンプトの構築ロジックを担う内部ユーティリティ。
///
/// `FoundationModelsSageAdviceProvider`（iOS 26+）から切り出した pure function 群。
/// `@testable import` でテストから直接呼び出し可能。
enum SagePromptBuilder {

    /// プロンプト文字列を構築する。
    /// - Parameters:
    ///   - category: 助言カテゴリ
    ///   - context: ユーザー文脈
    /// - Returns: LLM に渡すプロンプト文字列
    static func buildPrompt(
        category: SageAdviceCategory? = nil,
        context: SageContext
    ) -> String {
        let resolvedCategory = category ?? determineCategory(for: context)
        var lines: [String] = []
        lines.append(String(localized: "sage.llm.prompt.header"))

        let drinks = String(
            format: String(localized: "sage.llm.prompt.line.drinks"),
            context.todayDrinkCount,
            Int(context.todayTotalAlcoholGram)
        )
        lines.append(drinks)

        let trainStatus = context.todayDidTrain
            ? String(localized: "sage.llm.workout.done")
            : String(localized: "sage.llm.workout.none")
        lines.append(
            String(format: String(localized: "sage.llm.prompt.line.workout"), trainStatus)
        )

        lines.append(
            String(
                format: String(localized: "sage.llm.prompt.line.consecutiveDays"),
                context.consecutiveDrinkingDays
            )
        )
        lines.append(
            String(
                format: String(localized: "sage.llm.prompt.line.weekly"),
                context.weekDrinkCount,
                context.weekTrainingDays
            )
        )

        if context.hasAnyLinkedSource {
            if let parts = context.trainedBodyParts, !parts.isEmpty {
                let separator = String(localized: "bodyParts.separator")
                let partsLocalized = parts
                    .map(bodyPartLocalized(_:))
                    .joined(separator: separator)
                lines.append(
                    String(
                        format: String(localized: "sage.llm.prompt.line.bodyParts"),
                        partsLocalized
                    )
                )
            }
            if let intensity = context.trainingIntensity {
                lines.append(
                    String(
                        format: String(localized: "sage.llm.prompt.line.intensity"),
                        intensityLocalized(intensity)
                    )
                )
            }
            // ドメイン行
            if !context.trainedDomains.isEmpty {
                let separator = String(localized: "bodyParts.separator")
                let domainsText = context.trainedDomains
                    .sorted(by: { $0.rawValue < $1.rawValue })
                    .map(domainLocalized(_:))
                    .joined(separator: separator)
                lines.append(
                    String(
                        format: String(localized: "sage.llm.prompt.line.domains"),
                        domainsText
                    )
                )
            }
            // Forge 固有行
            if context.isForgeLinked {
                if let rpe = context.forgeAverageRPE {
                    lines.append(
                        String(
                            format: String(localized: "sage.llm.prompt.line.rpe"),
                            rpe
                        )
                    )
                }
                if context.forgeIsPRDay {
                    lines.append(String(localized: "sage.llm.prompt.line.prDay"))
                }
                if !context.forgeBenchmarkIDs.isEmpty {
                    lines.append(
                        String(
                            format: String(localized: "sage.llm.prompt.line.benchmarks"),
                            context.forgeBenchmarkIDs.joined(separator: ", ")
                        )
                    )
                }
            }
        }

        lines.append("")
        lines.append(
            String(
                format: String(localized: "sage.llm.prompt.line.category"),
                categoryLocalized(resolvedCategory)
            )
        )
        let tone = toneForCategory[resolvedCategory, default: .calm]
        lines.append(
            String(
                format: String(localized: "sage.llm.prompt.line.tone"),
                toneLocalized(tone)
            )
        )

        // バンドル Pro 詳細モード: 長文・履歴参照を指示する追加行
        if context.isBundlePro {
            lines.append(String(localized: "sage.llm.prompt.line.bundlePro.detailed"))
        }

        lines.append("")
        lines.append(String(localized: "sage.llm.prompt.footer"))
        return lines.joined(separator: "\n")
    }

    // MARK: - Category / Tone

    static func determineCategory(for context: SageContext) -> SageAdviceCategory {
        if context.consecutiveDrinkingDays >= 3 { return .streak }
        let isHeavy = context.todayDrinkCount >= 3 || context.todayTotalAlcoholGram >= 40
        let isLight = context.todayDrinkCount >= 1
        if context.hasAnyLinkedSource, let intensity = context.trainingIntensity {
            let isHigh = intensity == .high || intensity == .medium
            if isHigh && isHeavy { return .hardTrainHeavyDrink }
            if isHigh && isLight { return .hardTrainLightDrink }
            if !isHigh && isHeavy { return .lightTrainHeavyDrink }
        }
        if isHeavy { return .drankTooMuch }
        if isLight { return .drankALittle }
        if context.todayDidTrain && context.todayDrinkCount == 0 { return .goodJob }
        return .neutral
    }

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

    // MARK: - Localization helpers

    static func bodyPartLocalized(_ key: String) -> String {
        let lookupKey = "bodyPart.\(key.lowercased())"
        let localized = String(localized: String.LocalizationValue(lookupKey))
        return localized == lookupKey ? key : localized
    }

    static func domainLocalized(_ domain: TrainingDomain) -> String {
        let key = "domain.\(domain.rawValue)"
        let localized = String(localized: String.LocalizationValue(key))
        return localized == key ? domain.rawValue : localized
    }

    static func intensityLocalized(_ intensity: IntensityLevel) -> String {
        let key: String
        switch intensity {
        case .high: key = "sage.llm.intensity.high"
        case .medium: key = "sage.llm.intensity.medium"
        case .low: key = "sage.llm.intensity.low"
        }
        return String(localized: String.LocalizationValue(key))
    }

    static func categoryLocalized(_ category: SageAdviceCategory) -> String {
        let key: String
        switch category {
        case .drankTooMuch: key = "sage.llm.category.drankTooMuch"
        case .drankALittle: key = "sage.llm.category.drankALittle"
        case .goodJob: key = "sage.llm.category.goodJob"
        case .neutral: key = "sage.llm.category.neutral"
        case .streak: key = "sage.llm.category.streak"
        case .hardTrainHeavyDrink: key = "sage.llm.category.hardTrainHeavyDrink"
        case .hardTrainLightDrink: key = "sage.llm.category.hardTrainLightDrink"
        case .lightTrainHeavyDrink: key = "sage.llm.category.lightTrainHeavyDrink"
        }
        return String(localized: String.LocalizationValue(key))
    }

    static func toneLocalized(_ tone: SageAdviceTone) -> String {
        let key: String
        switch tone {
        case .stern: key = "sage.llm.tone.stern"
        case .warm: key = "sage.llm.tone.warm"
        case .firedUp: key = "sage.llm.tone.firedUp"
        case .calm: key = "sage.llm.tone.calm"
        }
        return String(localized: String.LocalizationValue(key))
    }
}
