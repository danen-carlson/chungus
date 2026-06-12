import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var targetMuscles: [String]
    var estimatedDurationMin: Int
    var order: Int

    var plan: WorkoutPlan?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseTemplate.workout)
    var exercises: [ExerciseTemplate]

    init(
        name: String,
        targetMuscles: [String],
        estimatedDurationMin: Int = 60,
        order: Int = 0,
        exercises: [ExerciseTemplate] = []
    ) {
        self.id = UUID()
        self.name = name
        self.targetMuscles = targetMuscles
        self.estimatedDurationMin = estimatedDurationMin
        self.order = order
        self.exercises = exercises
    }

    /// Short display like "Push Day • Chest, Shoulders, Triceps • 8 exercises"
    var summaryLine: String {
        let muscles = targetMuscles.prefix(3).joined(separator: ", ")
        return "\(name) • \(muscles) • \(exercises.count) exercises"
    }
}
