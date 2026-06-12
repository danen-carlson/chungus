import Foundation
import SwiftData

@Model
final class SetRecord {
    @Attribute(.unique) var id: UUID
    var setNumber: Int
    var weightLbs: Double?
    var reps: Int
    var completed: Bool
    var isWarmup: Bool
    var isDropSet: Bool

    var exerciseSession: ExerciseSession?

    init(
        setNumber: Int,
        weightLbs: Double? = nil,
        reps: Int = 0,
        completed: Bool = false,
        isWarmup: Bool = false,
        isDropSet: Bool = false
    ) {
        self.id = UUID()
        self.setNumber = setNumber
        self.weightLbs = weightLbs
        self.reps = reps
        self.completed = completed
        self.isWarmup = isWarmup
        self.isDropSet = isDropSet
    }

    /// Display string like "135 lbs × 10" or "BW × 12"
    var displayString: String {
        let weight = weightLbs.map { "\(Int($0)) lbs" } ?? "BW"
        return "\(weight) × \(reps)"
    }
}
