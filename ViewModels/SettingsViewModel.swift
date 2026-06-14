import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class SettingsViewModel {

    var profile: UserProfile?
    var isSaving = false
    var saveMessage: String?

    // Editable profile fields
    var editAge: Int = 25
    var editWeightLbs: Double = 170
    var editDaysAvailable: Int = 4
    var editGoal: String = "Hypertrophy"
    var editEquipmentAccess: String = "Full Gym"
    var editAdditionalNotes: String = ""

    func loadProfile(context: ModelContext) {
        var descriptor = FetchDescriptor<UserProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let profile = try? context.fetch(descriptor).first {
            self.profile = profile
            editAge = profile.age
            editWeightLbs = profile.weightLbs
            editDaysAvailable = profile.daysAvailable
            editGoal = profile.goal
            editEquipmentAccess = profile.equipmentAccess
            editAdditionalNotes = profile.additionalNotes
        }
    }

    func saveProfile(context: ModelContext) {
        guard let profile = profile else { return }
        isSaving = true

        profile.age = editAge
        profile.weightLbs = editWeightLbs
        profile.daysAvailable = editDaysAvailable
        profile.goal = editGoal
        profile.equipmentAccess = editEquipmentAccess
        profile.additionalNotes = editAdditionalNotes
        profile.updatedAt = Date()

        do {
            try context.save()
            saveMessage = "Profile saved!"
        } catch {
            saveMessage = "Error: \(error.localizedDescription)"
        }

        isSaving = false
    }
}
