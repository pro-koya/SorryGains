import SwiftUI

/// GitHub-style contribution heatmap showing drinking intensity over 4 weeks.
///
/// Each cell represents one day, colored by alcohol consumption intensity.
/// Training days show a small dumbbell indicator.
struct DrinkingHeatmapView: View {
    let dailyData: [DayData]

    private let columns = 7
    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3

    private var weekdayLabels: [String] {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        // Reorder to start from Monday
        let mondayIndex = 1 // Monday is index 1 in veryShortWeekdaySymbols (0=Sun)
        return Array(symbols[mondayIndex...]) + Array(symbols[..<mondayIndex])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Grid
            HStack(alignment: .top, spacing: cellSpacing) {
                // Weekday labels
                VStack(spacing: cellSpacing) {
                    ForEach(weekdayLabels.indices, id: \.self) { index in
                        if index % 2 == 0 {
                            Text(weekdayLabels[index])
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(Color.SG.textSecondary)
                                .frame(width: 16, height: cellSize)
                        } else {
                            Color.clear.frame(width: 16, height: cellSize)
                        }
                    }
                }

                // Data grid — columns are weeks, rows are days
                ForEach(Array(weekColumns.enumerated()), id: \.offset) { week in
                    VStack(spacing: cellSpacing) {
                        ForEach(Array(week.element.enumerated()), id: \.offset) { day in
                            heatmapCell(day.element)
                        }
                    }
                }
            }

            // Legend
            HStack(spacing: Spacing.xs) {
                Text("少ない")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.SG.textSecondary)

                ForEach(0...4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(intensityColor(for: level))
                        .frame(width: 10, height: 10)
                }

                Text("多い")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.SG.textSecondary)
            }
        }
    }

    // MARK: - Cell

    private func heatmapCell(_ day: DayData) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(intensityColor(for: day.intensityLevel))
                .frame(width: cellSize, height: cellSize)

            if day.didTrain {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Data Organization

    /// Organizes daily data into week columns (each column = 7 days).
    private var weekColumns: [[DayData]] {
        let sorted = dailyData.sorted { $0.date < $1.date }
        var weeks: [[DayData]] = []

        // Reorder: start each week from Monday
        let calendar = Calendar.current
        var currentWeek: [DayData] = []

        for day in sorted {
            let weekday = calendar.component(.weekday, from: day.date)
            // Convert Sunday=1..Saturday=7 to Monday=0..Sunday=6
            let mondayBased = (weekday + 5) % 7

            if mondayBased == 0 && !currentWeek.isEmpty {
                // Pad incomplete week
                while currentWeek.count < 7 {
                    currentWeek.append(DayData(
                        date: .distantPast,
                        drinkCount: 0,
                        totalAlcoholGram: 0,
                        didTrain: false,
                        recoveryCount: 0
                    ))
                }
                weeks.append(currentWeek)
                currentWeek = []
            }

            currentWeek.append(day)
        }

        if !currentWeek.isEmpty {
            while currentWeek.count < 7 {
                currentWeek.append(DayData(
                    date: .distantPast,
                    drinkCount: 0,
                    totalAlcoholGram: 0,
                    didTrain: false,
                    recoveryCount: 0
                ))
            }
            weeks.append(currentWeek)
        }

        return weeks
    }

    // MARK: - Colors

    private func intensityColor(for level: Int) -> Color {
        switch level {
        case 0: return Color.SG.surface
        case 1: return Color.SG.apologyMild.opacity(0.4)
        case 2: return Color.SG.apologyModerate.opacity(0.6)
        case 3: return Color.SG.apologySevere.opacity(0.8)
        default: return Color.SG.apologyMax
        }
    }
}
