import SwiftUI

// MARK: - Shareable Result View (off-screen rendering only)

/// A self-contained 360x360pt (1080x1080px @3x) share card.
/// Uses only literal colors -- never Color.SG.* -- because
/// ImageRenderer operates outside the live view hierarchy.
struct ShareableResultView: View {
    let result: ApologyResult
    let record: DrinkRecord

    var body: some View {
        ZStack {
            backgroundGradient
            cardContent
        }
        .frame(width: 360, height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var gradientColors: [Color] {
        switch result.angerLevel {
        case 1:
            return [Color(red: 0.56, green: 0.83, blue: 0.56),
                    Color(red: 0.40, green: 0.73, blue: 0.42)]
        case 2:
            return [Color(red: 0.98, green: 0.85, blue: 0.37),
                    Color(red: 0.95, green: 0.72, blue: 0.25)]
        case 3:
            return [Color(red: 1.0, green: 0.68, blue: 0.32),
                    Color(red: 0.96, green: 0.52, blue: 0.22)]
        case 4:
            return [Color(red: 0.96, green: 0.44, blue: 0.36),
                    Color(red: 0.90, green: 0.28, blue: 0.28)]
        case 5:
            return [Color(red: 0.80, green: 0.20, blue: 0.30),
                    Color(red: 0.55, green: 0.10, blue: 0.18)]
        default:
            return [Color(red: 0.55, green: 0.55, blue: 0.60),
                    Color(red: 0.40, green: 0.40, blue: 0.45)]
        }
    }

    // MARK: - Content

    private var cardContent: some View {
        VStack(spacing: 0) {
            headerSection
                .padding(.top, 28)

            Spacer(minLength: 8)

            drinkInfoSection

            Spacer(minLength: 8)

            metricsRow
                .padding(.horizontal, 20)

            Spacer(minLength: 8)

            footerSection
                .padding(.bottom, 20)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 2) {
            Text("筋肉ごめん")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Sorry, Gains")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    // MARK: - Drink Info

    private var drinkInfoSection: some View {
        HStack(spacing: 12) {
            Image(systemName: record.drinkType.symbolName)
                .font(.system(size: 36))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(drinkTypeLabel)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(volumeLabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.18))
        )
    }

    private var drinkTypeLabel: String {
        record.drinkType.localizedName
    }

    private var volumeLabel: String {
        let ml = Int(record.volumeML)
        let pct = String(format: "%.1f", record.alcoholPercent)
        return "\(ml)mL / \(pct)%"
    }

    // MARK: - Metrics

    private var metricsRow: some View {
        HStack(spacing: 0) {
            metricCell(
                title: result.didTrainToday ? "トレ成果" : "筋肉",
                subtitle: result.didTrainToday ? "Wasted" : "Down",
                value: String(format: "%.0f%%", result.wastedPercent)
            )

            metricDivider

            metricCell(
                title: "怒り度",
                subtitle: "Anger",
                value: angerStars
            )

            metricDivider

            metricCell(
                title: "影響スコア",
                subtitle: "Impact",
                value: String(format: "%.0f", result.impactScore)
            )
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.black.opacity(0.2))
        )
    }

    private var angerStars: String {
        String(repeating: "★", count: result.angerLevel)
            + String(repeating: "☆", count: max(0, 5 - result.angerLevel))
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.25))
            .frame(width: 1, height: 36)
    }

    private func metricCell(title: LocalizedStringKey, subtitle: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 6) {
            Text("#筋肉ごめん  #SorryGains")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))

            Text("※ このアプリは医学的アドバイスを提供するものではありません")
                .font(.system(size: 7, weight: .regular))
                .foregroundStyle(.white.opacity(0.45))
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Share Card - Level 1") {
    ShareableResultView(
        result: ApologyResult(
            pureAlcoholGram: 10,
            wastedPercent: 15,
            angerLevel: 1,
            impactScore: 20,
            captionKey: "result.caption.lv1",
            characterStage: 0,
            didTrainToday: true
        ),
        record: DrinkRecord(
            drinkType: .beer,
            volumeML: 350,
            alcoholPercent: 5.0
        )
    )
    .padding()
    .background(Color.gray.opacity(0.3))
}

#Preview("Share Card - Level 5") {
    ShareableResultView(
        result: ApologyResult(
            pureAlcoholGram: 60,
            wastedPercent: 85,
            angerLevel: 5,
            impactScore: 90,
            captionKey: "result.caption.lv5",
            characterStage: 3,
            didTrainToday: false
        ),
        record: DrinkRecord(
            drinkType: .sake,
            volumeML: 540,
            alcoholPercent: 15.0
        )
    )
    .padding()
    .background(Color.gray.opacity(0.3))
}
#endif
