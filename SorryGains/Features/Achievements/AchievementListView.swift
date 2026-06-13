import SwiftUI

/// Grid display of all achievement badges, showing unlocked and locked states.
struct AchievementListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var tracker: AchievementTracker

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: Spacing.sm),
        count: 3
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    progressHeader

                    LazyVGrid(columns: columns, spacing: Spacing.sm) {
                        ForEach(sortedAchievements) { achievement in
                            badgeCell(achievement)
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .navigationTitle("実績バッジ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: Spacing.xs) {
            Text("\(tracker.unlockedAchievements.count) / \(Achievement.allCases.count)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.SG.accent)

            Text("獲得済みバッジ")
                .font(.SG.caption)
                .foregroundStyle(Color.SG.textSecondary)

            // Progress bar
            GeometryReader { geometry in
                let progress = CGFloat(tracker.unlockedAchievements.count) / CGFloat(Achievement.allCases.count)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.SG.surface)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.SG.accent)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(Spacing.cardPadding)
        .background(Color.SG.surface)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
    }

    // MARK: - Badge Cell

    private func badgeCell(_ achievement: Achievement) -> some View {
        let isUnlocked = tracker.unlockedAchievements.contains(achievement)

        return VStack(spacing: Spacing.xs) {
            // Icon
            Image(systemName: achievement.symbolName)
                .font(.system(size: 28))
                .foregroundStyle(isUnlocked ? rarityColor(achievement.rarity) : Color.SG.textSecondary.opacity(0.3))
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(isUnlocked
                              ? rarityColor(achievement.rarity).opacity(0.15)
                              : Color.SG.surface)
                )

            // Name
            Text(achievement.localizedName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isUnlocked ? Color.SG.textPrimary : Color.SG.textSecondary.opacity(0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Description
            Text(achievement.description)
                .font(.system(size: 9))
                .foregroundStyle(Color.SG.textSecondary.opacity(isUnlocked ? 0.8 : 0.4))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Rarity
            Text(achievement.rarity.localizedName)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(isUnlocked ? rarityColor(achievement.rarity) : Color.SG.textSecondary.opacity(0.3))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(isUnlocked
                              ? rarityColor(achievement.rarity).opacity(0.12)
                              : Color.SG.surface)
                )
        }
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity)
        .opacity(isUnlocked ? 1.0 : 0.5)
    }

    // MARK: - Helpers

    private var sortedAchievements: [Achievement] {
        Achievement.allCases.sorted { a, b in
            let aUnlocked = tracker.unlockedAchievements.contains(a)
            let bUnlocked = tracker.unlockedAchievements.contains(b)
            if aUnlocked != bUnlocked { return aUnlocked }
            return a.rarity > b.rarity
        }
    }

    private func rarityColor(_ rarity: Achievement.Rarity) -> Color {
        switch rarity {
        case .common: return Color.SG.apologyMild
        case .uncommon: return Color.SG.accent
        case .rare: return Color.SG.apologyModerate
        case .legendary: return Color.SG.apologyMax
        }
    }
}
