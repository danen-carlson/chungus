import Foundation
import SwiftData

@Model
final class ExerciseTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var muscleGroup: String
    var sets: Int
    var repRange: String // e.g. "8-12" or "10"
    var targetWeightLbs: Double?
    var restSeconds: Int
    var tips: String?
    var imageUrl: String?
    var alternatives: [String]
    var order: Int

    var workout: WorkoutTemplate?

    init(
        name: String,
        muscleGroup: String,
        sets: Int = 3,
        repRange: String = "8-12",
        targetWeightLbs: Double? = nil,
        restSeconds: Int = 90,
        tips: String? = nil,
        imageUrl: String? = nil,
        alternatives: [String] = [],
        order: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.muscleGroup = muscleGroup
        self.sets = sets
        self.repRange = repRange
        self.targetWeightLbs = targetWeightLbs
        self.restSeconds = restSeconds
        self.tips = tips
        self.imageUrl = imageUrl
        self.alternatives = alternatives
        self.order = order
    }

    /// Display like "4×8-12" or "3×10"
    var setsRepsDisplay: String {
        "\(sets)×\(repRange)"
    }
}
