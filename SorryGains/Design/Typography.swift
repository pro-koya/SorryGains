import SwiftUI

extension Font {
    enum SG {
        static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
        static let title = Font.system(.title, design: .rounded, weight: .bold)
        static let title2 = Font.system(.title2, design: .rounded, weight: .semibold)
        static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
        static let body = Font.system(.body, design: .rounded)
        static let caption = Font.system(.caption, design: .rounded)
        static let footnote = Font.system(.footnote, design: .rounded)

        static let numericDisplay = Font.system(.largeTitle, design: .monospaced, weight: .bold)
        static let numericBody = Font.system(.title, design: .monospaced, weight: .semibold)
    }
}
