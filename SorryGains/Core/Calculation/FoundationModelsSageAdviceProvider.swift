import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple Foundation Models（iOS 26+）を使ったオンデバイスLLM助言プロバイダー。
/// - 端末上で完結（API料金ゼロ・オフライン動作）
/// - 失敗時は LocalSageAdviceProvider に自動フォールバック
@available(iOS 26.0, *)
struct FoundationModelsSageAdviceProvider: SageAdviceProvider {

    let fallback: SageAdviceProvider

    init(fallback: SageAdviceProvider = LocalSageAdviceProvider()) {
        self.fallback = fallback
    }

    func provideAdvice(for context: SageContext) async -> SageAdvice {
        #if canImport(FoundationModels)
        do {
            let category = Self.determineCategory(for: context)
            let tone = Self.toneForCategory[category, default: .calm]

            let session = LanguageModelSession(instructions: Self.personaInstructions)
            let prompt = Self.buildPrompt(category: category, context: context)

            // バンドル Pro 加入者は詳細モード（最大トークン 2倍）
            let maxTokens = context.isBundlePro ? 600 : 300
            let options = GenerationOptions(temperature: 1.05, maximumResponseTokens: maxTokens)
            let response = try await session.respond(to: prompt, options: options)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else {
                return await fallback.provideAdvice(for: context)
            }

            let (message, followUp) = Self.splitMessage(text)
            return SageAdvice(
                category: category,
                tone: tone,
                message: message,
                followUp: followUp ?? Self.contextualFollowUp(category: category, context: context)
            )
        } catch {
            #if DEBUG
            print("FoundationModels generation failed: \(error.localizedDescription)")
            #endif
            return await fallback.provideAdvice(for: context)
        }
        #else
        return await fallback.provideAdvice(for: context)
        #endif
    }
}

// MARK: - Prompt Construction

@available(iOS 26.0, *)
private extension FoundationModelsSageAdviceProvider {

    /// Persona instructions sent to Foundation Models. JA/EN bilingual via
    /// `String(localized:)` — each language carries its own character voice
    /// ("筋肉仙人" / "Muscle Sage").
    static var personaInstructions: String {
        String(localized: "sage.llm.persona")
    }

    /// `SagePromptBuilder` に委譲してプロンプトを構築する。
    static func buildPrompt(
        category: SageAdviceCategory,
        context: SageContext
    ) -> String {
        SagePromptBuilder.buildPrompt(category: category, context: context)
    }

    /// LLM出力を「メイン --- フォローアップ」で分割する。
    static func splitMessage(_ text: String) -> (String, String?) {
        if let separator = text.range(of: "---") {
            let main = text[..<separator.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let follow = text[separator.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (main, follow.isEmpty ? nil : follow)
        }
        return (text, nil)
    }

    static func contextualFollowUp(
        category: SageAdviceCategory,
        context: SageContext
    ) -> String? {
        let key: String
        switch category {
        case .drankTooMuch, .hardTrainHeavyDrink, .lightTrainHeavyDrink:
            key = "sage.llm.contextualFollowUp.drinkHeavy"
        case .streak:
            key = "sage.llm.contextualFollowUp.streak"
        case .goodJob:
            key = "sage.llm.contextualFollowUp.goodJob"
        case .hardTrainLightDrink:
            key = "sage.llm.contextualFollowUp.hardTrainLightDrink"
        default:
            return nil
        }
        return String(localized: String.LocalizationValue(key))
    }
}

// MARK: - Shared with LocalProvider (delegates to SagePromptBuilder)

@available(iOS 26.0, *)
private extension FoundationModelsSageAdviceProvider {

    static func determineCategory(for context: SageContext) -> SageAdviceCategory {
        SagePromptBuilder.determineCategory(for: context)
    }

    static let toneForCategory: [SageAdviceCategory: SageAdviceTone] =
        SagePromptBuilder.toneForCategory
}
