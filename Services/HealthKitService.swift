import Foundation
import HealthKit

/// Manages HealthKit authorization and writing workout data
@MainActor
final class HealthKitService: ObservableObject {

    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()

    @Published var isAuthorized = false

    private init() {}

    /// Request permission to write workout data
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        let typesToShare: Set<HKSampleType> = [
            HKQuantityType.workoutType()
        ]

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.workoutType(),
            HKObjectType.activitySummaryType()
        ]

        try await healthStore.requestAuthorization(
            toShare: typesToShare,
            read: typesToRead
        )

        isAuthorized = true
    }

    /// Write a completed workout session to Apple Health
    func saveWorkout(_ session: WorkoutSession) async throws {
        guard let completedAt = session.completedAt else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining

        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: .local()
        )

        try await builder.beginCollection(withStart: session.startedAt)

        // Add total energy expenditure if we estimate it
        let duration = completedAt.timeIntervalSince(session.startedAt)
        let estimatedCalories = estimateCalories(
            duration: duration,
            totalVolume: session.totalVolumeLbs
        )

        let energyBurned = HKQuantity(
            unit: .kilocalorie(),
            doubleValue: estimatedCalories
        )
        try await builder.add([
            HKQuantitySample(
                type: HKQuantityType(.activeEnergyBurned),
                quantity: energyBurned,
                start: session.startedAt,
                end: completedAt
            )
        ])

        try await builder.endCollection(withEnd: completedAt)
        try await builder.finishWorkout()
    }

    /// Rough calorie estimate for strength training
    /// ~6 kcal/min base + bonus for volume
    private func estimateCalories(duration: TimeInterval, totalVolume: Double) -> Double {
        let minutes = duration / 60.0
        let baseCalories = minutes * 6.0
        let volumeBonus = totalVolume / 1000.0 * 50.0 // rough estimate
        return baseCalories + volumeBonus
    }

    enum HealthKitError: LocalizedError {
        case notAvailable
        case authorizationDenied

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "HealthKit is not available on this device."
            case .authorizationDenied:
                return "HealthKit access was denied. Enable it in Settings."
            }
        }
    }
}
