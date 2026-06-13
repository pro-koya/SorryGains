import SwiftUI

/// Brief celebration overlay shown when a new achievement is unlocked.
struct AchievementUnlockOverlay: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var iconScale: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.opacity(isVisible ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismissWithAnimation() }

            VStack(spacing: Spacing.md) {
                // Badge icon
                Image(systemName: achievement.symbolName)
                    .font(.system(size: 48))
                    .foregroundStyle(rarityColor)
                    .scaleEffect(iconScale)
                    .shadow(color: rarityColor.opacity(0.5), radius: 16)

                Text("実績解除！")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.SG.textPrimary)

                Text(achievement.localizedName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(rarityColor)

                Text(achievement.description)
                    .font(.SG.caption)
                    .foregroundStyle(Color.SG.textSecondary)
                    .multilineTextAlignment(.center)

                Text(achievement.rarity.localizedName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(rarityColor)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(rarityColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                    .fill(Color.SG.surface)
                    .shadow(color: rarityColor.opacity(0.3), radius: 24)
            )
            .padding(.horizontal, Spacing.xl)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.8)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                isVisible = true
            }
            withAnimation(.spring(duration: 0.6, bounce: 0.5).delay(0.2)) {
                iconScale = 1.0
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(4))
            dismissWithAnimation()
        }
    }

    private func dismissWithAnimation() {
        withAnimation(.easeIn(duration: 0.2)) {
            isVisible = false
            iconScale = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }

    private var rarityColor: Color {
        switch achievement.rarity {
        case .common: return Color.SG.apologyMild
        case .uncommon: return Color.SG.accent
        case .rare: return Color.SG.apologyModerate
        case .legendary: return Color.SG.apologyMax
        }
    }
}
