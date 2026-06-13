import Foundation
import SwiftUI

/// 仙人助言クレジットの永続化ストア。
/// - 1日3回まで広告なしで助言を引き出せる「フリークレジット」を提供する
/// - 広告視聴で得られる「ボーナスクレジット」は日跨ぎでも持ち越される
/// - フリークレジットは DayBoundary（午前4時）でリセット
@MainActor
final class SageAdviceCreditsStore: ObservableObject {
    static let dailyFreeCredits = 3
    private static let lastResetKey = "sage.credits.lastResetDate"
    private static let freeUsedKey = "sage.credits.freeUsedToday"
    private static let bonusKey = "sage.credits.bonusCredits"

    @Published private(set) var freeRemaining: Int
    @Published private(set) var bonusCredits: Int

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = Self.refreshIfNeeded(defaults: defaults)
        self.freeRemaining = stored.freeRemaining
        self.bonusCredits = stored.bonus
    }

    /// 利用可能な総クレジット数（フリー残 + ボーナス）
    var totalAvailable: Int {
        freeRemaining + bonusCredits
    }

    /// クレジットを1消費して助言生成可否を返す。
    /// フリーを優先消費し、尽きたらボーナスを使う。
    @discardableResult
    func consumeOne() -> Bool {
        refreshIfDayChanged()
        if freeRemaining > 0 {
            let used = defaults.integer(forKey: Self.freeUsedKey) + 1
            defaults.set(used, forKey: Self.freeUsedKey)
            freeRemaining = max(0, Self.dailyFreeCredits - used)
            return true
        }
        if bonusCredits > 0 {
            let next = bonusCredits - 1
            defaults.set(next, forKey: Self.bonusKey)
            bonusCredits = next
            return true
        }
        return false
    }

    /// 広告視聴成功時に呼ばれ、ボーナスクレジットを1加算する。
    func addBonusCredit() {
        refreshIfDayChanged()
        let next = bonusCredits + 1
        defaults.set(next, forKey: Self.bonusKey)
        bonusCredits = next
    }

    /// アプリ復帰時などに日付リセットを反映する。
    func refreshIfDayChanged() {
        let stored = Self.refreshIfNeeded(defaults: defaults)
        if stored.freeRemaining != freeRemaining {
            freeRemaining = stored.freeRemaining
        }
        if stored.bonus != bonusCredits {
            bonusCredits = stored.bonus
        }
    }

    /// 日付が変わっていればフリー使用回数をクリアし、現在の残量とボーナスを返す。
    @discardableResult
    private static func refreshIfNeeded(
        defaults: UserDefaults
    ) -> (freeRemaining: Int, bonus: Int) {
        let todayStart = DayBoundary.startOfToday()
        let lastReset = defaults.object(forKey: lastResetKey) as? Date

        let used: Int
        if lastReset == nil || lastReset! < todayStart {
            defaults.set(todayStart, forKey: lastResetKey)
            defaults.set(0, forKey: freeUsedKey)
            used = 0
        } else {
            used = defaults.integer(forKey: freeUsedKey)
        }

        let remaining = max(0, dailyFreeCredits - used)
        let bonus = max(0, defaults.integer(forKey: bonusKey))
        return (remaining, bonus)
    }
}
