import SwiftUI

/// A visually striking share card for SNS.
///
/// Designed for Instagram Story (9:16) and square (1:1) formats.
/// Includes character, anger level bar, drink breakdown, and hashtag.
struct DamageReportCardView: View {
    let date: Date
    let records: [DrinkRecord]
    let impact: DailyImpactResult
    let characterStage: Int
    let sessionDuration: String?

    private var totalAlcoholGram: Double {
        records.reduce(0) { total, record in
            total + record.volumeML * (record.alcoholPercent / 100) * 0.8
        }
    }

    private var drinkSummaries: [DrinkTypeSummary] {
        DrinkAnalytics.makeDrinkTypeSummaries(from: records)
    }

    private var toneColor: Color {
        Color.SG.apologyColor(for: min(5, max(1, impact.angerLevel)))
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d (E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Text("DAMAGE REPORT")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(toneColor)
                Spacer()
                Text(dateText)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.SG.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Character + anger bar
            HStack(spacing: 16) {
                MuscleCharacterView(
                    stage: characterStage,
                    animate: false,
                    showCaption: false
                )
                .frame(width: 100, height: 100)

                VStack(alignment: .leading, spacing: 8) {
                    // Anger bar
                    VStack(alignment: .leading, spacing: 4) {
                        Text("怒り度")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.SG.textSecondary)

                        HStack(spacing: 3) {
                            ForEach(1...5, id: \.self) { level in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(level <= impact.angerLevel
                                          ? toneColor
                                          : Color.SG.textSecondary.opacity(0.2))
                                    .frame(height: 12)
                            }
                        }
                    }

                    // Key metrics
                    HStack(spacing: 12) {
                        miniMetric(
                            value: "\(records.count)",
                            unit: "杯"
                        )
                        miniMetric(
                            value: String(format: "%.0f", totalAlcoholGram),
                            unit: "g"
                        )
                        if let duration = sessionDuration {
                            miniMetric(
                                value: duration,
                                unit: ""
                            )
                        }
                    }

                    // Verdict
                    Text(verdictText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(toneColor)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // Drink breakdown
            if !drinkSummaries.isEmpty {
                Divider()
                    .overlay(Color.SG.textSecondary.opacity(0.15))
                    .padding(.horizontal, 20)

                VStack(spacing: 6) {
                    ForEach(drinkSummaries) { summary in
                        HStack(spacing: 8) {
                            Image(systemName: summary.drinkType.symbolName)
                                .font(.system(size: 12))
                                .foregroundStyle(toneColor)
                                .frame(width: 20)

                            Text(summary.drinkType.localizedName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.SG.textPrimary)

                            Spacer()

                            Text("×\(summary.count)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(toneColor)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }

            // Bottom bar with branding
            HStack {
                Text("#筋肉ごめん")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(toneColor.opacity(0.7))

                Spacer()

                Text("筋肉ごめん")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.SG.textSecondary.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.SG.surface.opacity(0.5))
        }
        .frame(width: 320)
        .background(Color.SG.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(toneColor.opacity(0.3), lineWidth: 1.5)
        )
    }

    // MARK: - Helpers

    private func miniMetric(value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.SG.textPrimary)
            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.SG.textSecondary)
            }
        }
    }

    private var verdictText: String {
        switch impact.angerLevel {
        case 0: return String(localized: "verdict.lvl0.daily")
        case 1: return String(localized: "verdict.lvl1")
        case 2: return String(localized: "verdict.lvl2.daily")
        case 3: return String(localized: "verdict.lvl3")
        case 4: return String(localized: "verdict.lvl4.daily")
        default: return String(localized: "verdict.lvl5")
        }
    }
}
