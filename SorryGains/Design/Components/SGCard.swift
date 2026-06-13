import SwiftUI

struct SGCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.cardPadding)
            .background(Color.SG.surface)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                    .stroke(Color.SG.textSecondary.opacity(0.15), lineWidth: 1)
            )
    }
}
