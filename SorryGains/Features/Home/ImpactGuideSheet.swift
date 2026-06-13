import SwiftUI

/// 影響度の仕組みをユーザーに説明するヘルプシート。
struct ImpactGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    impactScoreSection
                    angerLevelSection
                    trainingEffectSection
                    recoverySection
                    dailyResetSection
                    weeklyTotalSection
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .navigationTitle("数値の見方")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    // MARK: - Impact Score

    private var impactScoreSection: some View {
        guideCard(
            icon: "gauge.with.needle.fill",
            title: "影響スコア",
            subtitle: "0〜100",
            color: Color.SG.accent
        ) {
            guideParagraph("飲酒が筋肉に与えるダメージの大きさを表します。")

            guideFormula("飲酒量(g) × 体格補正 × トレーニング補正")

            guideBullets([
                "体重が軽いほどスコアが高くなります",
                "トレーニング頻度が高いほどスコアが高くなります（筋肉への影響が大きいため）",
                "上限は100。お詫び行動でスコアを下げられます",
            ])
        }
    }

    // MARK: - Anger Level

    private var angerLevelSection: some View {
        guideCard(
            icon: "flame.fill",
            title: "怒り度",
            subtitle: "0〜5段階",
            color: Color.SG.apologyColor(for: 3)
        ) {
            guideParagraph("筋肉がどれだけ怒っているかを表します。影響スコアから自動で決まります。")

            VStack(alignment: .leading, spacing: Spacing.xs) {
                angerRow(level: 0, desc: "飲んでいない / 許してもらえた")
                angerRow(level: 1, desc: "ちょっと気にしてる")
                angerRow(level: 2, desc: "不機嫌")
                angerRow(level: 3, desc: "かなり怒ってる")
                angerRow(level: 4, desc: "激怒")
                angerRow(level: 5, desc: "筋肉ブチギレ")
            }

            guideParagraph("お詫び行動の許しポイント合計 ÷ 3 = 怒り度の軽減量。怒り度が 0 になると「許してもらえた」と表示されます。")
        }
    }

    // MARK: - Training Effect

    private var trainingEffectSection: some View {
        guideCard(
            icon: "dumbbell.fill",
            title: "筋トレ成果 / 筋肉ダウン",
            subtitle: "0〜100%",
            color: Color.SG.apologyMild
        ) {
            guideParagraph("筋トレした日としていない日で意味が変わります。")

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .top, spacing: Spacing.xs) {
                    Text("筋トレした日")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.SG.apologyMild)
                        .frame(width: 90, alignment: .leading)
                    Text("トレーニング成果のうち、飲酒によって無駄になった割合")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.SG.textSecondary)
                }
                HStack(alignment: .top, spacing: Spacing.xs) {
                    Text("筋トレなし")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.SG.textSecondary)
                        .frame(width: 90, alignment: .leading)
                    Text("飲酒による筋肉量へのマイナス影響（最大30%）")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.SG.textSecondary)
                }
            }

            guideParagraph("Liftly連携時は、トレーニング強度や経過時間も加味されます。")
        }
    }

    // MARK: - Recovery

    private var recoverySection: some View {
        guideCard(
            icon: "heart.circle.fill",
            title: "お詫び行動",
            subtitle: "許しポイント & スコア軽減",
            color: Color.SG.accent
        ) {
            guideParagraph("筋肉に良い行動を報告すると、怒り度と影響スコアの両方が下がります。")

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                ForEach(RecoveryActionType.allCases) { action in
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: action.symbolName)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.SG.accent)
                            .frame(width: 20)
                        Text(action.localizedName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.SG.textPrimary)
                        Spacer()
                        Text("+\(action.forgivenessPoints)pt")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.SG.accent)
                        Text("-\(Int(action.scoreReduction))")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.SG.apologyMild)
                    }
                }
            }

            guideParagraph("各行動は1日1回まで。全7種を達成すると、ほとんどの飲酒ダメージを帳消しにできます。")
        }
    }

    // MARK: - Daily Reset

    private var dailyResetSection: some View {
        guideCard(
            icon: "clock.arrow.circlepath",
            title: "日次リセット",
            subtitle: "毎日 午前4:00",
            color: Color.SG.textSecondary
        ) {
            guideBullets([
                "毎日午前4時に、その日の影響スコア・怒り度・お詫び行動がリセットされます",
                "深夜0〜3時台の飲酒は「前日分」として集計されます",
                "過去のデータは週次・累計タブで確認できます",
            ])
        }
    }

    // MARK: - Weekly/Total

    private var weeklyTotalSection: some View {
        guideCard(
            icon: "chart.bar.fill",
            title: "今週 / 累計",
            subtitle: "長期的な傾向を把握",
            color: Color.SG.accent
        ) {
            guideBullets([
                "「今週」は過去7日間の合計影響スコアと飲酒回数",
                "「累計」は全期間の記録から集計",
                "1日平均・1杯平均のスコアで、飲酒習慣の変化が見えます",
            ])
        }
    }

    // MARK: - Shared Components

    private func guideCard<Content: View>(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.SG.headline)
                        .foregroundStyle(Color.SG.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.SG.textSecondary)
                }
            }

            content()
        }
        .padding(Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.SG.surface)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }

    private func guideParagraph(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Color.SG.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func guideFormula(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.SG.accent)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background(Color.SG.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))
    }

    private func guideBullets(_ items: [LocalizedStringKey]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            ForEach(0..<items.count, id: \.self) { index in
                HStack(alignment: .top, spacing: Spacing.xs) {
                    Text("•")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.SG.textSecondary)
                    Text(items[index])
                        .font(.system(size: 13))
                        .foregroundStyle(Color.SG.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func angerRow(level: Int, desc: LocalizedStringKey) -> some View {
        HStack(spacing: Spacing.xs) {
            Text("Lv.\(level)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(level == 0 ? Color.SG.apologyMild : Color.SG.apologyColor(for: level))
                .frame(width: 36, alignment: .leading)
            Text(desc)
                .font(.system(size: 12))
                .foregroundStyle(Color.SG.textSecondary)
        }
    }
}
