import Testing
@testable import SorryGains

@Suite("DailyImpactCalculator Tests")
struct DailyImpactCalculatorTests {

    let calculator = DailyImpactCalculator.live

    // MARK: - Zero Drinks

    @Test("Zero drinks returns all-zero result")
    func zeroDrinks() {
        let result = calculator.calculate([], UserProfile(), false, nil)

        #expect(result.totalPureAlcoholGram == 0)
        #expect(result.wastedPercent == 0)
        #expect(result.angerLevel == 0)
        #expect(result.impactScore == 0)
        #expect(result.characterStage == 0)
        #expect(result.drinkCount == 0)
    }

    // MARK: - Single Beer = Low Anger

    @Test("Single beer (350ml 5%) produces anger level 1")
    func singleBeerLowAnger() {
        let drink = DrinkRecord(drinkType: .beer, volumeML: 350, alcoholPercent: 5.0)
        let profile = UserProfile()  // 65kg, 3x/week

        let result = calculator.calculate([drink], profile, false, nil)

        // 14g alcohol with daily coefficients → lossScore ≈ 18.7 → below threshold 30
        #expect(result.angerLevel == 1)
        #expect(abs(result.totalPureAlcoholGram - 14.0) < 0.01)
    }

    @Test("Two beers produce anger level 2")
    func twoBeersAngerTwo() {
        let drinks = [
            DrinkRecord(drinkType: .beer, volumeML: 350, alcoholPercent: 5.0),
            DrinkRecord(drinkType: .beer, volumeML: 350, alcoholPercent: 5.0),
        ]
        let profile = UserProfile()

        let result = calculator.calculate(drinks, profile, false, nil)

        // 28g → lossScore ≈ 37.4 → exceeds [30] → anger 2
        #expect(result.angerLevel == 2)
    }

    @Test("Five beers produce anger level 5")
    func fiveBeersAngerFive() {
        let drinks = (0..<5).map { _ in
            DrinkRecord(drinkType: .beer, volumeML: 350, alcoholPercent: 5.0)
        }
        let profile = UserProfile()

        let result = calculator.calculate(drinks, profile, true, nil)

        // 70g → lossScore ≈ 93.5 → exceeds all 4 thresholds [20, 40, 60, 80] → anger 5 (max)
        // LossCoefficients.daily コメント: 「ビール1杯→Lv1, 2杯→Lv2, 4杯→Lv4, 5杯→Lv5」
        #expect(result.angerLevel == 5)
    }

    // MARK: - Multiple Drinks Aggregate

    @Test("Multiple drinks aggregate pure alcohol correctly")
    func multipleDrinksAggregate() {
        let beer = DrinkRecord(drinkType: .beer, volumeML: 350, alcoholPercent: 5.0)
        let sake = DrinkRecord(drinkType: .sake, volumeML: 180, alcoholPercent: 15.0)
        let profile = UserProfile()

        let result = calculator.calculate([beer, sake], profile, false, nil)

        // beer: 350 * 0.05 * 0.8 = 14g, sake: 180 * 0.15 * 0.8 = 21.6g, total = 35.6g
        #expect(abs(result.totalPureAlcoholGram - 35.6) < 0.01)
        #expect(result.drinkCount == 2)
    }

    @Test("Multiple drinks produce higher anger than single drink")
    func multipleDrinksHigherAnger() {
        let beer = DrinkRecord(drinkType: .beer, volumeML: 350, alcoholPercent: 5.0)
        let profile = UserProfile()

        let singleResult = calculator.calculate([beer], profile, true, nil)
        let doubleResult = calculator.calculate([beer, beer], profile, true, nil)

        #expect(doubleResult.angerLevel >= singleResult.angerLevel)
        #expect(doubleResult.wastedPercent >= singleResult.wastedPercent)
    }

    // MARK: - Anger Level Range

    @Test("Anger level is within 1-5 for non-empty records")
    func angerLevelRange() {
        let drink = DrinkRecord(drinkType: .beer, volumeML: 350, alcoholPercent: 5.0)
        let profile = UserProfile()
        let result = calculator.calculate([drink], profile, false, nil)

        #expect(result.angerLevel >= 1)
        #expect(result.angerLevel <= 5)
    }

    @Test("Heavy drinking produces high anger")
    func heavyDrinkingHighAnger() {
        let drinks = (0..<5).map { _ in
            DrinkRecord(drinkType: .sake, volumeML: 180, alcoholPercent: 15.0)
        }
        let profile = UserProfile(bodyWeightKG: 50, trainingPerWeek: 6)

        let result = calculator.calculate(drinks, profile, true)
        #expect(result.angerLevel >= 4)
    }

    // MARK: - Weight Factor

    @Test("Lighter person gets higher impact")
    func weightFactorImpact() {
        let drinks = [DrinkRecord(drinkType: .beer, volumeML: 500, alcoholPercent: 5.0)]
        let light = UserProfile(bodyWeightKG: 50, trainingPerWeek: 3)
        let heavy = UserProfile(bodyWeightKG: 90, trainingPerWeek: 3)

        let lightResult = calculator.calculate(drinks, light, false)
        let heavyResult = calculator.calculate(drinks, heavy, false)

        #expect(lightResult.wastedPercent > heavyResult.wastedPercent)
    }

    // MARK: - Training Factor

    @Test("Training on drink day yields higher wasted percent")
    func trainingDayHigherWaste() {
        let drinks = [DrinkRecord(drinkType: .beer, volumeML: 500, alcoholPercent: 5.0)]
        let profile = UserProfile(bodyWeightKG: 70, trainingPerWeek: 5)

        let trainedResult = calculator.calculate(drinks, profile, true)
        let notTrainedResult = calculator.calculate(drinks, profile, false)

        #expect(trainedResult.wastedPercent >= notTrainedResult.wastedPercent)
    }

    // MARK: - Character Stage

    @Test("Character stage is derived from anger level")
    func characterStageDerivedFromAnger() {
        let drink = DrinkRecord(drinkType: .beer, volumeML: 350, alcoholPercent: 5.0)
        let profile = UserProfile()
        let result = calculator.calculate([drink], profile, false, nil)

        #expect(result.characterStage == min(4, result.angerLevel - 1))
    }

    @Test("Zero drinks gives character stage 0")
    func zeroDrinksCharacterStage() {
        let result = calculator.calculate([], UserProfile(), false, nil)
        #expect(result.characterStage == 0)
    }
}
