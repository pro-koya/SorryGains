import Foundation

/// 決定論的な乱数生成器。
/// 同じシード値を渡すと毎回同じ乱数列が得られる（xorshift64 アルゴリズム）。
///
/// 主な用途: 同日・同コンテキストで仙人助言を一意に定める。
struct SeededRandomNumberGenerator: RandomNumberGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        // seed が 0 だと xorshift が全て 0 になるため最低 1 を保証
        self.state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - Factory

extension SeededRandomNumberGenerator {

    /// 日付と `SageContext` の主要フィールドからシード値を生成する。
    /// 同日・同コンテキストなら常に同じ値になる。
    static func seed(for context: SageContext, date: Date = Date()) -> UInt64 {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year  = UInt64(components.year  ?? 0)
        let month = UInt64(components.month ?? 0)
        let day   = UInt64(components.day   ?? 0)

        // 各フィールドを LCG 定数でミックスし、衝突しにくいシードを作る
        var seed: UInt64 = year &* 10_000 &+ month &* 100 &+ day
        seed = seed &* 6_364_136_223_846_793_005 &+ UInt64(context.todayDrinkCount)
        seed = seed &* 6_364_136_223_846_793_005 &+ UInt64(context.consecutiveDrinkingDays)
        seed = seed &* 6_364_136_223_846_793_005 &+ UInt64(context.weekDrinkCount)
        seed = seed &* 6_364_136_223_846_793_005 &+ UInt64(context.weekTrainingDays)
        seed = seed &* 6_364_136_223_846_793_005 &+ UInt64(context.todayTotalAlcoholGram * 10)
        return seed == 0 ? 1 : seed
    }

    /// 日付と `SageContext` からシードを生成して初期化する。
    static func make(date: Date = Date(), context: SageContext) -> SeededRandomNumberGenerator {
        SeededRandomNumberGenerator(seed: seed(for: context, date: date))
    }
}
