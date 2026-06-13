import SwiftUI

struct MetricCard: View {
    let title: LocalizedStringKey
    let value: String
    let unit: LocalizedStringKey
    let color: Color

    /// Plain-text label for VoiceOver (e.g. "Effort Saved").
    let accessibilityTitle: String

    /// Plain-text unit for VoiceOver (e.g. "percent", "hours").
    let accessibilityUnit: String

    init(
        title: LocalizedStringKey,
        value: String,
        unit: LocalizedStringKey,
        color: Color = Color.SG.accent,
        accessibilityTitle: String = "",
        accessibilityUnit: String = ""
    ) {
        self.title = title
        self.value = value
        self.unit = unit
        self.color = color
        self.accessibilityTitle = accessibilityTitle
        self.accessibilityUnit = accessibilityUnit
    }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(title)
                .font(.SG.caption)
                .foregroundStyle(Color.SG.textSecondary)

            Text(value)
                .font(.SG.numericDisplay)
                .foregroundStyle(color)
                .contentTransition(.numericText())

            Text(unit)
                .font(.SG.footnote)
                .foregroundStyle(Color.SG.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.cardPadding)
        .background(Color.SG.surface)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                .stroke(Color.SG.textSecondary.opacity(0.15), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue("\(value) \(accessibilityUnit)")
    }
}
