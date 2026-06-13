import SwiftData
import SwiftUI

struct ResultView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(TrainingDataService.self) private var trainingDataService

    let record: DrinkRecord

    @State private var result: ApologyResult?
    @State private var animState = ResultAnimationState()
    @State private var shareImage: Image?

    private let calculator: ApologyCalculator = .live

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    characterSection
                    captionSection
                    metricsSection
                    apologySection
                    disclaimerText
                    actionsSection
                }
                .padding(Spacing.md)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: animState.metricHapticTick)
            .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.8), trigger: animState.angerRevealTick)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: animState.apologyHapticTick)
            .task { await runPresentation() }
        }
    }

    // MARK: - Character

    private var characterSection: some View {
        VStack(spacing: Spacing.sm) {
            MuscleCharacterView(
                stage: animState.forgiven ? 0 : (result?.characterStage ?? 0),
                animate: !reduceMotion
            )
            .frame(height: 140)
            .symbolEffect(.bounce, value: animState.apologyReaction)

            if let result, animState.captionVisible {
                let level = animState.currentAngerLevel
                Text(angerLevelText(level))
                    .font(.SG.title2)
                    .foregroundStyle(
                        animState.forgiven
                            ? Color.SG.apologyMild
                            : Color.SG.apologyColor(for: result.angerLevel)
                    )
                    .transition(.opacity)
                    .contentTransition(.numericText())
            }
        }
        .padding(.top, Spacing.xl)
    }

    // MARK: - Caption

    @ViewBuilder
    private var captionSection: some View {
        if animState.captionVisible, let result {
            Group {
                if animState.forgiven {
                    Text("result.forgiven")
                        .font(.SG.title)
                } else {
                    Text(LocalizedStringKey(result.captionKey))
                        .font(.SG.title)
                }
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.SG.textPrimary)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - Metrics

    @ViewBuilder
    private var metricsSection: some View {
        if animState.metricsVisible, let result {
            VStack(spacing: Spacing.sm) {
                // 指標1: 筋トレ成果 / 筋肉ダウン
                MetricCard(
                    title: result.didTrainToday
                        ? "result.metric.wasted_training"
                        : "result.metric.muscle_down",
                    value: String(format: "%.0f", animState.displayedWastedPercent),
                    unit: result.didTrainToday
                        ? "result.metric.percent_wasted"
                        : "result.metric.percent_down",
                    color: Color.SG.apologyColor(for: result.angerLevel)
                )

                HStack(spacing: Spacing.sm) {
                    // 指標2: 筋肉怒り度
                    MetricCard(
                        title: "result.metric.anger_level",
                        value: "\(animState.displayedAngerLevel)",
                        unit: "result.metric.of_five",
                        color: Color.SG.apologyColor(for: result.angerLevel)
                    )

                    // 指標3: 影響スコア
                    VStack(spacing: Spacing.xs) {
                        MetricCard(
                            title: "result.metric.impact_score",
                            value: String(format: "%.0f", animState.displayedImpactScore),
                            unit: "/ 100",
                            color: animState.forgiven
                                ? Color.SG.apologyMild
                                : Color.SG.apologyColor(for: result.angerLevel)
                        )

                        if animState.savedScore > 0 {
                            Text(String(
                                format: String(localized: "result.metric.saved_score"),
                                animState.savedScore
                            ))
                            .font(.SG.caption)
                            .foregroundStyle(Color.SG.apologyMild)
                            .transition(.opacity)
                        }
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - Apology Button

    @ViewBuilder
    private var apologySection: some View {
        if animState.actionsVisible, let result, !animState.forgiven {
            Button {
                animState.apologize(result: result, record: record, context: modelContext)
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "hands.clap.fill")
                    Text("result.action.apologize")
                    if animState.apologyCount > 0 {
                        Text("(\(animState.apologyCount))")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.SG.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.SG.accent.opacity(animState.apologyCooldown ? 0.08 : 0.2))
                .foregroundStyle(Color.SG.accent.opacity(animState.apologyCooldown ? 0.4 : 1.0))
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
            }
            .disabled(animState.apologyCooldown)
            .animation(.easeInOut(duration: 0.3), value: animState.apologyCooldown)
            .transition(.opacity)
        }

        if animState.forgiven {
            VStack(spacing: Spacing.xs) {
                Image(systemName: "heart.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.SG.apologyMild)
                    .symbolEffect(.bounce, value: animState.forgiven)
                Text("result.forgiven_detail")
                    .font(.SG.body)
                    .foregroundStyle(Color.SG.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .transition(.scale.combined(with: .opacity))
            .padding(.vertical, Spacing.sm)
        }
    }

    // MARK: - Disclaimer

    private var disclaimerText: some View {
        Text("result.disclaimer")
            .font(.SG.footnote)
            .foregroundStyle(Color.SG.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.md)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionsSection: some View {
        if animState.actionsVisible {
            VStack(spacing: Spacing.sm) {
                ShareLink(
                    item: shareImage ?? Image(systemName: "photo"),
                    preview: SharePreview(
                        String(localized: "share.title"),
                        image: shareImage ?? Image(systemName: "photo")
                    )
                ) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "square.and.arrow.up")
                        Text("result.action.share")
                    }
                    .font(.SG.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.SG.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
                }

                SGButton("result.action.close", style: .secondary) {
                    dismiss()
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - Helpers

    private func angerLevelText(_ level: Int) -> String {
        Bundle.main.localizedString(
            forKey: "result.anger_level.\(level)",
            value: "Lv\(level)",
            table: nil
        )
    }

    private func runPresentation() async {
        let profile = fetchProfile()
        _ = await trainingDataService.fetchTodayTraining()
        // todaySnapshot は TrainingSnapshot? の後方互換 computed property
        let snapshot = trainingDataService.todaySnapshot
        let calculated = calculator.calculate(record, profile, record.didTrainToday, snapshot)
        result = calculated
        shareImage = ShareImageRenderer.render(result: calculated, record: record)
        await animState.run(result: calculated, record: record, reduceMotion: reduceMotion)
    }

    private func fetchProfile() -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = (try? modelContext.fetch(descriptor)) ?? []
        return profiles.first ?? UserProfile()
    }
}
