import SwiftData
import SwiftUI

/// Full weekly report view accessible from the Sage tab.
///
/// Shows a heatmap, key metrics, pattern detection results,
/// and a sage commentary on the week.
struct WeeklyReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \DrinkRecord.timestamp, order: .reverse)
    private var allRecords: [DrinkRecord]
    @Query(sort: \DailyRecoveryLog.date, order: .reverse)
    private var recoveryLogs: [DailyRecoveryLog]
    @Query(sort: \DailyTrainingStatus.date, order: .reverse)
    private var trainingStatuses: [DailyTrainingStatus]

    private var report: WeeklyReport {
        WeeklyReportBuilder.build(
            records: Array(allRecords),
            recoveryLogs: Array(recoveryLogs),
            trainingStatuses: Array(trainingStatuses)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    heatmapSection
                    metricsSection
                    patternsSection
                    sageCommentSection
                    worstDaySection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .navigationTitle("週間レポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        SGCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("飲酒ヒートマップ（4週間）")
                    .font(.SG.headline)
                    .foregroundStyle(Color.SG.textPrimary)

                DrinkingHeatmapView(dailyData: report.dailyData)
            }
        }
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                metricCard(
                    icon: "mug.fill",
                    label: "飲酒日数",
                    value: "\(report.drinkingDays)",
                    unit: "日",
                    color: Color.SG.apologySevere
                )

                metricCard(
                    icon: "figure.strengthtraining.traditional",
                    label: "筋トレ日数",
                    value: "\(report.trainingDays)",
                    unit: "日",
                    color: Color.SG.apologyMild
                )
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: Spacing.sm) {
                metricCard(
                    icon: "drop.fill",
                    label: "総アルコール",
                    value: String(format: "%.0f", report.totalAlcoholGram),
                    unit: "g",
                    color: Color.SG.apologyModerate
                )

                metricCard(
                    icon: "heart.circle.fill",
                    label: "お詫び達成率",
                    value: String(format: "%.0f", report.recoveryRate * 100),
                    unit: "%",
                    color: Color.SG.accent
                )
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Patterns

    @ViewBuilder
    private var patternsSection: some View {
        if !report.patterns.isEmpty {
            SGCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("パターン検出")
                        .font(.SG.headline)
                        .foregroundStyle(Color.SG.textPrimary)

                    ForEach(report.patterns) { pattern in
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: patternIcon(pattern.type))
                                .font(.title3)
                                .foregroundStyle(Color.SG.apologySevere)
                                .frame(width: 28)

                            Text(pattern.description)
                                .font(.SG.body)
                                .foregroundStyle(Color.SG.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sage Comment

    private var sageCommentSection: some View {
        SGCard {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "person.fill.questionmark")
                    .font(.title2)
                    .foregroundStyle(Color.SG.accent)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("仙人の一言")
                        .font(.SG.caption)
                        .foregroundStyle(Color.SG.textSecondary)

                    Text(report.sageComment)
                        .font(.SG.body)
                        .foregroundStyle(Color.SG.textPrimary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Worst Day

    @ViewBuilder
    private var worstDaySection: some View {
        if let worst = report.worstDay, worst.drinkCount > 0 {
            SGCard {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("今週の最大ダメージ日")
                        .font(.SG.headline)
                        .foregroundStyle(Color.SG.textPrimary)

                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "flame.fill")
                            .font(.title2)
                            .foregroundStyle(Color.SG.apologyMax)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(worstDayDateText(worst.date))
                                .font(.SG.body)
                                .foregroundStyle(Color.SG.textPrimary)
                            Text("\(worst.drinkCount)杯 / \(String(format: "%.0f", worst.totalAlcoholGram))g")
                                .font(.SG.caption)
                                .foregroundStyle(Color.SG.textSecondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func metricCard(
        icon: String,
        label: LocalizedStringKey,
        value: String,
        unit: LocalizedStringKey,
        color: Color
    ) -> some View {
        SGCard {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.SG.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.SG.textPrimary)
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.SG.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private func patternIcon(_ type: DrinkingPattern.PatternType) -> String {
        switch type {
        case .heaviestDay: return "calendar.badge.exclamationmark"
        case .consecutiveStreak: return "flame"
        case .trainThenDrink: return "figure.strengthtraining.traditional"
        }
    }

    private func worstDayDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MdEEEE")
        return formatter.string(from: date)
    }
}
