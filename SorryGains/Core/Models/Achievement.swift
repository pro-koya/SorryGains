import Foundation

/// Defines all achievement badges and their unlock conditions.
///
/// Achievements are checked dynamically against current data.
/// Unlocked achievements are persisted via UserDefaults.
enum Achievement: String, CaseIterable, Identifiable {
    // Discipline badges
    case steelWill            // 鋼の意志: 7日連続休肝
    case ironResolve          // 鉄の意志: 14日連続休肝
    case soberWeek            // 休肝ウィーク: 1週間で飲酒0日

    // Recovery badges
    case proteinMaster        // プロテインマスター: プロテインお詫び10回
    case recoveryPro          // 反省の達人: お詫び100%達成5日
    case firstRecovery        // はじめてのお詫び: お詫び行動を初めて完了

    // Relationship badges
    case muscleFriend         // 筋肉の親友: 怒りLv1以下を7日維持
    case forgivenTenTimes     // 許しの常連: 10回許してもらう

    // Extreme badges
    case nightOfCarnage       // 修羅場の夜: 1日で影響スコア90超え
    case fiveDrinkNight       // 五杯の夜: 1日5杯以上記録

    // Engagement badges
    case sageDisciple         // 仙人の弟子: 仙人のアドバイスを10回聞く
    case firstSession         // はじめての飲み会: 飲み会モードを初めて使う
    case centuryDrinker       // 百杯記念: 累計100杯記録

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .steelWill: return String(localized: "achievement.steelWill.name")
        case .ironResolve: return String(localized: "achievement.ironResolve.name")
        case .soberWeek: return String(localized: "achievement.soberWeek.name")
        case .proteinMaster: return String(localized: "achievement.proteinMaster.name")
        case .recoveryPro: return String(localized: "achievement.recoveryPro.name")
        case .firstRecovery: return String(localized: "achievement.firstRecovery.name")
        case .muscleFriend: return String(localized: "achievement.muscleFriend.name")
        case .forgivenTenTimes: return String(localized: "achievement.forgivenTenTimes.name")
        case .nightOfCarnage: return String(localized: "achievement.nightOfCarnage.name")
        case .fiveDrinkNight: return String(localized: "achievement.fiveDrinkNight.name")
        case .sageDisciple: return String(localized: "achievement.sageDisciple.name")
        case .firstSession: return String(localized: "achievement.firstSession.name")
        case .centuryDrinker: return String(localized: "achievement.centuryDrinker.name")
        }
    }

    var description: String {
        switch self {
        case .steelWill: return String(localized: "achievement.steelWill.desc")
        case .ironResolve: return String(localized: "achievement.ironResolve.desc")
        case .soberWeek: return String(localized: "achievement.soberWeek.desc")
        case .proteinMaster: return String(localized: "achievement.proteinMaster.desc")
        case .recoveryPro: return String(localized: "achievement.recoveryPro.desc")
        case .firstRecovery: return String(localized: "achievement.firstRecovery.desc")
        case .muscleFriend: return String(localized: "achievement.muscleFriend.desc")
        case .forgivenTenTimes: return String(localized: "achievement.forgivenTenTimes.desc")
        case .nightOfCarnage: return String(localized: "achievement.nightOfCarnage.desc")
        case .fiveDrinkNight: return String(localized: "achievement.fiveDrinkNight.desc")
        case .sageDisciple: return String(localized: "achievement.sageDisciple.desc")
        case .firstSession: return String(localized: "achievement.firstSession.desc")
        case .centuryDrinker: return String(localized: "achievement.centuryDrinker.desc")
        }
    }

    var symbolName: String {
        switch self {
        case .steelWill: return "shield.fill"
        case .ironResolve: return "shield.checkered"
        case .soberWeek: return "star.circle.fill"
        case .proteinMaster: return "cup.and.saucer.fill"
        case .recoveryPro: return "checkmark.seal.fill"
        case .firstRecovery: return "hand.raised.fill"
        case .muscleFriend: return "heart.fill"
        case .forgivenTenTimes: return "heart.circle.fill"
        case .nightOfCarnage: return "flame.fill"
        case .fiveDrinkNight: return "5.circle.fill"
        case .sageDisciple: return "book.fill"
        case .firstSession: return "party.popper.fill"
        case .centuryDrinker: return "trophy.fill"
        }
    }

    var rarity: Rarity {
        switch self {
        case .firstRecovery, .firstSession, .fiveDrinkNight:
            return .common
        case .soberWeek, .sageDisciple, .centuryDrinker, .nightOfCarnage:
            return .uncommon
        case .steelWill, .proteinMaster, .forgivenTenTimes:
            return .rare
        case .ironResolve, .recoveryPro, .muscleFriend:
            return .legendary
        }
    }

    enum Rarity: Int, Comparable {
        case common = 0
        case uncommon = 1
        case rare = 2
        case legendary = 3

        static func < (lhs: Rarity, rhs: Rarity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var localizedName: String {
            switch self {
            case .common: return String(localized: "achievement.rarity.common")
            case .uncommon: return String(localized: "achievement.rarity.uncommon")
            case .rare: return String(localized: "achievement.rarity.rare")
            case .legendary: return String(localized: "achievement.rarity.legendary")
            }
        }
    }
}
