import Foundation
import SwiftData

@Model
final class WorkoutPlan {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var splitType: String
    var weekNumber: Int
    var isActive: Bool

    @Relationship(deleteRule: .cascade, inverse: \WorkoutTemplate.plan)
    var workouts: [WorkoutTemplate]

    init(
        splitType: String,
        weekNumber: Int = 1,
        workouts: [WorkoutTemplate] = []
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.splitType = splitType
        self.weekNumber = weekNumber
        self.isActive = true
        self.workouts = workouts
    }
}
