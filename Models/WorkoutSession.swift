import Foundation
import SwiftData

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var templateId: UUID
    var workoutName: String
    var startedAt: Date
    var completedAt: Date?
    var overallNotes: String?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSession.workoutSession)
    var exercises: [ExerciseSession]

    init(
        templateId: UUID,
        workoutName: String,
        exercises: [ExerciseSession] = []
    ) {
        self.id = UUID()
        self.templateId = templateId
        self.workoutName = workoutName
        self.startedAt = Date()
        self.completedAt = nil
        self.overallNotes = nil
        self.exercises = exercises
    }

    var isComplete: Bool {
        completedAt != nil
    }

    var durationMinutes: Int? {
        guard let end = completedAt else { return nil }
        return Int(end.timeIntervalSince(startedAt) / 60)
    }

    /// Total volume (weight × reps) across all completed sets
    var totalVolumeLbs: Double {
        exercises.flatMap { $0.sets }
            .filter { $0.completed && !$0.isWarmup }
            .compactMap { set -> Double? in
                guard let w = set.weightLbs else { return nil }
                return w * Double(set.reps)
            }
            .reduce(0, +)
    }
}
