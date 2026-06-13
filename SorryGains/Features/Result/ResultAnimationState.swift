import SwiftData
import SwiftUI

/// Drives the staggered animation sequence and apology interaction on the Result screen.
@MainActor
@Observable
final class ResultAnimationState {
    // MARK: - Phase flags

    private(set) var characterReady = false
    private(set) var captionVisible = false
    private(set) var metricsVisible = false
    private(set) var actionsVisible = false

    // MARK: - Count-up display values

    private(set) var displayedWastedPercent: Double = 0
    private(set) var displayedAngerLevel: Int = 0
    private(set) var displayedImpactScore: Double = 0

    // MARK: - Apology interaction

    private(set) var apologyCount: Int = 0
    private(set) var currentAngerLevel: Int = 0
    private(set) var currentImpactScore: Double = 0
    private(set) var savedScore: Double = 0
    private(set) var forgiven: Bool = false
    private(set) var apologyReaction: Int = 0
    private(set) var apologyCooldown: Bool = false

    // MARK: - Haptic triggers

    private(set) var metricHapticTick: Int = 0
    private(set) var angerRevealTick: Int = 0
    private(set) var apologyHapticTick: Int = 0

    // MARK: - Run

    func run(result: ApologyResult, record: DrinkRecord, reduceMotion: Bool) async {
        // 既存の謝罪データがあれば復元
        if record.apologyCount > 0 {
            apologyCount = record.apologyCount
            savedScore = record.savedHours // DrinkRecord の既存フィールドを流用
            let restoredAnger = record.currentAngerLevel ?? result.angerLevel
            currentAngerLevel = restoredAnger
            currentImpactScore = max(0, result.impactScore - savedScore)
            forgiven = restoredAnger == 0
        } else {
            currentAngerLevel = result.angerLevel
            currentImpactScore = result.impactScore
        }

        if reduceMotion {
            showAllImmediately(result: result)
            return
        }

        characterReady = true
        try? await Task.sleep(for: .milliseconds(600))

        withAnimation(.easeOut(duration: 0.4)) {
            captionVisible = true
        }
        try? await Task.sleep(for: .milliseconds(400))

        withAnimation(.easeOut(duration: 0.3)) {
            metricsVisible = true
        }
        try? await Task.sleep(for: .milliseconds(100))

        await countUp(\.displayedWastedPercent, to: result.wastedPercent, steps: 20, stepMS: 30)
        metricHapticTick += 1

        try? await Task.sleep(for: .milliseconds(300))
        await countUpAnger(to: currentAngerLevel)
        angerRevealTick += 1

        try? await Task.sleep(for: .milliseconds(300))
        await countUp(\.displayedImpactScore, to: currentImpactScore, steps: 15, stepMS: 40)
        metricHapticTick += 1

        try? await Task.sleep(for: .milliseconds(300))
        withAnimation(.easeOut(duration: 0.3)) {
            actionsVisible = true
        }
    }

    // MARK: - Apologize

    /// 筋肉に謝る。怒り度と影響スコアが減る。クールダウン付き。
    func apologize(result: ApologyResult, record: DrinkRecord, context: Any?) {
        guard !forgiven, !apologyCooldown else { return }

        apologyCount += 1
        apologyReaction += 1
        apologyHapticTick += 1

        // クールダウン開始（1秒間非活性）
        apologyCooldown = true

        // 怒り度を減少（3回謝るごとに1段階下がる）
        let newAnger = max(0, result.angerLevel - (apologyCount / 3))
        withAnimation(.bouncy(duration: 0.4)) {
            currentAngerLevel = newAnger
            displayedAngerLevel = newAnger
        }

        // 影響スコアを軽減（1回ごとにランダムで3〜10pt軽減）
        let reduction = Double.random(in: 3...10)
        let newScore = max(0, currentImpactScore - reduction)
        savedScore = result.impactScore - newScore

        withAnimation(.easeOut(duration: 0.3)) {
            currentImpactScore = newScore
            displayedImpactScore = newScore
        }

        // DrinkRecord に永続化（savedHours フィールドを影響スコア軽減量として流用）
        record.apologyCount = apologyCount
        record.savedHours = savedScore
        record.currentAngerLevel = newAnger
        if let ctx = context as? ModelContext {
            try? ctx.save()
        }

        if newAnger == 0 {
            withAnimation(.bouncy(duration: 0.6)) {
                forgiven = true
            }
        }

        // クールダウン解除（1秒後）
        Task {
            try? await Task.sleep(for: .seconds(1))
            apologyCooldown = false
        }
    }

    // MARK: - Private

    private func showAllImmediately(result: ApologyResult) {
        characterReady = true
        captionVisible = true
        metricsVisible = true
        actionsVisible = true
        displayedWastedPercent = result.wastedPercent
        displayedAngerLevel = currentAngerLevel
        displayedImpactScore = currentImpactScore
    }

    private func countUp(
        _ keyPath: ReferenceWritableKeyPath<ResultAnimationState, Double>,
        to target: Double,
        steps: Int,
        stepMS: UInt64
    ) async {
        for i in 1...steps {
            let value = target * Double(i) / Double(steps)
            withAnimation(.linear(duration: 0.03)) {
                self[keyPath: keyPath] = value
            }
            try? await Task.sleep(for: .milliseconds(stepMS))
        }
        withAnimation(.linear(duration: 0.03)) {
            self[keyPath: keyPath] = target
        }
    }

    private func countUpAnger(to target: Int) async {
        guard target > 0 else { return }
        for i in 1...target {
            withAnimation(.linear(duration: 0.05)) {
                displayedAngerLevel = i
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}
