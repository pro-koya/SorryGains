import XCTest
@testable import SorryGains

/// Muscle360 統合論理モデルのユニットテスト。
///
/// 仕様: Projects/Muscle360/2026-05-18-types-and-rpc-spec.md §7.1
final class UnifiedTrainingSnapshotTests: XCTestCase {

    // MARK: - Helpers

    private func makeLiftlyPayload(
        volumeKG: Double = 1000,
        intensity: IntensityLevel? = .medium,
        bodyParts: [String] = ["chest", "shoulders"]
    ) -> LiftlyTrainingPayload {
        LiftlyTrainingPayload(
            sessionCount: 1,
            trainedBodyParts: bodyParts,
            exerciseCount: 4,
            totalSets: 12,
            totalReps: 80,
            totalVolumeKG: volumeKG,
            intensityLevel: intensity
        )
    }

    private func makeForgePayload(
        sessionTypes: [String] = ["crossfit_wod"],
        intensity: IntensityLevel? = .high,
        averageRPE: Double? = 8.5,
        isPR: Bool = false,
        benchmarkIDs: [String] = []
    ) -> ForgeTrainingPayload {
        ForgeTrainingPayload(
            sessionCount: 1,
            sessionTypes: sessionTypes,
            totalDurationSeconds: 1200,
            averageRPE: averageRPE,
            isPRSession: isPR,
            benchmarkIDs: benchmarkIDs,
            intensityLevel: intensity,
            movementsSummary: []
        )
    }

    private func entry(
        from liftly: LiftlyTrainingPayload,
        startedAt: Date? = nil,
        endedAt: Date? = nil
    ) -> TrainingEntry {
        .fromLiftly(payload: liftly, startedAt: startedAt, endedAt: endedAt)
    }

    private func entry(
        from forge: ForgeTrainingPayload,
        startedAt: Date? = nil,
        endedAt: Date? = nil
    ) -> TrainingEntry {
        .fromForge(payload: forge, startedAt: startedAt, endedAt: endedAt)
    }

    // MARK: - aggregatedIntensity (max rule)

    func testAggregatedIntensity_singleHigh() {
        let snapshot = UnifiedTrainingSnapshot(
            userId: "u1",
            trainingDate: .now,
            entries: [entry(from: makeForgePayload(intensity: .high))]
        )
        XCTAssertEqual(snapshot.aggregatedIntensity, .high)
    }

    func testAggregatedIntensity_singleMedium() {
        let snapshot = UnifiedTrainingSnapshot(
            userId: "u1",
            trainingDate: .now,
            entries: [entry(from: makeLiftlyPayload(intensity: .medium))]
        )
        XCTAssertEqual(snapshot.aggregatedIntensity, .medium)
    }

    func testAggregatedIntensity_singleLow() {
        let snapshot = UnifiedTrainingSnapshot(
            userId: "u1",
            trainingDate: .now,
            entries: [entry(from: makeLiftlyPayload(intensity: .low))]
        )
        XCTAssertEqual(snapshot.aggregatedIntensity, .low)
    }

    func testAggregatedIntensity_mixedHighMedium_returnsHigh() {
        let snapshot = UnifiedTrainingSnapshot(
            userId: "u1",
            trainingDate: .now,
            entries: [
                entry(from: makeLiftlyPayload(intensity: .medium)),
                entry(from: makeForgePayload(intensity: .high))
            ]
        )
        XCTAssertEqual(snapshot.aggregatedIntensity, .high)
    }

    func testAggregatedIntensity_mixedLowMedium_returnsMedium() {
        let snapshot = UnifiedTrainingSnapshot(
            userId: "u1",
            trainingDate: .now,
            entries: [
                entry(from: makeLiftlyPayload(intensity: .low)),
                entry(from: makeForgePayload(intensity: .medium))
            ]
        )
        XCTAssertEqual(snapshot.aggregatedIntensity, .medium)
    }

    func testAggregatedIntensity_allNil_returnsNil() {
        let snapshot = UnifiedTrainingSnapshot(
            userId: "u1",
            trainingDate: .now,
            entries: [entry(from: makeLiftlyPayload(intensity: nil))]
        )
        XCTAssertNil(snapshot.aggregatedIntensity)
    }

    // MARK: - aggregatedBodyParts

    func testAggregatedBodyParts_liftlyOnly() {
        let snapshot = UnifiedTrainingSnapshot(
            userId: "u1",
            trainingDate: .now,
            entries: [entry(from: makeLiftlyPayload(bodyParts: ["chest", "back"]))]
        )
        XCTAssertEqual(snapshot.aggregatedBodyParts, ["chest", "back"])
    }

    func testAggregatedBodyParts_forgeOnly_crossfit() {
        let snapshot = UnifiedTrainingSnapshot(
            userId: "u1",
            trainingDate: .now,
            entries: [entry(from: makeForgePayload(sessionTypes: ["crossfit_wod"]))]
        )
        XCTAssertEqual(snapshot.aggregatedBodyParts, ["crossfit"])
    }

    func testAggregatedBodyParts_forgeOnly_hyrox() {
        let snapshot = UnifiedTrainingSnapshot(
            userId: "u1",
            trainingDate: .now,
            entries: [entry(from: makeForgePayload(sessionTypes: ["hyrox_race"]))]
        )
        XCTAssertEqual(snapshot.aggregatedBodyParts, ["hyrox"])
    }

    func testAggregatedBodyParts_both_dedupAndOrder() {
        let snapshot = UnifiedTrainingSnapshot(
            userId: "u1",
            trainingDate: .now,
            entries: [
                entry(from: makeLiftlyPayload(bodyParts: ["legs"])),
                entry(from: makeForgePayload(sessionTypes: ["hyrox_simulation"]))
            ]
        )
        // Liftly 由来が先、Forge 由来が後
        XCTAssertEqual(snapshot.aggregatedBodyParts, ["legs", "hyrox"])
    }

    func testAggregatedBodyParts_empty() {
        let snapshot = UnifiedTrainingSnapshot.empty(for: .now)
        XCTAssertEqual(snapshot.aggregatedBodyParts, [])
    }

    // MARK: - hoursSinceTraining

    func testHoursSinceTraining_afterTwoHours() {
        let now = Date()
        let twoHoursAgo = now.addingTimeInterval(-7200)
        let snapshot = UnifiedTrainingSnapshot(
            userId: "u1",
            trainingDate: now,
            entries: [entry(from: makeLiftlyPayload(), endedAt: twoHoursAgo)]
        )
        let hours = snapshot.hoursSinceTraining(at: now)
        XCTAssertEqual(hours ?? 0, 2.0, accuracy: 0.01)
    }

    func testHoursSinceTraining_noEndedAt() {
        let snapshot = UnifiedTrainingSnapshot(
            userId: "u1",
            trainingDate: .now,
            entries: [entry(from: makeLiftlyPayload(), endedAt: nil)]
        )
        XCTAssertNil(snapshot.hoursSinceTraining())
    }

    func testHoursSinceTraining_returnsLatestEnd() {
        let now = Date()
        let snapshot = UnifiedTrainingSnapshot(
            userId: "u1",
            trainingDate: now,
            entries: [
                entry(from: makeLiftlyPayload(), endedAt: now.addingTimeInterval(-7200)),
                entry(from: makeForgePayload(), endedAt: now.addingTimeInterval(-3600))
            ]
        )
        let hours = snapshot.hoursSinceTraining(at: now)
        XCTAssertEqual(hours ?? 0, 1.0, accuracy: 0.01) // 1時間前（より新しい方）
    }

    // MARK: - sources / trainedDomains

    func testSources_liftlyOnly() {
        let snapshot = UnifiedTrainingSnapshot(
            userId: "u1",
            trainingDate: .now,
            entries: [entry(from: makeLiftlyPayload())]
        )
        XCTAssertEqual(snapshot.sources, [.liftly])
    }

    func testSources_both() {
        let snapshot = UnifiedTrainingSnapshot(
            userId: "u1",
            trainingDate: .now,
            entries: [
                entry(from: makeLiftlyPayload()),
                entry(from: makeForgePayload())
            ]
        )
        XCTAssertEqual(snapshot.sources, [.liftly, .forge])
    }

    func testTrainedDomains_forgeCrossfitAndHyrox_addsMixed() {
        let payload = makeForgePayload(sessionTypes: ["crossfit_wod", "hyrox_simulation"])
        let snapshot = UnifiedTrainingSnapshot(
            userId: "u1",
            trainingDate: .now,
            entries: [entry(from: payload)]
        )
        XCTAssertTrue(snapshot.trainedDomains.contains(.crossfit))
        XCTAssertTrue(snapshot.trainedDomains.contains(.hyrox))
        XCTAssertTrue(snapshot.trainedDomains.contains(.mixed),
                      "複数ドメインを跨ぐ場合は .mixed も含むべき")
    }

    func testTrainedDomains_liftlyCardio() {
        let payload = makeLiftlyPayload(bodyParts: ["cardio"])
        let snapshot = UnifiedTrainingSnapshot(
            userId: "u1",
            trainingDate: .now,
            entries: [entry(from: payload)]
        )
        XCTAssertTrue(snapshot.trainedDomains.contains(.strength))
        XCTAssertTrue(snapshot.trainedDomains.contains(.cardio))
    }

    // MARK: - SageContext (new init)

    func testSageContext_unifiedSnapshot_liftlyOnly_setsCorrectFields() {
        let snapshot = UnifiedTrainingSnapshot(
            userId: "u1",
            trainingDate: .now,
            entries: [entry(from: makeLiftlyPayload(volumeKG: 5000))]
        )
        let context = SageContext(
            todayDrinkCount: 1,
            todayTotalAlcoholGram: 20,
            todayDidTrain: true,
            weekDrinkCount: 3,
            weekTrainingDays: 4,
            consecutiveDrinkingDays: 1,
            trainingGoal: .maintain,
            latestAngerLevel: nil,
            unifiedSnapshot: snapshot
        )
        XCTAssertTrue(context.isLiftlyLinked)
        XCTAssertFalse(context.isForgeLinked)
        XCTAssertEqual(context.trainingVolumeKG, 5000)
        XCTAssertNil(context.forgeAverageRPE)
        XCTAssertFalse(context.forgeIsPRDay)
    }

    func testSageContext_unifiedSnapshot_forgePR_propagatesIsPRDay() {
        let snapshot = UnifiedTrainingSnapshot(
            userId: "u1",
            trainingDate: .now,
            entries: [entry(from: makeForgePayload(
                averageRPE: 9.0,
                isPR: true,
                benchmarkIDs: ["fran"]
            ))]
        )
        let context = SageContext(
            todayDrinkCount: 0,
            todayTotalAlcoholGram: 0,
            todayDidTrain: true,
            weekDrinkCount: 0,
            weekTrainingDays: 5,
            consecutiveDrinkingDays: 0,
            trainingGoal: .bulk,
            latestAngerLevel: nil,
            unifiedSnapshot: snapshot
        )
        XCTAssertTrue(context.isForgeLinked)
        XCTAssertEqual(context.forgeAverageRPE ?? 0, 9.0, accuracy: 0.01)
        XCTAssertTrue(context.forgeIsPRDay)
        XCTAssertEqual(context.forgeBenchmarkIDs, ["fran"])
    }

    func testSageContext_unifiedSnapshot_both_aggregatesIntensity() {
        let snapshot = UnifiedTrainingSnapshot(
            userId: "u1",
            trainingDate: .now,
            entries: [
                entry(from: makeLiftlyPayload(intensity: .low)),
                entry(from: makeForgePayload(intensity: .high))
            ]
        )
        let context = SageContext(
            todayDrinkCount: 0,
            todayTotalAlcoholGram: 0,
            todayDidTrain: true,
            weekDrinkCount: 0,
            weekTrainingDays: 3,
            consecutiveDrinkingDays: 0,
            trainingGoal: .maintain,
            latestAngerLevel: nil,
            unifiedSnapshot: snapshot
        )
        XCTAssertEqual(context.trainingIntensity, IntensityLevel.high)
        XCTAssertTrue(context.linkedSources.contains(.liftly))
        XCTAssertTrue(context.linkedSources.contains(.forge))
    }

    func testSageContext_unifiedSnapshot_nil_setsEmptyDefaults() {
        let context = SageContext(
            todayDrinkCount: 2,
            todayTotalAlcoholGram: 30,
            todayDidTrain: false,
            weekDrinkCount: 3,
            weekTrainingDays: 0,
            consecutiveDrinkingDays: 2,
            trainingGoal: .maintain,
            latestAngerLevel: nil,
            unifiedSnapshot: nil
        )
        XCTAssertFalse(context.hasAnyLinkedSource)
        XCTAssertFalse(context.isLiftlyLinked)
        XCTAssertFalse(context.isForgeLinked)
        XCTAssertNil(context.trainedBodyParts)
        XCTAssertNil(context.trainingIntensity)
        XCTAssertTrue(context.forgeBenchmarkIDs.isEmpty)
    }

    // MARK: - SageContext (legacy init backward compat)

    @available(*, deprecated)
    func testSageContext_legacyInit_fromTrainingSnapshot_stillWorks() {
        let snap = TrainingSnapshot(from: [
            "user_id": "u1",
            "training_date": "2026-05-18",
            "session_count": 1,
            "exercise_count": 4,
            "total_sets": 12,
            "total_reps": 80,
            "total_volume_kg": 1500.0,
            "trained_body_parts": ["chest", "shoulders"],
            "intensity_level": "medium"
        ])
        let context = SageContext(
            todayDrinkCount: 1,
            todayTotalAlcoholGram: 15,
            todayDidTrain: true,
            weekDrinkCount: 2,
            weekTrainingDays: 3,
            consecutiveDrinkingDays: 1,
            trainingGoal: .bulk,
            latestAngerLevel: nil,
            trainingSnapshot: snap
        )
        XCTAssertTrue(context.isLiftlyLinked)
        XCTAssertEqual(context.trainingIntensity, IntensityLevel.medium)
        XCTAssertEqual(context.trainingVolumeKG, 1500)
        XCTAssertEqual(context.trainedBodyParts, ["chest", "shoulders"])
    }
}
