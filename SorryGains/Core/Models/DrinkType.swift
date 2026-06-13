import SwiftUI

enum DrinkType: String, Codable, CaseIterable, Identifiable {
    case beer
    case highball
    case sour
    case sake
    case wine
    case other

    var id: String { rawValue }

    var defaultAlcoholPercent: Double {
        switch self {
        case .beer: 5.0
        case .highball: 7.0
        case .sour: 5.0
        case .sake: 15.0
        case .wine: 12.0
        case .other: 5.0
        }
    }

    var defaultVolumeML: Double {
        switch self {
        case .beer: 350
        case .highball: 350
        case .sour: 350
        case .sake: 180
        case .wine: 125
        case .other: 350
        }
    }

    var localizedName: String {
        Bundle.main.localizedString(
            forKey: "drink_type.\(rawValue)",
            value: rawValue,
            table: nil
        )
    }

    var symbolName: String {
        switch self {
        case .beer: "mug.fill"
        case .highball: "waterbottle.fill"
        case .sour: "cup.and.saucer.fill"
        case .sake: "wineglass.fill"
        case .wine: "wineglass"
        case .other: "drop.fill"
        }
    }
}
