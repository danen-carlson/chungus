import Foundation

enum AppConstants {

    static let appName = "Chungus"
    static let appVersion = "1.0.0"

    // MARK: - Goals

    enum Goal: String, CaseIterable, Identifiable {
        case hypertrophy = "Hypertrophy"
        case strength = "Strength"
        case endurance = "Endurance"
        case mixed = "Mixed"
        case athletic = "Athletic Performance"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .hypertrophy: return "Build muscle size"
            case .strength: return "Increase max strength"
            case .endurance: return "Improve muscular endurance"
            case .mixed: return "Balanced muscle and strength"
            case .athletic: return "Sport-specific performance"
            }
        }
    }

    // MARK: - Equipment

    enum EquipmentAccess: String, CaseIterable, Identifiable {
        case fullGym = "Full Gym"
        case homeGym = "Home Gym"
        case noEquipment = "No Equipment"
        case specific = "Specific Equipment"

        var id: String { rawValue }
    }

    enum EquipmentPreference: String, CaseIterable, Identifiable {
        case freeWeights = "Free weights"
        case machines = "Machines"
        case cableMachines = "Cable machines"
        case bodyweight = "Bodyweight"
        case resistanceBands = "Resistance bands"

        var id: String { rawValue }
    }

    // MARK: - Sex Options

    enum SexOption: String, CaseIterable, Identifiable {
        case male = "Male"
        case female = "Female"
        case preferNotToSay = "Prefer not to say"

        var id: String { rawValue }
    }

    // MARK: - Defaults

    enum Defaults {
        static let restTimerSeconds = 90
        static let weightIncrementLbs = 5.0
        static let lowerBodyIncrementLbs = 10.0
        static let deloadWeekFrequency = 4 // every Nth week
    }
}
