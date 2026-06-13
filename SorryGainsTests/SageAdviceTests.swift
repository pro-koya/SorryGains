import Foundation
import Testing
@testable import SorryGains

@Suite("SageAdvice Tests")
struct SageAdviceTests {

    let provider = LocalSageAdviceProvider()

    // MARK: - Category Determination

    @Test("Streak category when 3+ consecutive drinking days")
    func streakCategory() async {
        let context = SageContext(
            todayDrinkCount: 1,
            todayTotalAlcoholGram: 14,
            todayDidTrain: false,
            weekDrinkCount: 4,
            weekTrainingDays: 1,
            consecutiveDrinkingDays: 3,
            trainingGoal: .maintain,
            latestAngerLevel: 3
        )
        let advice = await provider.provideAdvice(for: context)
        #expect(advice.category == .streak)
    }

    @Test("Drank too much when 3+ drinks today")
    func drankTooMuchByCount() async {
        let context = SageContext(
            todayDrinkCount: 4,
            todayTotalAlcoholGram: 56,
            todayDidTrain: false,
            weekDrinkCount: 1,
            weekTrainingDays: 2,
            consecutiveDrinkingDays: 1,
            trainingGoal: .bulk,
            latestAngerLevel: 4
        )
        let advice = await provider.provideAdvice(for: context)
        #expect(advice.category == .drankTooMuch)
    }

    @Test("Drank too much when 40g+ alcohol today")
    func drankTooMuchByAlcohol() async {
        let context = SageContext(
            todayDrinkCount: 2,
            todayTotalAlcoholGram: 45,
            todayDidTrain: true,
            weekDrinkCount: 1,
            weekTrainingDays: 3,
            consecutiveDrinkingDays: 1,
            trainingGoal: .cut,
            latestAngerLevel: nil
        )
        let advice = await provider.provideAdvice(for: context)
        #expect(advice.category == .drankTooMuch)
    }

    @Test("Drank a little when 1-2 drinks today")
    func drankALittle() async {
        let context = SageContext(
            todayDrinkCount: 1,
            todayTotalAlcoholGram: 14,
            todayDidTrain: false,
            weekDrinkCount: 1,
            weekTrainingDays: 2,
            consecutiveDrinkingDays: 1,
            trainingGoal: .maintain,
            latestAngerLevel: 2
        )
        let advice = await provider.provideAdvice(for: context)
        #expect(advice.category == .drankALittle)
    }

    @Test("Good job when trained and no drinks")
    func goodJobCategory() async {
        let context = SageContext(
            todayDrinkCount: 0,
            todayTotalAlcoholGram: 0,
            todayDidTrain: true,
            weekDrinkCount: 0,
            weekTrainingDays: 4,
            consecutiveDrinkingDays: 0,
            trainingGoal: .bulk,
            latestAngerLevel: nil
        )
        let advice = await provider.provideAdvice(for: context)
        #expect(advice.category == .goodJob)
    }

    @Test("Neutral when no drinks and no training")
    func neutralCategory() async {
        let context = SageContext(
            todayDrinkCount: 0,
            todayTotalAlcoholGram: 0,
            todayDidTrain: false,
            weekDrinkCount: 0,
            weekTrainingDays: 0,
            consecutiveDrinkingDays: 0,
            trainingGoal: .casual,
            latestAngerLevel: nil
        )
        let advice = await provider.provideAdvice(for: context)
        #expect(advice.category == .neutral)
    }

    // MARK: - Category Priority

    @Test("Streak takes priority over drankTooMuch")
    func streakPriority() async {
        let context = SageContext(
            todayDrinkCount: 5,
            todayTotalAlcoholGram: 70,
            todayDidTrain: false,
            weekDrinkCount: 5,
            weekTrainingDays: 0,
            consecutiveDrinkingDays: 5,
            trainingGoal: .maintain,
            latestAngerLevel: 5
        )
        let advice = await provider.provideAdvice(for: context)
        #expect(advice.category == .streak)
    }

    // MARK: - Tone Mapping

    @Test("Stern tone for heavy drinking")
    func sternTone() async {
        let context = SageContext(
            todayDrinkCount: 4,
            todayTotalAlcoholGram: 56,
            todayDidTrain: false,
            weekDrinkCount: 1,
            weekTrainingDays: 0,
            consecutiveDrinkingDays: 1,
            trainingGoal: .maintain,
            latestAngerLevel: nil
        )
        let advice = await provider.provideAdvice(for: context)
        #expect(advice.tone == .stern)
    }

    @Test("Fired up tone for good job")
    func firedUpTone() async {
        let context = SageContext(
            todayDrinkCount: 0,
            todayTotalAlcoholGram: 0,
            todayDidTrain: true,
            weekDrinkCount: 0,
            weekTrainingDays: 5,
            consecutiveDrinkingDays: 0,
            trainingGoal: .bulk,
            latestAngerLevel: nil
        )
        let advice = await provider.provideAdvice(for: context)
        #expect(advice.tone == .firedUp)
    }

    // MARK: - Advice Content

    @Test("Advice message is never empty")
    func messageNotEmpty() async {
        let contexts: [SageContext] = [
            SageContext(todayDrinkCount: 0, todayTotalAlcoholGram: 0, todayDidTrain: false, weekDrinkCount: 0, weekTrainingDays: 0, consecutiveDrinkingDays: 0, trainingGoal: .casual, latestAngerLevel: nil),
            SageContext(todayDrinkCount: 5, todayTotalAlcoholGram: 70, todayDidTrain: false, weekDrinkCount: 3, weekTrainingDays: 1, consecutiveDrinkingDays: 3, trainingGoal: .bulk, latestAngerLevel: 5),
            SageContext(todayDrinkCount: 0, todayTotalAlcoholGram: 0, todayDidTrain: true, weekDrinkCount: 0, weekTrainingDays: 3, consecutiveDrinkingDays: 0, trainingGoal: .cut, latestAngerLevel: nil),
        ]

        for context in contexts {
            let advice = await provider.provideAdvice(for: context)
            #expect(!advice.message.isEmpty)
        }
    }

    @Test("Deterministic: same context on same day returns same advice")
    func deterministicAdvice() async {
        let context = SageContext(
            todayDrinkCount: 2,
            todayTotalAlcoholGram: 28,
            todayDidTrain: false,
            weekDrinkCount: 2,
            weekTrainingDays: 1,
            consecutiveDrinkingDays: 1,
            trainingGoal: .maintain,
            latestAngerLevel: 2
        )

        // history をリセットして同じ状態から2回呼ぶことで決定論性を検証する
        await LocalSageAdviceProvider.history.reset()
        let first = await provider.provideAdvice(for: context)
        await LocalSageAdviceProvider.history.reset()
        let second = await provider.provideAdvice(for: context)
        #expect(first == second)
    }

    // MARK: - Follow Up

    @Test("drankTooMuch and streak have follow-up messages")
    func followUpPresence() async {
        let tooMuchContext = SageContext(
            todayDrinkCount: 4,
            todayTotalAlcoholGram: 56,
            todayDidTrain: false,
            weekDrinkCount: 1,
            weekTrainingDays: 0,
            consecutiveDrinkingDays: 1,
            trainingGoal: .maintain,
            latestAngerLevel: nil
        )
        let streakContext = SageContext(
            todayDrinkCount: 1,
            todayTotalAlcoholGram: 14,
            todayDidTrain: false,
            weekDrinkCount: 4,
            weekTrainingDays: 0,
            consecutiveDrinkingDays: 4,
            trainingGoal: .maintain,
            latestAngerLevel: nil
        )

        let tooMuchAdvice = await provider.provideAdvice(for: tooMuchContext)
        let streakAdvice = await provider.provideAdvice(for: streakContext)

        #expect(tooMuchAdvice.followUp != nil)
        #expect(streakAdvice.followUp != nil)
    }
}

// MARK: - SageContextBuilder Tests

@Suite("SageContextBuilder Tests")
struct SageContextBuilderTests {

    @Test("Empty records produce zero context")
    func emptyRecords() {
        let context = SageContextBuilder.build(
            records: [],
            trainingStatuses: [],
            profile: UserProfile()
        )
        #expect(context.todayDrinkCount == 0)
        #expect(context.todayTotalAlcoholGram == 0)
        #expect(context.todayDidTrain == false)
        #expect(context.weekDrinkCount == 0)
        #expect(context.weekTrainingDays == 0)
        #expect(context.consecutiveDrinkingDays == 0)
        #expect(context.latestAngerLevel == nil)
    }

    @Test("Today's records are counted correctly")
    func todayRecordsCounted() {
        let now = Date()
        let records = [
            DrinkRecord(timestamp: now, drinkType: .beer, volumeML: 350, alcoholPercent: 5.0),
            DrinkRecord(timestamp: now, drinkType: .highball, volumeML: 350, alcoholPercent: 7.0),
        ]
        let context = SageContextBuilder.build(
            records: records,
            trainingStatuses: [],
            profile: UserProfile()
        )
        #expect(context.todayDrinkCount == 2)
        // 350*0.05*0.8 = 14g + 350*0.07*0.8 = 19.6g = 33.6g
        #expect(abs(context.todayTotalAlcoholGram - 33.6) < 0.1)
    }

    @Test("Training goal is passed through from profile")
    func trainingGoalPassthrough() {
        let profile = UserProfile(goal: .cut)
        let context = SageContextBuilder.build(
            records: [],
            trainingStatuses: [],
            profile: profile
        )
        #expect(context.trainingGoal == .cut)
    }

    @Test("Latest anger level from most recent record")
    func latestAngerLevel() {
        let now = Date()
        let older = DrinkRecord(
            timestamp: now.addingTimeInterval(-3600),
            drinkType: .beer, volumeML: 350, alcoholPercent: 5.0,
            currentAngerLevel: 2
        )
        let newer = DrinkRecord(
            timestamp: now,
            drinkType: .sake, volumeML: 180, alcoholPercent: 15.0,
            currentAngerLevel: 4
        )
        let context = SageContextBuilder.build(
            records: [older, newer],
            trainingStatuses: [],
            profile: UserProfile()
        )
        #expect(context.latestAngerLevel == 4)
    }
}
