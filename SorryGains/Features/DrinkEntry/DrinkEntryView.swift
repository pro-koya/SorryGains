import SwiftData
import SwiftUI

struct DrinkEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(TrainingDataService.self) private var trainingDataService
    @Query(sort: \DailyTrainingStatus.date, order: .reverse)
    private var dailyTrainingStatuses: [DailyTrainingStatus]

    private let recordToEdit: DrinkRecord?

    @State private var selectedType: DrinkType
    @State private var volumeML: Double
    @State private var alcoholPercent: Double

    private let volumePresets: [Double] = [180, 250, 350, 500, 700]

    init(record: DrinkRecord? = nil, template: DrinkRecord? = nil) {
        self.recordToEdit = record
        _selectedType = State(initialValue: record?.drinkType ?? template?.drinkType ?? .beer)
        _volumeML = State(initialValue: record?.volumeML ?? template?.volumeML ?? 350)
        _alcoholPercent = State(initialValue: record?.alcoholPercent ?? template?.alcoholPercent ?? 5.0)
    }

    private var isEditing: Bool {
        recordToEdit != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    drinkTypeSection
                    volumeSection
                    alcoholSection
                    if !isEditing {
                        dailyTrainingInfoSection
                    }
                    submitButton
                }
                .padding(Spacing.md)
            }
            .navigationTitle(String(localized: isEditing ? "drink_entry.edit_title" : "drink_entry.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Drink Type Selection

    private var drinkTypeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("drink_entry.type")
                .font(.SG.headline)
                .foregroundStyle(Color.SG.textPrimary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 3),
                spacing: Spacing.sm
            ) {
                ForEach(DrinkType.allCases) { type in
                    drinkTypeButton(type)
                }
            }
        }
    }

    private func drinkTypeButton(_ type: DrinkType) -> some View {
        Button {
            selectedType = type
            volumeML = type.defaultVolumeML
            alcoholPercent = type.defaultAlcoholPercent
        } label: {
            VStack(spacing: Spacing.xs) {
                Image(systemName: type.symbolName)
                    .font(.title2)
                Text(type.localizedName)
                    .font(.SG.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                selectedType == type
                    ? Color.SG.accent.opacity(0.2)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall)
                    .stroke(
                        selectedType == type ? Color.SG.accent : Color.SG.textSecondary.opacity(0.3),
                        lineWidth: selectedType == type ? 2 : 1
                    )
            )
        }
        .foregroundStyle(
            selectedType == type ? Color.SG.accent : Color.SG.textPrimary
        )
        .sensoryFeedback(.selection, trigger: selectedType)
    }

    // MARK: - Volume

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("drink_entry.volume")
                .font(.SG.headline)
                .foregroundStyle(Color.SG.textPrimary)

            HStack(spacing: Spacing.xs) {
                ForEach(volumePresets, id: \.self) { preset in
                    Button {
                        volumeML = preset
                    } label: {
                        Text("\(Int(preset))ml")
                            .font(.SG.caption)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(
                                volumeML == preset
                                    ? Color.SG.accent
                                    : Color.SG.accent.opacity(0.1)
                            )
                            .foregroundStyle(
                                volumeML == preset ? .white : Color.SG.accent
                            )
                            .clipShape(Capsule())
                    }
                    .sensoryFeedback(.selection, trigger: volumeML)
                }
            }

            Slider(value: $volumeML, in: 50...1000, step: 10) {
                Text("drink_entry.volume")
            } minimumValueLabel: {
                Text("50")
                    .font(.SG.caption)
            } maximumValueLabel: {
                Text("1000")
                    .font(.SG.caption)
            }
            .tint(Color.SG.accent)

            Text("\(Int(volumeML))ml")
                .font(.SG.numericBody)
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(Color.SG.textPrimary)
        }
    }

    // MARK: - Alcohol Percent

    private var alcoholSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("drink_entry.alcohol_percent")
                .font(.SG.headline)
                .foregroundStyle(Color.SG.textPrimary)

            Slider(value: $alcoholPercent, in: 1...50, step: 0.5) {
                Text("drink_entry.alcohol_percent")
            } minimumValueLabel: {
                Text("1%")
                    .font(.SG.caption)
            } maximumValueLabel: {
                Text("50%")
                    .font(.SG.caption)
            }
            .tint(Color.SG.accent)

            Text(String(format: "%.1f%%", alcoholPercent))
                .font(.SG.numericBody)
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(Color.SG.textPrimary)
        }
    }

    // MARK: - Daily Training Status

    private var dailyTrainingInfoSection: some View {
        SGCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: todaysTrainingStatus && trainingDataService.linkStatus.isLinked
                          ? "link.circle.fill" : "dumbbell.fill")
                        .foregroundStyle(Color.SG.accent)
                    Text("今日の筋トレ状態")
                        .font(.SG.headline)
                        .foregroundStyle(Color.SG.textPrimary)
                    Spacer()
                    Text(todaysTrainingStatus ? "した" : "してない")
                        .font(.SG.caption)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(todaysTrainingStatus ? Color.SG.accent.opacity(0.18) : Color.SG.textSecondary.opacity(0.12))
                        .foregroundStyle(todaysTrainingStatus ? Color.SG.accent : Color.SG.textSecondary)
                        .clipShape(Capsule())
                }

                // Liftly 連携時: 部位情報を表示
                if trainingDataService.linkStatus.isLinked,
                   let snapshot = trainingDataService.todaySnapshot,
                   snapshot.hasTraining,
                   !snapshot.bodyPartsDisplayText.isEmpty {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.caption)
                            .foregroundStyle(Color.SG.accent)
                        Text(snapshot.bodyPartsDisplayText)
                            .font(.SG.caption)
                            .foregroundStyle(Color.SG.accent)
                    }
                }

                if trainingDataService.linkStatus.isLinked {
                    Text("Liftlyのトレーニングデータが自動で反映されます。")
                        .font(.SG.caption)
                        .foregroundStyle(Color.SG.textSecondary)
                } else {
                    Text("筋トレしたかどうかはホームで1日1回だけ設定します。この記録には現在の今日設定が自動で反映されます。")
                        .font(.SG.caption)
                        .foregroundStyle(Color.SG.textSecondary)
                }
            }
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        SGButton(
            isEditing ? "drink_entry.update_submit" : "drink_entry.submit",
            icon: isEditing ? "pencil.circle.fill" : "checkmark.circle.fill"
        ) {
            if let recordToEdit {
                recordToEdit.drinkType = selectedType
                recordToEdit.volumeML = volumeML
                recordToEdit.alcoholPercent = alcoholPercent
                // Result-related cached values depend on the drink details.
                recordToEdit.apologyCount = 0
                recordToEdit.savedHours = 0
                recordToEdit.currentAngerLevel = nil
            } else {
                let record = DrinkRecord(
                    drinkType: selectedType,
                    volumeML: volumeML,
                    alcoholPercent: alcoholPercent,
                    didTrainToday: todaysTrainingStatus
                )
                modelContext.insert(record)
            }

            try? modelContext.save()
            dismiss()
        }
        .padding(.top, Spacing.md)
    }

    private var todaysTrainingStatus: Bool {
        // Liftly 連携済み + スナップショット取得済み → Liftly のデータで判定
        if trainingDataService.linkStatus.isLinked,
           let snapshot = trainingDataService.todaySnapshot {
            return snapshot.hasTraining
        }
        // 未連携 or スナップショット未取得 → ローカル手入力で判定
        let calendar = Calendar.current
        if let status = dailyTrainingStatuses.first(where: {
            calendar.isDate($0.date, inSameDayAs: .now)
        }) {
            return status.didTrain
        }
        return false
    }
}
