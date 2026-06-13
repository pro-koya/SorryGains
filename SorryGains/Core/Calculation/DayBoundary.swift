import Foundation

/// 1日の起点を午前4時とする日付境界ユーティリティ。
/// 深夜まで飲む生活パターンを考慮し、0:00〜3:59 は「前日」扱いとする。
enum DayBoundary {
    static let resetHour = 4

    /// 現在時刻に基づく「今日の起点」を返す。
    /// 午前4時未満なら前日の4:00、午前4時以降なら当日の4:00。
    static func startOfToday(now: Date = .now, calendar: Calendar = .current) -> Date {
        let hour = calendar.component(.hour, from: now)
        let calendarDay = calendar.startOfDay(for: now)

        if hour < resetHour {
            // 午前4時前 → 前日の4:00が起点
            let yesterday = calendar.date(byAdding: .day, value: -1, to: calendarDay)!
            return calendar.date(bySettingHour: resetHour, minute: 0, second: 0, of: yesterday)!
        }
        return calendar.date(bySettingHour: resetHour, minute: 0, second: 0, of: calendarDay)!
    }

    /// 指定された日付が「今日」に属するかを判定する。
    static func isToday(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        let todayStart = startOfToday(now: now, calendar: calendar)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        return date >= todayStart && date < tomorrowStart
    }

    /// 「今週」の起点を返す（7日前の同リセット時刻）。
    static func startOfThisWeek(now: Date = .now, calendar: Calendar = .current) -> Date {
        let todayStart = startOfToday(now: now, calendar: calendar)
        return calendar.date(byAdding: .day, value: -6, to: todayStart)!
    }

    /// 昨日の起点を返す（今日の起点の1日前）。
    static func startOfYesterday(now: Date = .now, calendar: Calendar = .current) -> Date {
        let todayStart = startOfToday(now: now, calendar: calendar)
        return calendar.date(byAdding: .day, value: -1, to: todayStart)!
    }

    /// 指定された日付が「昨日」に属するかを判定する。
    static func isYesterday(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        let yesterdayStart = startOfYesterday(now: now, calendar: calendar)
        let todayStart = startOfToday(now: now, calendar: calendar)
        return date >= yesterdayStart && date < todayStart
    }

    /// 今日の終了時刻（＝明日の起点）を返す。リカバリー期限の表示に使用。
    static func endOfToday(now: Date = .now, calendar: Calendar = .current) -> Date {
        let todayStart = startOfToday(now: now, calendar: calendar)
        return calendar.date(byAdding: .day, value: 1, to: todayStart)!
    }

    /// 指定日時が属する「4時区切りの日」の起点を返す。
    static func startOfDay(containing date: Date, calendar: Calendar = .current) -> Date {
        startOfToday(now: date, calendar: calendar)
    }
}
