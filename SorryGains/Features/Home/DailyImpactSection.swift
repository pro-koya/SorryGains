import SwiftData
import SwiftUI

struct DailyImpactSection: View {
    let todayImpact: DailyImpactResult
    let yesterdayImpact: DailyImpactResult
    let yesterdayRecoveryLog: DailyRecoveryLog?
    let recoveryDeadline: Date
    let weeklyImpactScore: Double
    let weeklyDrinkCount: Int
    let totalImpactScore: Double
    let totalDrinkCount: Int
    let onShowRecoverySheet: () -> Void

    @State private var selectedTab = 0
    @State private var showGuide = false

    // MARK: - Computed (Yesterday Recovery)

    private var yesterdayAngerReduction: Int {
        yesterdayRecoveryLog?.angerReduction ?? 0
    }

    private var effectiveYesterdayAngerLevel: Int {
        max(0, yesterdayImpact.angerLevel - yesterdayAngerReduction)
    }

    private var effectiveYesterdayImpactScore: Double {
        max(0, yesterdayImpact.impactScore - (yesterdayRecoveryLog?.totalScoreReduction ?? 0))
    }

    private var isYesterdayForgiven: Bool {
        effectiveYesterdayAngerLevel == 0 && yesterdayImpact.drinkCount > 0
    }

    private var hasYesterdayPending: Bool {
        yesterdayImpact.drinkCount > 0 && !isYesterdayForgiven
    }

    private var yesterdayCompletedCount: Int {
        yesterdayRecoveryLog?.completedActionRawValues.count ?? 0
    }

    // MARK: - Tone

    private var toneColor: Color {
        if hasYesterdayPending {
            return Color.SG.apologyColor(for: effectiveYesterdayAngerLevel)
        }
        if todayImpact.drinkCount > 0 {
            return Color.SG.apologyColor(for: todayImpact.angerLevel)
        }
        if isYesterdayForgiven {
            return Color.SG.apologyMild
        }
        return Color.SG.apologyMild
    }

    private var headerTitleKey: LocalizedStringKey {
        switch selectedTab {
        case 0: return "ステータス"
        case 1: return "今週の影響度"
        default: return "これまでの影響度"
        }
    }

    private var tabTitleKeys: [LocalizedStringKey] {
        ["ステータス", "今週", "累計"]
    }

    private var remainingTimeText: String {
        let remaining = recoveryDeadline.timeIntervalSince(.now)
        guard remaining > 0 else { return String(localized: "deadline.expired") }
        let hours = Int(remaining / 3600)
        if hours > 0 {
            return String(format: String(localized: "deadline.remainingHours"), hours)
        }
        let minutes = max(1, Int(remaining / 60) % 60)
        return String(format: String(localized: "deadline.remainingMinutes"), minutes)
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            headerRow

            tabPicker

            switch selectedTab {
            case 0: statusTab
            case 1: weeklyMetrics
            default: totalMetrics
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Text(headerTitleKey)
                .font(.SG.headline)
                .foregroundStyle(Color.SG.textPrimary)

            Button { showGuide = true } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.SG.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            if selectedTab == 0 && isYesterdayForgiven && todayImpact.drinkCount == 0 {
                Label("許してもらえた", systemImage: "heart.fill")
                    .font(.SG.caption)
                    .foregroundStyle(Color.SG.apologyMild)
            }
        }
        .sheet(isPresented: $showGuide) {
            ImpactGuideSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabTitleKeys.enumerated()), id: \.offset) { index, label in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
                } label: {
                    Text(label)
                        .font(.system(size: 12, weight: selectedTab == index ? .bold : .medium))
                        .foregroundStyle(selectedTab == index ? Color.SG.accent : Color.SG.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(
                            selectedTab == index
                                ? Color.SG.accent.opacity(0.12)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.SG.surface)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))
    }

    // MARK: - Status Tab

    @ViewBuilder
    private var statusTab: some View {
        VStack(spacing: Spacing.sm) {
            if yesterdayImpact.drinkCount > 0 {
                recoveryBanner
            }

            if todayImpact.drinkCount > 0 {
                todayDrinkingCard
            }

            if yesterdayImpact.drinkCount == 0 && todayImpact.drinkCount == 0 {
                allClearCard
            }
        }
    }

    // MARK: - Recovery Banner

    @ViewBuilder
    private var recoveryBanner: some View {
        if isYesterdayForgiven {
            forgivenBanner
        } else {
            pendingRecoveryBanner
        }
    }

    private var forgivenBanner: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.SG.apologyMild)

            VStack(alignment: .leading, spacing: 2) {
                Text("昨日の飲酒 — 許してもらえた！")
                    .font(.SG.headline)
                    .foregroundStyle(Color.SG.apologyMild)
                if yesterdayCompletedCount > 0 {
                    Text("\(yesterdayCompletedCount)つのお詫び行動を達成")
                        .font(.SG.caption)
                        .foregroundStyle(Color.SG.textSecondary)
                }
            }

            Spacer()
        }
        .padding(Spacing.cardPadding)
        .background(Color.SG.surface)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                .stroke(Color.SG.apologyMild.opacity(0.3), lineWidth: 1)
        )
    }

    private var pendingRecoveryBanner: some View {
        VStack(spacing: Spacing.sm) {
            // Header: 昨日の飲酒情報 + カウントダウン
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("昨日は\(yesterdayImpact.drinkCount)杯飲んだね")
                    .font(.SG.headline)
                    .foregroundStyle(Color.SG.textPrimary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(remainingTimeText)
                        .font(.SG.caption)
                }
                .foregroundStyle(Color.SG.textSecondary)
            }

            // 昨日の影響メトリクス
            HStack(spacing: 0) {
                impactColumn(
                    label: "怒り度",
                    value: "\(effectiveYesterdayAngerLevel)",
                    unit: "/ 5"
                )

                metricDivider

                impactColumn(
                    label: "影響スコア",
                    value: String(format: "%.0f", effectiveYesterdayImpactScore),
                    unit: "/ 100"
                )
            }
            .padding(.vertical, Spacing.xs)

            // リカバリーアクションボタン
            Button(action: onShowRecoverySheet) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "list.bullet.clipboard.fill")
                    Text("お詫び行動でカバーする")
                    if yesterdayCompletedCount > 0 {
                        Text("(\(yesterdayCompletedCount)/\(RecoveryActionType.allCases.count))")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.SG.caption)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(Color.SG.accent.opacity(0.15))
                .foregroundStyle(Color.SG.accent)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.cardPadding)
        .background(Color.SG.surface)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                .stroke(toneColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Today Drinking Card

    private var todayDrinkingCard: some View {
        VStack(spacing: Spacing.xs) {
            if yesterdayImpact.drinkCount > 0 {
                HStack {
                    Text("今日の飲酒")
                        .font(.SG.caption)
                        .foregroundStyle(Color.SG.textSecondary)
                    Spacer()
                }
            }

            metricsContainer {
                impactColumn(
                    label: todayImpact.didTrainToday ? "筋トレ成果減少度" : "筋肉ダウン",
                    value: String(format: "%.0f", todayImpact.wastedPercent),
                    unit: "%"
                )

                metricDivider

                impactColumn(
                    label: "怒り度",
                    value: "\(todayImpact.angerLevel)",
                    unit: "/ 5"
                )

                metricDivider

                impactColumn(
                    label: "影響スコア",
                    value: String(format: "%.0f", todayImpact.impactScore),
                    unit: "/ 100"
                )
            }
        }
    }

    // MARK: - All Clear

    private var allClearCard: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "hand.thumbsup.fill")
                .font(.title3)
                .foregroundStyle(Color.SG.accent)

            Text("飲酒の影響なし！この調子！")
                .font(.SG.headline)
                .foregroundStyle(Color.SG.textPrimary)

            Spacer()
        }
        .padding(Spacing.cardPadding)
        .background(Color.SG.surface)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
    }

    // MARK: - Weekly Metrics

    private var weeklyMetrics: some View {
        metricsContainer {
            impactColumn(
                label: "飲酒回数",
                value: "\(weeklyDrinkCount)",
                unit: "杯"
            )

            metricDivider

            impactColumn(
                label: "影響スコア合計",
                value: String(format: "%.0f", weeklyImpactScore),
                unit: "pt"
            )

            metricDivider

            impactColumn(
                label: "1日平均",
                value: String(format: "%.0f", weeklyDrinkCount > 0 ? weeklyImpactScore / 7 : 0),
                unit: "pt"
            )
        }
    }

    // MARK: - Total Metrics

    private var totalMetrics: some View {
        metricsContainer {
            impactColumn(
                label: "総飲酒回数",
                value: "\(totalDrinkCount)",
                unit: "杯"
            )

            metricDivider

            impactColumn(
                label: "影響スコア合計",
                value: String(format: "%.0f", totalImpactScore),
                unit: "pt"
            )

            metricDivider

            impactColumn(
                label: "1杯平均",
                value: String(format: "%.1f", totalDrinkCount > 0 ? totalImpactScore / Double(totalDrinkCount) : 0),
                unit: "pt"
            )
        }
    }

    // MARK: - Shared Components

    private func metricsContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) {
            content()
        }
        .padding(.vertical, Spacing.sm)
        .background(Color.SG.surface)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                .stroke(toneColor.opacity(0.2), lineWidth: 1)
        )
    }

    private var metricDivider: some View {
        Divider()
            .frame(height: 36)
            .overlay(Color.SG.textSecondary.opacity(0.2))
    }

    private func impactColumn(label: LocalizedStringKey, value: String, unit: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.SG.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(toneColor)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.SG.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
