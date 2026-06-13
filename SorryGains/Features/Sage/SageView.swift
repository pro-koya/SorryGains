import SwiftData
import SwiftUI

struct SageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TrainingDataService.self) private var trainingDataService
    @Query(sort: \DrinkRecord.timestamp, order: .reverse)
    private var allRecords: [DrinkRecord]
    @Query(sort: \DailyTrainingStatus.date, order: .reverse)
    private var trainingStatuses: [DailyTrainingStatus]

    @State private var advice: SageAdvice?
    @State private var isTyping = false
    @State private var isGenerating = false
    @State private var displayedText = ""
    @State private var showMetrics = false
    @State private var showActions = false
    @State private var hasAppeared = false
    @State private var bubbleScale: CGFloat = 0
    @State private var bubbleRotation: Double = 0
    @State private var showWeeklyReport = false
    @State private var showOutOfCreditsHint = false
    @StateObject private var rewardedAdController = RewardedAdController()
    @StateObject private var creditsStore = SageAdviceCreditsStore()

    private let provider: any SageAdviceProvider = SageAdviceProviderFactory.make()

    private var profile: UserProfile? {
        try? modelContext.fetch(FetchDescriptor<UserProfile>()).first
    }

    private var sageContext: SageContext {
        SageContextBuilder.build(
            records: Array(allRecords),
            trainingStatuses: Array(trainingStatuses),
            profile: profile ?? UserProfile(),
            trainingSnapshot: trainingDataService.todaySnapshot
        )
    }

    private var tintColor: Color {
        guard let advice else { return Color.SG.accent }
        switch advice.tone {
        case .stern: return Color.SG.apologySevere
        case .warm: return Color.SG.apologyModerate
        case .firedUp: return Color.SG.apologyMild
        case .calm: return Color.SG.accent
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.sm) {
                    characterSection
                    adviceBubble
                    creditStatusView
                    askButton
                    watchAdButton
                    weeklySummaryCard
                    weeklyReportButton
                    if showActions {
                        AdBannerSlot(placement: .sageInline)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .navigationTitle(String(localized: "sage.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            guard !hasAppeared else { return }
            hasAppeared = true
            creditsStore.refreshIfDayChanged()
            Task { await rewardedAdController.loadAd() }
            // 初回も自動生成しない。動きを出すためメトリクスとアクションだけ表示。
            withAnimation(.easeOut(duration: 0.4)) { showMetrics = true }
            withAnimation(.easeOut(duration: 0.3).delay(0.1)) { showActions = true }
        }
    }

    // MARK: - Character Section

    private var characterSection: some View {
        GeometryReader { geometry in
            let characterWidth = geometry.size.width * 0.75
            let characterHeight = characterWidth * 1.2

            ZStack {
                Circle()
                    .fill(tintColor.opacity(0.14))
                    .frame(width: characterWidth * 0.8, height: characterWidth * 0.8)
                    .blur(radius: 20)
                    .offset(y: -characterWidth * 0.06)

                Capsule()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: characterWidth * 0.5, height: 24)
                    .blur(radius: 20)
                    .offset(y: characterHeight * 0.38)

                SageCharacterView(tintColor: tintColor)
                    .frame(width: characterWidth, height: characterHeight)
                    .scaleEffect(hasAppeared ? 1 : 0.9)
                    .opacity(hasAppeared ? 1 : 0)
                    .animation(
                        .spring(duration: 0.7, bounce: 0.2),
                        value: hasAppeared
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: 320)
    }

    // MARK: - Advice Bubble (漫画風吹き出し)

    private var adviceBubble: some View {
        let bubbleShape = SpeechBubbleShape(
            tailPosition: 0.35,
            tailWidth: 28,
            tailHeight: 18,
            cornerRadius: Spacing.cornerRadius
        )

        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let advice {
                    Text(displayedText)
                        .font(.SG.body)
                        .foregroundStyle(Color.SG.textPrimary)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("sageAdviceText")

                    if isTyping {
                        typingIndicator
                    }

                    if let followUp = advice.followUp, !isTyping {
                        Text(followUp)
                            .font(.SG.caption)
                            .foregroundStyle(tintColor)
                            .padding(.top, Spacing.xxs)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                } else if isGenerating {
                    HStack(spacing: Spacing.xs) {
                        ProgressView()
                        Text("仙人が考え中…")
                            .font(.SG.caption)
                            .foregroundStyle(Color.SG.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    Text("下のボタンで仙人に話を聞いてみろ。")
                        .font(.SG.body)
                        .foregroundStyle(Color.SG.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 18 + Spacing.cardPadding) // tailHeight + padding
            .padding(.horizontal, Spacing.cardPadding)
            .padding(.bottom, Spacing.cardPadding)
            .background(
                bubbleShape
                    .fill(Color.SG.surface)
            )
            .overlay(
                bubbleShape
                    .stroke(tintColor.opacity(0.35), lineWidth: 2)
            )
            .shadow(color: tintColor.opacity(0.12), radius: 16, y: 8)
        }
        .scaleEffect(bubbleScale, anchor: .top)
        .rotationEffect(.degrees(bubbleRotation), anchor: .top)
        .padding(.top, -Spacing.xxl) // キャラクターと密着して重なる
        .animation(.easeInOut(duration: 0.3), value: isTyping)
    }

    /// タイピング中の「...」アニメーション
    private var typingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(tintColor.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .offset(y: typingDotOffset(for: index))
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: isTyping
                    )
            }
        }
        .padding(.top, Spacing.xxs)
    }

    private func typingDotOffset(for index: Int) -> CGFloat {
        isTyping ? -3 : 0
    }

    // MARK: - Weekly Summary

    private var weeklySummaryCard: some View {
        SGCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("sage.weekly_summary")
                    .font(.SG.headline)
                    .foregroundStyle(Color.SG.textPrimary)

                HStack(spacing: Spacing.lg) {
                    summaryItem(
                        icon: "mug.fill",
                        value: "\(sageContext.weekDrinkCount)",
                        unit: "sage.days",
                        label: "飲酒日数",
                        color: Color.SG.apologySevere
                    )

                    summaryItem(
                        icon: "figure.strengthtraining.traditional",
                        value: "\(sageContext.weekTrainingDays)",
                        unit: "sage.days",
                        label: "筋トレ日数",
                        color: Color.SG.apologyMild
                    )

                    if sageContext.consecutiveDrinkingDays > 0 {
                        summaryItem(
                            icon: "flame",
                            value: "\(sageContext.consecutiveDrinkingDays)",
                            unit: "sage.consecutive",
                            label: "連続飲酒",
                            color: Color.SG.apologyMax
                        )
                    }
                }
            }
        }
        .opacity(showMetrics ? 1 : 0)
        .offset(y: showMetrics ? 0 : 12)
        .animation(.easeOut(duration: 0.4).delay(0.2), value: showMetrics)
    }

    private func summaryItem(
        icon: String,
        value: String,
        unit: LocalizedStringKey,
        label: LocalizedStringKey,
        color: Color
    ) -> some View {
        VStack(spacing: Spacing.xxs) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.SG.textSecondary)

            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.SG.numericBody)
                .foregroundStyle(Color.SG.textPrimary)

            Text(unit)
                .font(.SG.footnote)
                .foregroundStyle(Color.SG.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Weekly Report Button

    private var weeklyReportButton: some View {
        Button { showWeeklyReport = true } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "chart.bar.fill")
                Text("週間レポートを見る")
            }
            .font(.SG.headline)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.SG.surface)
            .foregroundStyle(Color.SG.accent)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                    .stroke(Color.SG.accent.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .opacity(showMetrics ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(0.3), value: showMetrics)
        .sheet(isPresented: $showWeeklyReport) {
            WeeklyReportView()
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Credit Status

    private var creditStatusView: some View {
        let total = creditsStore.totalAvailable
        return VStack(spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: total > 0 ? "sparkles" : "hourglass")
                    .foregroundStyle(total > 0 ? Color.SG.accent : Color.SG.textSecondary)
                Text("仙人からあと \(total)回 助言をもらえる")
                    .font(.SG.headline)
                    .foregroundStyle(Color.SG.textPrimary)
            }
            Text("無料分: \(creditsStore.freeRemaining)/\(SageAdviceCreditsStore.dailyFreeCredits)・ボーナス: \(creditsStore.bonusCredits)")
                .font(.SG.caption)
                .foregroundStyle(Color.SG.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .opacity(showActions ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: showActions)
    }

    // MARK: - Ask Button (consume credit)

    private var askButton: some View {
        let canAsk = creditsStore.totalAvailable > 0 && !isGenerating && !isTyping
        return Button {
            handleAskTap()
        } label: {
            HStack(spacing: Spacing.xs) {
                if isGenerating {
                    ProgressView()
                } else {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                }
                Text(isGenerating ? "仙人が考え中…" : "今すぐ聞く")
            }
            .font(.SG.headline)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, Spacing.lg)
            .background(canAsk ? Color.SG.accent : Color.SG.accent.opacity(0.2))
            .foregroundStyle(canAsk ? Color.white : Color.SG.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
        }
        .buttonStyle(.plain)
        .disabled(!canAsk)
        .accessibilityAddTraits(.isButton)
        .opacity(showActions ? 1 : 0)
        .animation(.easeOut(duration: 0.3).delay(0.05), value: showActions)
    }

    // MARK: - Watch Ad Button (add credit only)

    private var watchAdButton: some View {
        VStack(spacing: Spacing.xs) {
            Button {
                rewardedAdController.showAd { [creditsStore] in
                    Task { @MainActor in
                        creditsStore.addBonusCredit()
                    }
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    if rewardedAdController.isLoading || rewardedAdController.isPresenting {
                        ProgressView()
                    } else {
                        Image(systemName: "play.rectangle.fill")
                    }
                    Text(rewardedAdButtonTitle)
                }
                .font(.SG.body)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, Spacing.lg)
                .background(Color.SG.accent.opacity(rewardedAdController.isReady ? 0.15 : 0.08))
                .foregroundStyle(rewardedAdController.isReady ? Color.SG.accent : Color.SG.textSecondary)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
            }
            .disabled(!rewardedAdController.isReady || rewardedAdController.isPresenting)
            .accessibilityAddTraits(.isButton)

            if rewardedAdController.lastErrorMessage != nil {
                Button {
                    Task { await rewardedAdController.loadAd() }
                } label: {
                    Text("広告を再読み込み")
                        .font(.SG.caption)
                        .foregroundStyle(Color.SG.textSecondary)
                }
            }
        }
        .opacity(showActions ? 1 : 0)
        .animation(.easeOut(duration: 0.3).delay(0.1), value: showActions)
    }

    private var rewardedAdButtonTitle: LocalizedStringKey {
        if rewardedAdController.isPresenting {
            return "広告を表示中"
        }
        if rewardedAdController.isLoading {
            return "広告を準備中"
        }
        if rewardedAdController.isReady {
            return "広告を見てクレジット +1"
        }
        return "広告を準備中"
    }

    private func handleAskTap() {
        guard creditsStore.consumeOne() else { return }
        Task { await loadAdvice() }
    }

    // MARK: - Advice Loading

    private func loadAdvice() async {
        isGenerating = true
        isTyping = true
        displayedText = ""

        // 吹き出しを縮小してリセット
        withAnimation(.easeIn(duration: 0.15)) {
            bubbleScale = 0
            bubbleRotation = 0
        }

        // Liftly 連携: 助言生成前にトレーニングデータを最新化
        _ = await trainingDataService.fetchTodayTraining()
        let context = sageContext
        let newAdvice = await provider.provideAdvice(for: context)
        advice = newAdvice
        isGenerating = false

        // 吹き出しポップイン — 漫画的な「ボンッ」演出
        try? await Task.sleep(for: .milliseconds(100))
        withAnimation(.spring(duration: 0.5, bounce: 0.4)) {
            bubbleScale = 1.0
        }
        withAnimation(.spring(duration: 0.3, bounce: 0.5).delay(0.15)) {
            bubbleRotation = 1.5
        }
        try? await Task.sleep(for: .milliseconds(200))
        withAnimation(.spring(duration: 0.25, bounce: 0.3)) {
            bubbleRotation = 0
        }

        await typewriterReveal(newAdvice.message)

        isTyping = false
        AchievementTracker.incrementSageViewCount()
    }

    private func typewriterReveal(_ text: String) async {
        let characters = Array(text)
        for character in characters {
            displayedText.append(character)
            let delay: UInt64 = character == "。" || character == "！"
                ? 80_000_000
                : 30_000_000
            try? await Task.sleep(nanoseconds: delay)
        }
    }
}
