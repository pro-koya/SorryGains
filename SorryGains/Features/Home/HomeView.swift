import SwiftData
import SwiftUI

struct HomeView: View {
    private enum ScrollTarget {
        static let todaySummary = "today-summary"
        static let todayHistory = "today-history"
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(TrainingDataService.self) private var trainingDataService
    @Query(
        filter: #Predicate<DrinkRecord> { _ in true },
        sort: \DrinkRecord.timestamp,
        order: .reverse
    ) private var recentRecords: [DrinkRecord]
    @Query(sort: \DailyTrainingStatus.date, order: .reverse)
    private var dailyTrainingStatuses: [DailyTrainingStatus]

    @Query(sort: \DailyRecoveryLog.date, order: .reverse)
    private var dailyRecoveryLogs: [DailyRecoveryLog]

    @Environment(\.scenePhase) private var scenePhase

    @State private var showDrinkEntry = false
    @State private var entryTemplate: DrinkRecord?
    @State private var hasAppeared = false
    @State private var showRecordedToast = false
    @State private var showRecoverySheet = false
    @State private var recoveryReactionToast: String?
    @State private var previousRecordCount = 0
    @State private var showLiftlyLinkPrompt = false
    @State private var currentDrinkReaction: DrinkReaction?
    @State private var showSessionReport = false
    @State private var showAchievements = false
    @StateObject private var achievementTracker = AchievementTracker()

    @Query(filter: #Predicate<DrinkingSession> { $0.endedAt == nil },
           sort: \DrinkingSession.startedAt, order: .reverse)
    private var activeSessions: [DrinkingSession]

    @Query(sort: \DrinkingSession.startedAt, order: .reverse)
    private var allSessions: [DrinkingSession]

    private var activeSession: DrinkingSession? {
        activeSessions.first
    }

    private var lastEndedSession: DrinkingSession? {
        allSessions.first { $0.endedAt != nil }
    }
    /// 日付境界チェック用。ScenePhase 変化時に更新し、SwiftUI の再評価を強制する。
    @State private var dayBoundaryTick = 0
    @AppStorage("liftlyLinkPromptDismissed") private var liftlyLinkPromptDismissed = false

    private let dailyImpactCalculator: DailyImpactCalculator = .live

    private var todaysRecords: [DrinkRecord] {
        // dayBoundaryTick を参照して ScenePhase 変化時に再評価を強制
        _ = dayBoundaryTick
        let start = DayBoundary.startOfToday()
        return recentRecords.filter { $0.timestamp >= start }
    }

    private var todayTrainingRecord: DailyTrainingStatus? {
        _ = dayBoundaryTick
        return dailyTrainingStatuses.first(where: {
            DayBoundary.isToday($0.date)
        })
    }

    private var todaysTrainingStatus: Bool {
        // Liftly 連携済み + スナップショット取得済み → Liftly のデータで判定
        if trainingDataService.linkStatus.isLinked,
           let snapshot = trainingDataService.todaySnapshot {
            return snapshot.hasTraining
        }
        // 未連携 or スナップショット未取得 → ローカル手入力で判定
        return todayTrainingRecord?.didTrain ?? todaysRecords.contains { $0.didTrainToday }
    }

    private var todaysDrinkSummaries: [DrinkTypeSummary] {
        DrinkAnalytics.makeDrinkTypeSummaries(from: todaysRecords)
    }

    // MARK: - Yesterday (Recovery Target)

    private var yesterdaysRecords: [DrinkRecord] {
        _ = dayBoundaryTick
        let yesterdayStart = DayBoundary.startOfYesterday()
        let todayStart = DayBoundary.startOfToday()
        return recentRecords.filter { $0.timestamp >= yesterdayStart && $0.timestamp < todayStart }
    }

    private var yesterdayRecoveryLog: DailyRecoveryLog? {
        _ = dayBoundaryTick
        return dailyRecoveryLogs.first(where: {
            DayBoundary.isYesterday($0.date)
        })
    }

    private var yesterdayImpact: DailyImpactResult {
        dailyImpactCalculator.calculate(
            yesterdaysRecords,
            fetchProfile(),
            yesterdaysRecords.contains { $0.didTrainToday },
            nil
        )
    }

    private var recoveryDeadline: Date {
        DayBoundary.endOfToday()
    }

    // MARK: - Today

    private var dailyImpact: DailyImpactResult {
        dailyImpactCalculator.calculate(
            todaysRecords,
            fetchProfile(),
            todaysTrainingStatus,
            trainingDataService.todaySnapshot
        )
    }

    // MARK: - Weekly / Total Aggregation

    private var weeklyRecords: [DrinkRecord] {
        _ = dayBoundaryTick
        let weekStart = DayBoundary.startOfThisWeek()
        return recentRecords.filter { $0.timestamp >= weekStart }
    }

    private var weeklyImpactScore: Double {
        let profile = fetchProfile()
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: weeklyRecords) { record in
            calendar.startOfDay(for: record.timestamp)
        }
        return grouped.reduce(0.0) { total, entry in
            let (dayStart, dayRecords) = entry
            let result = dailyImpactCalculator.calculate(dayRecords, profile, false, nil)
            let recoveryLog = dailyRecoveryLogs.first { log in
                calendar.isDate(log.date, inSameDayAs: dayStart)
            }
            let reduction = recoveryLog?.totalScoreReduction ?? 0
            return total + max(0, result.impactScore - reduction)
        }
    }

    private var totalImpactScore: Double {
        let profile = fetchProfile()
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: recentRecords) { record in
            calendar.startOfDay(for: record.timestamp)
        }
        return grouped.reduce(0.0) { total, entry in
            let (dayStart, dayRecords) = entry
            let result = dailyImpactCalculator.calculate(dayRecords, profile, false, nil)
            let recoveryLog = dailyRecoveryLogs.first { log in
                calendar.isDate(log.date, inSameDayAs: dayStart)
            }
            let reduction = recoveryLog?.totalScoreReduction ?? 0
            return total + max(0, result.impactScore - reduction)
        }
    }

    private var characterStage: Int {
        let yesterdayAnger: Int = {
            guard !yesterdaysRecords.isEmpty else { return 0 }
            let reduction = yesterdayRecoveryLog?.angerReduction ?? 0
            return max(0, yesterdayImpact.angerLevel - reduction)
        }()

        let todayAnger: Int = {
            guard !todaysRecords.isEmpty else { return 0 }
            return dailyImpact.angerLevel
        }()

        let maxAnger = max(yesterdayAnger, todayAnger)
        guard maxAnger > 0 else { return 0 }
        return min(4, maxAnger - 1)
    }

    private var heroTone: Color {
        Color.SG.apologyColor(for: min(characterStage + 1, 5))
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Spacing.sm) {
                        characterSection(proxy: proxy)

                        if let session = activeSession {
                            DrinkingSessionBanner(
                                session: session,
                                drinkCount: sessionDrinkCount(session),
                                onStop: { endSession(session) }
                            )
                        }

                        quickAccessBar(proxy: proxy)

                        if !todaysRecords.isEmpty || !yesterdaysRecords.isEmpty || !recentRecords.isEmpty {
                            DailyImpactSection(
                                todayImpact: dailyImpact,
                                yesterdayImpact: yesterdayImpact,
                                yesterdayRecoveryLog: yesterdayRecoveryLog,
                                recoveryDeadline: recoveryDeadline,
                                weeklyImpactScore: weeklyImpactScore,
                                weeklyDrinkCount: weeklyRecords.count,
                                totalImpactScore: totalImpactScore,
                                totalDrinkCount: recentRecords.count,
                                onShowRecoverySheet: { showRecoverySheet = true }
                            )
                        }

                        if !todaysDrinkSummaries.isEmpty {
                            todayDrinkSummarySection
                        }

                        todayHistorySection
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.xxl)
                }
            }
            .safeAreaInset(edge: .bottom) {
                drinkButton
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.md)
                    .background(Color.SG.background.opacity(0.95))
            }
            .navigationTitle(String(localized: "app.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showAchievements = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .font(.caption)
                            Text("\(achievementTracker.unlockedAchievements.count)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                        .foregroundStyle(Color.SG.accent)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    todayCountBadge
                }
            }
        }
        .sheet(isPresented: $showDrinkEntry, onDismiss: {
            entryTemplate = nil
            let newCount = todaysRecords.count
            if newCount > previousRecordCount {
                // Show character reaction instead of plain toast
                let reaction = DrinkReactionProvider.reaction(forDrinkNumber: newCount)
                currentDrinkReaction = reaction
                // Check achievements after recording
                achievementTracker.checkAll(context: modelContext)
            }
        }) {
            DrinkEntryView(template: entryTemplate)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showRecoverySheet) {
            RecoveryActionSheet(
                recoveryLog: ensureRecoveryLog(for: DayBoundary.startOfYesterday()),
                characterStage: characterStage,
                targetDateLabel: String(localized: "昨日の飲酒"),
                onActionCompleted: completeRecoveryAction
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showSessionReport) {
            let session = lastEndedSession ?? DrinkingSession()
            let records = sessionRecords(lastEndedSession)
            SessionReportView(
                session: session,
                records: records,
                impact: dailyImpact,
                characterStage: characterStage,
                onShare: {
                    if let uiImage = ShareImageRenderer.renderDamageReportUIImage(
                        date: .now,
                        records: records,
                        impact: dailyImpact,
                        characterStage: characterStage,
                        sessionDuration: session.durationText
                    ) {
                        let controller = UIActivityViewController(
                            activityItems: [uiImage],
                            applicationActivities: nil
                        )
                        if let windowScene = UIApplication.shared.connectedScenes
                            .compactMap({ $0 as? UIWindowScene }).first,
                           let root = windowScene.windows.first?.rootViewController {
                            root.present(controller, animated: true)
                        }
                    }
                }
            )
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showAchievements) {
            AchievementListView(tracker: achievementTracker)
                .preferredColorScheme(.dark)
        }
        .overlay(alignment: .top) {
            if showRecordedToast {
                recordedToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if let reactionText = recoveryReactionToast {
                recoveryReactionToastView(text: reactionText)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay {
            if let reaction = currentDrinkReaction {
                DrinkReactionOverlay(
                    reaction: reaction,
                    characterStage: characterStage,
                    drinkNumber: todaysRecords.count,
                    onDismiss: { currentDrinkReaction = nil }
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if let achievement = achievementTracker.newlyUnlocked {
                AchievementUnlockOverlay(
                    achievement: achievement,
                    onDismiss: { achievementTracker.newlyUnlocked = nil }
                )
                .transition(.opacity)
            }
        }
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.7), trigger: currentDrinkReaction?.dialogue ?? "")
        .sensoryFeedback(.success, trigger: recoveryReactionToast ?? "")
        .task {
            // Liftly 連携: 当日のトレーニングデータを取得
            _ = await trainingDataService.fetchTodayTraining()
        }
        .onChange(of: authService.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                // セッション復元後に linkStatus を同期してトレーニングデータを取得
                trainingDataService.updateLinkStatus(isSignedIn: true)
                Task {
                    _ = await trainingDataService.fetchTodayTraining(forceRefresh: true)
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // フォアグラウンド復帰時に日付境界チェック → 全computed propertyを再評価
                dayBoundaryTick += 1
            }
            if newPhase == .background {
                // バックグラウンド移行時に通知をリスケジュール
                CharacterNotificationManager.shared.reschedule(context: modelContext)
            }
        }
        .sheet(isPresented: $showLiftlyLinkPrompt) {
            LiftlyLinkPromptSheet(
                isLoading: authService.isLoading,
                activeProvider: authService.activeSignInProvider,
                error: authService.error,
                onAppleSignIn: {
                    liftlyLinkPromptDismissed = true
                    await authService.signInWithApple()
                },
                onGoogleSignIn: {
                    liftlyLinkPromptDismissed = true
                    await authService.signInWithGoogle()
                },
                onContinueManually: {
                    liftlyLinkPromptDismissed = true
                }
            )
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
    }

    private func characterSection(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let characterWidth = geometry.size.width * 0.9
                let characterHeight = characterWidth * 1.14

                ZStack {
                    Circle()
                        .fill(heroTone.opacity(0.18))
                        .frame(width: characterWidth * 0.82, height: characterWidth * 0.82)
                        .blur(radius: 24)
                        .offset(y: -characterWidth * 0.08)

                    Capsule()
                        .fill(Color.black.opacity(0.14))
                        .frame(width: characterWidth * 0.62, height: 28)
                        .blur(radius: 24)
                        .offset(y: characterHeight * 0.34)

                    MuscleCharacterView(
                        stage: characterStage,
                        animate: true,
                        showCaption: false
                    )
                    .frame(width: characterWidth, height: characterHeight)
                    .scaleEffect(hasAppeared ? 1 : 0.92)
                    .opacity(hasAppeared ? 1 : 0)
                    .animation(.spring(duration: 0.7, bounce: 0.24), value: hasAppeared)

                    CharacterSpeechView(stage: characterStage)
                        .offset(y: characterHeight * 0.38)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(height: 370)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
        }
    }

    private func quickAccessBar(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: Spacing.xs) {
            // 今日の筋トレ状態
            if trainingDataService.linkStatus.isLinked,
               let snapshot = trainingDataService.todaySnapshot {
                // Liftly 連携時: スナップショットに基づく表示 + 同期ボタン
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "link.circle.fill")
                        .font(.caption)
                        .foregroundStyle(snapshot.hasTraining ? Color.SG.accent : Color.SG.textSecondary)
                    Text(snapshot.hasTraining
                         ? (snapshot.bodyPartsDisplayText.isEmpty
                            ? "Liftly: トレーニング済み"
                            : "Liftly: \(snapshot.bodyPartsDisplayText)")
                         : "Liftly: トレーニングなし")
                        .font(.SG.caption)
                        .foregroundStyle(snapshot.hasTraining ? Color.SG.accent : Color.SG.textSecondary)
                        .lineLimit(1)

                    // 同期ボタン
                    Button {
                        Task {
                            _ = await trainingDataService.fetchTodayTraining(forceRefresh: true)
                        }
                    } label: {
                        Image(systemName: trainingDataService.isLoading
                              ? "arrow.triangle.2.circlepath"
                              : "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(Color.SG.accent)
                            .rotationEffect(.degrees(trainingDataService.isLoading ? 360 : 0))
                            .animation(
                                trainingDataService.isLoading
                                    ? .linear(duration: 1).repeatForever(autoreverses: false)
                                    : .default,
                                value: trainingDataService.isLoading
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(trainingDataService.isLoading)
                }
            } else if authService.isSignedIn {
                // 連携済みだがスナップショット未取得 → 同期ボタン
                Button {
                    Task {
                        trainingDataService.updateLinkStatus(isSignedIn: true)
                        _ = await trainingDataService.fetchTodayTraining(forceRefresh: true)
                    }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                        Text("Liftlyと同期")
                            .font(.SG.caption)
                    }
                    .foregroundStyle(Color.SG.accent)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.SG.accent.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                // 手入力モード（従来通り）
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "dumbbell.fill")
                        .font(.caption)
                        .foregroundStyle(todaysTrainingStatus ? Color.SG.accent : Color.SG.textSecondary)

                    Text("今日の筋トレ")
                        .font(.SG.caption)
                        .foregroundStyle(Color.SG.textSecondary)

                    trainingStatusChip(title: "した", isSelected: todaysTrainingStatus) {
                        updateTrainingStatus(true)
                        // 未連携 + 未dismiss時に Liftly 連携を提案
                        if !authService.isSignedIn && !liftlyLinkPromptDismissed {
                            showLiftlyLinkPrompt = true
                        }
                    }
                    trainingStatusChip(title: "してない", isSelected: !todaysTrainingStatus) {
                        updateTrainingStatus(false)
                    }
                }
            }

            Spacer()

            // 今日の記録へジャンプ
            if !todaysDrinkSummaries.isEmpty {
                Button {
                    withAnimation(.spring(duration: 0.9, bounce: 0.16)) {
                        proxy.scrollTo(ScrollTarget.todaySummary, anchor: .top)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("今日の記録")
                            .font(.SG.caption)
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption)
                    }
                    .foregroundStyle(heroTone)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(.thinMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(heroTone.opacity(0.22), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func trainingStatusChip(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.SG.caption)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(isSelected ? Color.SG.accent : Color.SG.accent.opacity(0.1))
                .foregroundStyle(isSelected ? Color.white : Color.SG.accent)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var todayDrinkSummarySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("今日の杯数サマリー")
                    .font(.SG.headline)
                    .foregroundStyle(Color.SG.textPrimary)

                Spacer()

                // Daily damage report share button
                Button {
                    shareDailyDamageReport()
                } label: {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                        Text("シェア")
                            .font(.SG.caption)
                    }
                    .foregroundStyle(Color.SG.accent)
                }
                .buttonStyle(.plain)

                Text("\(todaysRecords.count)杯")
                    .font(.SG.caption)
                    .foregroundStyle(Color.SG.textSecondary)
            }

            ForEach(todaysDrinkSummaries) { summary in
                TodayDrinkSummaryRow(summary: summary, heroTone: heroTone) {
                    quickAdd(summary)
                }
            }
        }
        .id(ScrollTarget.todaySummary)
    }

    @ViewBuilder
    private var todayHistorySection: some View {
        if !todaysRecords.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("今日の記録タイムライン")
                    .font(.SG.headline)
                    .foregroundStyle(Color.SG.textPrimary)

                ForEach(todaysRecords, id: \.id) { record in
                    TodayHistoryRow(record: record)
                }
            }
            .id(ScrollTarget.todayHistory)
        }
    }

    private var drinkButton: some View {
        HStack(spacing: Spacing.sm) {
            // Session start/stop toggle
            Button {
                if activeSession != nil {
                    // Show session report when stopping from bottom bar
                    if let session = activeSession {
                        endSession(session)
                    }
                } else {
                    startSession()
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: activeSession != nil ? "stop.circle.fill" : "party.popper.fill")
                        .font(.title3)
                    Text(activeSession != nil ? "終了" : "飲み会開始")
                        .font(.SG.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .foregroundStyle(activeSession != nil ? .red : Color.SG.accent)
                .frame(width: 88)
                .frame(minHeight: 48)
                .background(
                    (activeSession != nil ? Color.red : Color.SG.accent)
                        .opacity(0.12)
                )
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
            }
            .buttonStyle(.plain)

            // Record drink button
            SGButton("home.drink_button", icon: "plus.circle.fill") {
                previousRecordCount = todaysRecords.count
                entryTemplate = nil
                showDrinkEntry = true
            }
        }
        .sensoryFeedback(.impact(flexibility: .solid), trigger: showDrinkEntry)
    }

    private func updateTrainingStatus(_ didTrain: Bool) {
        if let todayTrainingRecord {
            todayTrainingRecord.didTrain = didTrain
        } else {
            modelContext.insert(DailyTrainingStatus(date: .now, didTrain: didTrain))
        }

        for record in todaysRecords {
            record.didTrainToday = didTrain
        }

        // 筋トレ状態に連動して昨日のリカバリーログにお詫び行動を自動追加/削除
        if !yesterdaysRecords.isEmpty {
            let log = ensureRecoveryLog(for: DayBoundary.startOfYesterday())
            if didTrain {
                log.addAction(.workout)
            } else {
                log.removeAction(.workout)
            }
        }

        try? modelContext.save()
    }

    private func quickAdd(_ summary: DrinkTypeSummary) {
        guard let latestRecord = summary.latestRecord else { return }

        let record = DrinkRecord(
            drinkType: latestRecord.drinkType,
            volumeML: latestRecord.volumeML,
            alcoholPercent: latestRecord.alcoholPercent,
            didTrainToday: todaysTrainingStatus
        )

        modelContext.insert(record)
        try? modelContext.save()

        // Show character reaction for quick-add too
        let newCount = todaysRecords.count
        let reaction = DrinkReactionProvider.reaction(forDrinkNumber: newCount)
        currentDrinkReaction = reaction
    }

    // MARK: - Recovery Actions

    @discardableResult
    private func ensureRecoveryLog(for dayStart: Date) -> DailyRecoveryLog {
        let targetStart = DayBoundary.startOfDay(containing: dayStart)
        if let existing = dailyRecoveryLogs.first(where: {
            DayBoundary.startOfDay(containing: $0.date) == targetStart
        }) {
            return existing
        }
        let log = DailyRecoveryLog(date: targetStart)
        modelContext.insert(log)
        try? modelContext.save()
        return log
    }

    private func completeRecoveryAction(_ action: RecoveryActionType) {
        let log = ensureRecoveryLog(for: DayBoundary.startOfYesterday())
        guard !log.hasCompleted(action) else { return }

        log.addAction(action)
        try? modelContext.save()

        let reaction = action.reactionDialogue(for: characterStage)
        withAnimation { recoveryReactionToast = reaction }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { recoveryReactionToast = nil }
        }

        // Check achievements after recovery action
        achievementTracker.checkAll(context: modelContext)
    }

    // MARK: - Share

    private func shareDailyDamageReport() {
        guard let uiImage = ShareImageRenderer.renderDamageReportUIImage(
            date: .now,
            records: todaysRecords,
            impact: dailyImpact,
            characterStage: characterStage
        ) else { return }

        let controller = UIActivityViewController(
            activityItems: [uiImage],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
           let root = windowScene.windows.first?.rootViewController {
            root.present(controller, animated: true)
        }
    }

    // MARK: - Drinking Session

    private func startSession() {
        let session = DrinkingSession()
        modelContext.insert(session)
        try? modelContext.save()
        CharacterNotificationManager.shared.scheduleSessionAlert(sessionStart: session.startedAt)
    }

    private func endSession(_ session: DrinkingSession) {
        session.endedAt = .now
        try? modelContext.save()
        CharacterNotificationManager.shared.cancelSessionAlerts()
        showSessionReport = true
    }

    private func sessionDrinkCount(_ session: DrinkingSession) -> Int {
        todaysRecords.filter { $0.timestamp >= session.startedAt }.count
    }

    private func sessionRecords(_ session: DrinkingSession?) -> [DrinkRecord] {
        guard let session else { return [] }
        let end = session.endedAt ?? .now
        return todaysRecords.filter { $0.timestamp >= session.startedAt && $0.timestamp <= end }
    }

    // MARK: - Toolbar

    private var todayCountBadge: some View {
        HStack(spacing: 4) {
            Text("今日")
                .font(.SG.caption)
                .foregroundStyle(Color.SG.textSecondary)
            Text("\(todaysRecords.count)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(heroTone)
                .contentTransition(.numericText())
            Text("杯")
                .font(.SG.caption)
                .foregroundStyle(Color.SG.textSecondary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(heroTone.opacity(0.12), in: Capsule())
    }

    // MARK: - Helpers

    private func fetchProfile() -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = (try? modelContext.fetch(descriptor)) ?? []
        return profiles.first ?? UserProfile()
    }

    private var recordedToast: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.SG.accent)
            Text("記録しました！")
                .font(.SG.headline)
                .foregroundStyle(Color.SG.textPrimary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: Color.black.opacity(0.2), radius: 12, y: 6)
        .padding(.top, Spacing.xl)
    }

    private func recoveryReactionToastView(text: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "dumbbell.fill")
                .foregroundStyle(Color.SG.accent)
            Text(text)
                .font(.SG.headline)
                .foregroundStyle(Color.SG.textPrimary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: Color.black.opacity(0.2), radius: 12, y: 6)
        .padding(.top, Spacing.xl)
    }
}

private struct TodayDrinkSummaryRow: View {
    let summary: DrinkTypeSummary
    let heroTone: Color
    let onQuickAdd: () -> Void

    private var latestDetailsText: String {
        guard let latestRecord = summary.latestRecord else {
            return String(localized: "drink.addAnother.same")
        }

        return String(
            format: String(localized: "drink.addAnother.detail"),
            Int(latestRecord.volumeML),
            String(format: "%.1f", latestRecord.alcoholPercent)
        )
    }

    var body: some View {
        SGCard {
            HStack(spacing: Spacing.sm) {
                Image(systemName: summary.drinkType.symbolName)
                    .font(.title3)
                    .foregroundStyle(heroTone)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(summary.drinkType.localizedName)
                            .font(.SG.headline)
                            .foregroundStyle(Color.SG.textPrimary)

                        Text("×\(summary.count)")
                            .font(.SG.caption)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 2)
                            .background(heroTone.opacity(0.14))
                            .foregroundStyle(heroTone)
                            .clipShape(Capsule())
                    }

                    Text("合計 \(Int(summary.totalVolumeML))ml")
                        .font(.SG.caption)
                        .foregroundStyle(Color.SG.textSecondary)

                    Text(latestDetailsText)
                        .font(.SG.caption)
                        .foregroundStyle(Color.SG.textSecondary)
                }

                Spacer()

                Button(action: onQuickAdd) {
                    VStack(spacing: 2) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text("+1杯")
                            .font(.SG.caption)
                    }
                    .foregroundStyle(Color.SG.accent)
                    .frame(minWidth: 60)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct TodayHistoryRow: View {
    let record: DrinkRecord

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: record.timestamp)
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: record.drinkType.symbolName)
                .font(.title3)
                .foregroundStyle(Color.SG.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.drinkType.localizedName)
                    .font(.SG.headline)
                    .foregroundStyle(Color.SG.textPrimary)

                Text("\(Int(record.volumeML))ml / \(String(format: "%.1f", record.alcoholPercent))%")
                    .font(.SG.caption)
                    .foregroundStyle(Color.SG.textSecondary)
            }

            Spacer()

            Text(timeString)
                .font(.SG.caption)
                .foregroundStyle(Color.SG.textSecondary)
        }
        .padding(Spacing.sm)
        .background(Color.SG.surface)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))
    }
}

private struct LiftlyLinkPromptSheet: View {
    @Environment(\.dismiss) private var dismiss

    let isLoading: Bool
    let activeProvider: AuthProviderKind?
    let error: String?
    let onAppleSignIn: () async -> Void
    let onGoogleSignIn: () async -> Void
    let onContinueManually: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Liftlyと連携しませんか？")
                    .font(.SG.title2)
                    .foregroundStyle(Color.SG.textPrimary)
                Text("筋トレ状態を自動で取得できます。手入力も引き続き使えます。")
                    .font(.SG.body)
                    .foregroundStyle(Color.SG.textSecondary)
            }

            VStack(spacing: Spacing.sm) {
                SignInChoiceButton(
                    title: String(localized: "auth.signIn.apple"),
                    systemImage: "apple.logo",
                    provider: .apple,
                    activeProvider: activeProvider,
                    isLoading: isLoading
                ) {
                    await onAppleSignIn()
                    dismiss()
                }

                SignInChoiceButton(
                    title: String(localized: "auth.signIn.google"),
                    systemImage: "g.circle.fill",
                    provider: .google,
                    activeProvider: activeProvider,
                    isLoading: isLoading
                ) {
                    await onGoogleSignIn()
                    dismiss()
                }
            }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.SG.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }

            Button {
                onContinueManually()
                dismiss()
            } label: {
                Text("手入力を続ける")
                    .font(.SG.body)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.SG.textSecondary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.SG.background)
    }
}

private struct SignInChoiceButton: View {
    let title: String
    let systemImage: String
    let provider: AuthProviderKind
    let activeProvider: AuthProviderKind?
    let isLoading: Bool
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            HStack(spacing: Spacing.sm) {
                if activeProvider == provider {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: systemImage)
                        .frame(width: 22)
                }

                Text(title)
                    .font(.SG.body)
                    .fontWeight(.semibold)

                Spacer()
            }
            .foregroundStyle(Color.SG.textPrimary)
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(Color.SG.surface.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))
            .overlay {
                RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall)
                    .stroke(Color.SG.textSecondary.opacity(0.3), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading && activeProvider != provider ? 0.55 : 1)
    }
}
