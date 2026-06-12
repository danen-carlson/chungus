import Foundation
import SwiftData

@Model
final class ExerciseSession {
    @Attribute(.unique) var id: UUID
    var templateExerciseId: UUID
    var name: String
    var notes: String?
    var wasSwapped: Bool
    var originalExerciseName: String?
    var order: Int

    var workoutSession: WorkoutSession?

    @Relationship(deleteRule: .cascade)
    var sets: [SetRecord]

    init(
        templateExerciseId: UUID,
        name: String,
        order: Int = 0,
        sets: [SetRecord] = []
    ) {
        self.id = UUID()
        self.templateExerciseId = templateExerciseId
        self.name = name
        self.notes = nil
        self.wasSwapped = false
        self.originalExerciseName = nil
        self.order = order
        self.sets = sets
    }

    /// Best set weight for progression tracking
    var topSetWeight: Double? {
        sets.filter { $0.completed && !$0.isWarmup }
            .compactMap(\.weightLbs)
            .max()
    }

    /// Total reps completed (non-warmup)
    var totalReps: Int {
        sets.filter { $0.completed && !$0.isWarmup }
            .reduce(0) { $0 + $1.reps }
    }
}
