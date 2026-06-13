import SwiftUI

/// End-of-session damage report shown when the user stops a drinking session.
///
/// Summarizes the session duration, total drinks, breakdown by type,
/// and overall impact on muscles. Includes a share button.
struct SessionReportView: View {
    @Environment(\.dismiss) private var dismiss

    let session: DrinkingSession
    let records: [DrinkRecord]
    let impact: DailyImpactResult
    let characterStage: Int
    let onShare: () -> Void

    private var drinkSummaries: [DrinkTypeSummary] {
        DrinkAnalytics.makeDrinkTypeSummaries(from: records)
    }

    private var totalAlcoholGram: Double {
        records.reduce(0) { total, record in
            total + record.volumeML * (record.alcoholPercent / 100) * 0.8
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    headerSection
                    characterSection
                    metricsSection
                    drinkBreakdownSection
                    actionButtons
                }
                .padding(Spacing.md)
            }
            .navigationTitle("ダメージレポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Spacing.xs) {
            Text("飲み会終了！")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.SG.textPrimary)

            HStack(spacing: Spacing.md) {
                Label(session.durationText, systemImage: "clock")
                Label("\(records.count)杯", systemImage: "mug.fill")
            }
            .font(.SG.body)
            .foregroundStyle(Color.SG.textSecondary)
        }
    }

    // MARK: - Character

    private var characterSection: some View {
        VStack(spacing: Spacing.sm) {
            MuscleCharacterView(
                stage: characterStage,
                animate: true,
                showCaption: true
            )
            .frame(height: 140)

            Text(sessionVerdict)
                .font(.SG.headline)
                .foregroundStyle(Color.SG.apologyColor(for: min(5, impact.angerLevel)))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        HStack(spacing: 0) {
            metricColumn(
                label: impact.didTrainToday ? "筋トレ成果減少度" : "筋肉ダウン",
                value: String(format: "%.0f", impact.wastedPercent),
                unit: "%"
            )

            metricDivider

            metricColumn(
                label: "怒り度",
                value: "\(impact.angerLevel)",
                unit: "/ 5"
            )

            metricDivider

            metricColumn(
                label: "純アルコール",
                value: String(format: "%.0f", totalAlcoholGram),
                unit: "g"
            )
        }
        .padding(.vertical, Spacing.sm)
        .background(Color.SG.surface)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                .stroke(toneColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Drink Breakdown

    @ViewBuilder
    private var drinkBreakdownSection: some View {
        if !drinkSummaries.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("飲んだもの")
                    .font(.SG.headline)
                    .foregroundStyle(Color.SG.textPrimary)

                ForEach(drinkSummaries) { summary in
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: summary.drinkType.symbolName)
                            .font(.title3)
                            .foregroundStyle(toneColor)
                            .frame(width: 28)

                        Text(summary.drinkType.localizedName)
                            .font(.SG.body)
                            .foregroundStyle(Color.SG.textPrimary)

                        Spacer()

                        Text("×\(summary.count)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(toneColor)

                        Text("\(Int(summary.totalVolumeML))ml")
                            .font(.SG.caption)
                            .foregroundStyle(Color.SG.textSecondary)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .padding(.vertical, Spacing.xxs)
                }
            }
            .padding(Spacing.cardPadding)
            .background(Color.SG.surface)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: Spacing.sm) {
            SGButton("シェアする", icon: "square.and.arrow.up") {
                onShare()
            }

            SGButton("閉じる", style: .secondary) {
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    private var toneColor: Color {
        Color.SG.apologyColor(for: min(5, max(1, impact.angerLevel)))
    }

    private var sessionVerdict: String {
        switch impact.angerLevel {
        case 0: return String(localized: "verdict.lvl0.session")
        case 1: return String(localized: "verdict.lvl1")
        case 2: return String(localized: "verdict.lvl2.session")
        case 3: return String(localized: "verdict.lvl3")
        case 4: return String(localized: "verdict.lvl4.session")
        default: return String(localized: "verdict.lvl5")
        }
    }

    private func metricColumn(label: LocalizedStringKey, value: String, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.SG.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(toneColor)
                Text(unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.SG.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var metricDivider: some View {
        Divider()
            .frame(height: 36)
            .overlay(Color.SG.textSecondary.opacity(0.2))
    }
}
