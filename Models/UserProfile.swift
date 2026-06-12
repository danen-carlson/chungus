import Foundation
import SwiftData

@Model
final class UserProfile {
    var age: Int
    var sex: String
    var heightFeet: Int
    var heightInches: Int
    var weightLbs: Double
    var timeConstraintMin: Int?
    var daysAvailable: Int
    var sportsPlayed: [String]
    var yearsTraining: Double
    var specificExercises: [String]
    var goal: String
    var equipmentAccess: String
    var equipmentPreference: [String]
    var additionalNotes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        age: Int,
        sex: String = "Prefer not to say",
        heightFeet: Int = 5,
        heightInches: Int = 10,
        weightLbs: Double = 170,
        timeConstraintMin: Int? = nil,
        daysAvailable: Int = 4,
        sportsPlayed: [String] = [],
        yearsTraining: Double = 0,
        specificExercises: [String] = [],
        goal: String = "Hypertrophy",
        equipmentAccess: String = "Full Gym",
        equipmentPreference: [String] = ["Free weights"],
        additionalNotes: String = ""
    ) {
        self.age = age
        self.sex = sex
        self.heightFeet = heightFeet
        self.heightInches = heightInches
        self.weightLbs = weightLbs
        self.timeConstraintMin = timeConstraintMin
        self.daysAvailable = daysAvailable
        self.sportsPlayed = sportsPlayed
        self.yearsTraining = yearsTraining
        self.specificExercises = specificExercises
        self.goal = goal
        self.equipmentAccess = equipmentAccess
        self.equipmentPreference = equipmentPreference
        self.additionalNotes = additionalNotes
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Formatted height string, e.g. "5'10\""
    var heightString: String {
        "\(heightFeet)'\(heightInches)\""
    }

    /// Build a natural-language summary for Gemini prompts
    var promptSummary: String {
        var parts: [String] = []
        parts.append("\(age) year old \(sex.lowercased())")
        parts.append("\(heightString), \(String(format: "%.0f", weightLbs)) lbs")
        parts.append("Goal: \(goal)")
        parts.append("Training experience: \(yearsTraining) years")
        parts.append("Available \(daysAvailable) days/week")
        parts.append("Equipment: \(equipmentAccess)")
        if !equipmentPreference.isEmpty {
            parts.append("Prefers: \(equipmentPreference.joined(separator: ", "))")
        }
        if !sportsPlayed.isEmpty {
            parts.append("Sports: \(sportsPlayed.joined(separator: ", "))")
        }
        if let mins = timeConstraintMin {
            parts.append("Time limit: \(mins) min per workout")
        }
        if !specificExercises.isEmpty {
            parts.append("Requested exercises: \(specificExercises.joined(separator: ", "))")
        }
        if !additionalNotes.isEmpty {
            parts.append("Notes: \(additionalNotes)")
        }
        return parts.joined(separator: ". ")
    }
}
