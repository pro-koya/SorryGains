import Foundation

/// 助言プロバイダープロトコル — LocalとLLMの切り替えを可能にする
protocol SageAdviceProvider: Sendable {
    func provideAdvice(for context: SageContext) async -> SageAdvice
}
