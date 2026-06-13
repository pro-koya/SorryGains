import Testing
@testable import SorryGains

@Suite("ApologyCalculator Tests")
struct CalculationTests {

    let calculator = ApologyCalculator.live

    // MARK: - Pure Alcohol Gram

    @Test("Pure alcohol gram calculation: 350ml beer at 5%")
    func pureAlcoholGramBeer() {
        let drink = DrinkRecord(drinkType: .beer, volumeML: 350, alcoholPercent: 5.0)
        let profile = UserProfile()
        let result = calculator.calculate(drink, profile, false)

        // 350 * 0.05 * 0.8 = 14g
        #expect(abs(result.pureAlcoholGram - 14.0) < 0.01)
    }

    @Test("Pure alcohol gram calculation: 180ml sake at 15%")
    func pureAlcoholGramSake() {
        let drink = DrinkRecord(drinkType: .sake, volumeML: 180, alcoholPercent: 15.0)
        let profile = UserProfile()
        let result = calculator.calculate(drink, profile, false)

        // 180 * 0.15 * 0.8 = 21.6g
        #expect(abs(result.pureAlcoholGram - 21.6) < 0.01)
    }

    // MARK: - Wasted Percent

    @Test("Wasted percent is clamped to 0-100")
    func wastedPercentBounds() {
        // Light drink: should have low wasted percent
        let lightDrink = DrinkRecord(drinkType: .beer, volumeML: 200, alcoholPercent: 3.0)
        let profile = UserProfile(bodyWeightKG: 80, trainingPerWeek: 2)
        let lightResult = calculator.calculate(lightDrink, profile, false)
        #expect(lightResult.wastedPercent >= 0)
        #expect(lightResult.wastedPercent <= 100)

        // Heavy drink: should have high wasted percent
        let heavyDrink = DrinkRecord(drinkType: .sake, volumeML: 720, alcoholPercent: 15.0)
        let heavyProfile = UserProfile(bodyWeightKG: 50, trainingPerWeek: 7)
        let heavyResult = calculator.calculate(heavyDrink, heavyProfile, true)
        #expect(heavyResult.wastedPercent >= 0)
        #expect(heavyResult.wastedPercent <= 100)
    }

    // MARK: - Anger Level

    @Test("Anger level ranges from 1 to 5")
    func angerLevelRange() {
        let drink = DrinkRecord(drinkType: .beer, volumeML: 350, alcoholPercent: 5.0)
        let profile = UserProfile()
        let result = calculator.calculate(drink, profile, false)
        #expect(result.angerLevel >= 1)
        #expect(result.angerLevel <= 5)
    }

    @Test("Light drink produces low anger level")
    func lightDrinkLowAnger() {
        let drink = DrinkRecord(drinkType: .beer, volumeML: 150, alcoholPercent: 3.0)
        let profile = UserProfile(bodyWeightKG: 80, trainingPerWeek: 1)
        let result = calculator.calculate(drink, profile, false)
        #expect(result.angerLevel <= 2)
    }

    @Test("Heavy drink produces high anger level")
    func heavyDrinkHighAnger() {
        let drink = DrinkRecord(drinkType: .sake, volumeML: 720, alcoholPercent: 15.0)
        let profile = UserProfile(bodyWeightKG: 50, trainingPerWeek: 6)
        let result = calculator.calculate(drink, profile, true)
        #expect(result.angerLevel >= 4)
    }

    // MARK: - Weight Factor

    @Test("Lighter person gets higher wasted percent than heavier person")
    func weightFactorImpact() {
        let drink = DrinkRecord(drinkType: .beer, volumeML: 500, alcoholPercent: 5.0)
        let light = UserProfile(bodyWeightKG: 50, trainingPerWeek: 3)
        let heavy = UserProfile(bodyWeightKG: 90, trainingPerWeek: 3)

        let lightResult = calculator.calculate(drink, light, false)
        let heavyResult = calculator.calculate(drink, heavy, false)

        #expect(lightResult.wastedPercent > heavyResult.wastedPercent)
    }

    // MARK: - Training Factor

    @Test("Higher training frequency increases wasted percent (more 'waste')")
    func trainingFactorImpact() {
        let drink = DrinkRecord(drinkType: .beer, volumeML: 500, alcoholPercent: 5.0)
        let casual = UserProfile(bodyWeightKG: 70, trainingPerWeek: 1)
        let hardcore = UserProfile(bodyWeightKG: 70, trainingPerWeek: 7)

        let casualResult = calculator.calculate(drink, casual, true)
        let hardcoreResult = calculator.calculate(drink, hardcore, true)

        #expect(hardcoreResult.wastedPercent > casualResult.wastedPercent)
    }

    // MARK: - Character Stage

    @Test("Character stage matches anger level minus 1, capped at 4")
    func characterStageDerivedFromLevel() {
        let drink = DrinkRecord(drinkType: .beer, volumeML: 350, alcoholPercent: 5.0)
        let profile = UserProfile()
        let result = calculator.calculate(drink, profile, false)
        #expect(result.characterStage == min(4, result.angerLevel - 1))
    }

    // MARK: - Caption Key

    @Test("Caption key follows naming convention")
    func captionKeyFormat() {
        let drink = DrinkRecord(drinkType: .wine, volumeML: 375, alcoholPercent: 12.0)
        let profile = UserProfile()
        let result = calculator.calculate(drink, profile, false)
        #expect(result.captionKey.hasPrefix("result.caption.lv"))
    }

    // MARK: - Boundary

    @Test("Zero volume produces minimal loss")
    func zeroVolumeMinimalLoss() {
        let drink = DrinkRecord(drinkType: .beer, volumeML: 0, alcoholPercent: 5.0)
        let profile = UserProfile()
        let result = calculator.calculate(drink, profile, false)
        #expect(result.pureAlcoholGram == 0)
        #expect(result.wastedPercent == 0)
        #expect(result.angerLevel == 1)
    }

    @Test("Minimum weight guard prevents division by zero")
    func minimumWeightGuard() {
        let drink = DrinkRecord(drinkType: .beer, volumeML: 350, alcoholPercent: 5.0)
        let profile = UserProfile(bodyWeightKG: 0, trainingPerWeek: 3)
        let result = calculator.calculate(drink, profile, false)
        #expect(result.pureAlcoholGram.isFinite)
        #expect(result.wastedPercent.isFinite)
    }
}
