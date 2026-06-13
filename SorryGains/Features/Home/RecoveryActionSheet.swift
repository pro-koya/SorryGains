import SwiftUI

/// Half-sheet displaying recovery actions the user can report to earn forgiveness.
struct RecoveryActionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let recoveryLog: DailyRecoveryLog
    let characterStage: Int
    let targetDateLabel: String
    let onActionCompleted: (RecoveryActionType) -> Void

    private var completedCount: Int {
        recoveryLog.completedActionRawValues.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.sm) {
                    progressHeader

                    ForEach(RecoveryActionType.allCases) { action in
                        actionRow(action)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .navigationTitle("\(targetDateLabel)のお詫び行動")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "heart.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.SG.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("お詫びの進捗")
                    .font(.SG.caption)
                    .foregroundStyle(Color.SG.textSecondary)
                Text("\(completedCount) / \(RecoveryActionType.allCases.count) 達成")
                    .font(.SG.headline)
                    .foregroundStyle(Color.SG.textPrimary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("許しポイント")
                    .font(.SG.caption)
                    .foregroundStyle(Color.SG.textSecondary)
                Text("\(recoveryLog.totalForgivenessPoints)pt")
                    .font(.SG.headline)
                    .foregroundStyle(Color.SG.accent)
            }
        }
        .padding(Spacing.cardPadding)
        .background(Color.SG.surface)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                .stroke(Color.SG.accent.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Action Row

    private func actionRow(_ action: RecoveryActionType) -> some View {
        let isCompleted = recoveryLog.hasCompleted(action)

        return Button {
            onActionCompleted(action)
            dismiss()
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: action.symbolName)
                    .font(.title3)
                    .foregroundStyle(isCompleted ? Color.SG.apologyMild : Color.SG.accent)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.localizedName)
                        .font(.SG.headline)
                        .foregroundStyle(isCompleted
                            ? Color.SG.textSecondary
                            : Color.SG.textPrimary)

                    Text("+\(action.forgivenessPoints)pt / -\(String(format: "%.0f", action.scoreReduction))スコア")
                        .font(.SG.caption)
                        .foregroundStyle(Color.SG.textSecondary)
                }

                Spacer()

                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isCompleted ? Color.SG.apologyMild : Color.SG.textSecondary.opacity(0.4))
            }
            .padding(Spacing.cardPadding)
            .background(Color.SG.surface)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                    .stroke(
                        isCompleted
                            ? Color.SG.apologyMild.opacity(0.3)
                            : Color.SG.textSecondary.opacity(0.15),
                        lineWidth: 1
                    )
            )
            .opacity(isCompleted ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isCompleted)
    }
}
