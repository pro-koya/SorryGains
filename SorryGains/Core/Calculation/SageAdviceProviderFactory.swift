import Foundation

/// 環境に応じた SageAdviceProvider を返すファクトリ。
/// - iOS 26+: Apple Foundation Models（オンデバイスLLM）
/// - iOS 17–25: 強化テンプレートエンジン（断片組み合わせ生成）
enum SageAdviceProviderFactory {

    static func make() -> any SageAdviceProvider {
        if #available(iOS 26.0, *) {
            return FoundationModelsSageAdviceProvider()
        }
        return LocalSageAdviceProvider()
    }
}
