import SwiftUI

extension Color {
    enum SG {
        static let background = Color("Background")
        static let surface = Color("Surface")
        static let accent = Color("AccentColor")
        static let textPrimary = Color("TextPrimary")
        static let textSecondary = Color("TextSecondary")

        static let apologyMild = Color("ApologyMild")
        static let apologyModerate = Color("ApologyModerate")
        static let apologySevere = Color("ApologySevere")
        static let apologyCritical = Color("ApologyCritical")
        static let apologyMax = Color("ApologyMax")

        static func apologyColor(for level: Int) -> Color {
            switch level {
            case 1: apologyMild
            case 2: apologyModerate
            case 3: apologySevere
            case 4: apologyCritical
            default: apologyMax
            }
        }
    }
}
