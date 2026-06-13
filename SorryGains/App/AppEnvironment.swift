import Foundation
import SwiftData

@MainActor
@Observable
final class AppEnvironment {
    let drinkRepository: any DrinkRecordRepository
    let calculator: ApologyCalculator
    let authService: AuthService
    let trainingDataService: TrainingDataService

    init(
        drinkRepository: any DrinkRecordRepository,
        calculator: ApologyCalculator = .live,
        authService: AuthService = AuthService(),
        trainingDataService: TrainingDataService = TrainingDataService()
    ) {
        self.drinkRepository = drinkRepository
        self.calculator = calculator
        self.authService = authService
        self.trainingDataService = trainingDataService
    }
}
