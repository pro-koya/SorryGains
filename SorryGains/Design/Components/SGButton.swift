import SwiftUI

struct SGButton: View {
    let title: LocalizedStringKey
    let icon: String?
    let style: Style
    let action: () -> Void

    enum Style {
        case primary
        case secondary
        case ghost
    }

    private static let minimumTouchTarget: CGFloat = 44

    init(
        _ title: LocalizedStringKey,
        icon: String? = nil,
        style: Style = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(.SG.headline)
            .frame(maxWidth: .infinity, minHeight: Self.minimumTouchTarget)
            .padding(.horizontal, Spacing.lg)
            .background(backgroundView)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
        }
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            Color.SG.accent
        case .secondary:
            Color.SG.accent.opacity(0.15)
        case .ghost:
            Color.clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: .white
        case .secondary: Color.SG.accent
        case .ghost: Color.SG.accent
        }
    }
}
