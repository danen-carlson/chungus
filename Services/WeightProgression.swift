import Foundation

/// Handles weight progression logic and 1RM estimation
struct WeightProgression {

    /// Epley formula: estimated 1RM = weight × (1 + reps/30)
    static func estimatedOneRepMax(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    /// Suggest next weight based on performance
    /// - If user hit top of rep range on all sets → increase weight
    /// - If user struggled (below range) → keep or decrease
    /// - Standard increment: 5 lbs for upper body, 10 lbs for lower body
    static func suggestNextWeight(
        currentWeight: Double,
        reps: [Int],
        targetRepRange: String,
        isLowerBody: Bool
    ) -> Double {
        let range = parseRepRange(targetRepRange)
        let increment = isLowerBody ? 10.0 : 5.0

        let allAtTop = reps.allSatisfy { $0 >= range.upper }
        let allInRange = reps.allSatisfy { $0 >= range.lower && $0 <= range.upper }
        let anyBelowRange = reps.contains { $0 < range.lower }

        if allAtTop {
            // Dominated — increase weight
            return currentWeight + increment
        } else if allInRange {
            // Solid performance — small increase or hold
            return currentWeight + (increment / 2.0)
        } else if anyBelowRange {
            // Struggling — keep same or slight decrease
            return max(currentWeight - (increment / 2.0), 0)
        } else {
            // Mixed — keep the same
            return currentWeight
        }
    }

    /// Parse "8-12" into (8, 12) or "10" into (10, 10)
    static func parseRepRange(_ range: String) -> (lower: Int, upper: Int) {
        let parts = range.split(separator: "-").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        if parts.count == 2 {
            return (parts[0], parts[1])
        } else if let single = parts.first {
            return (single, single)
        }
        return (8, 12) // safe default
    }

    /// Detect plateau: no weight increase in N sessions for same exercise
    static func isPlateau(recentWeights: [Double], threshold: Int = 3) -> Bool {
        guard recentWeights.count >= threshold else { return false }
        let lastN = Array(recentWeights.suffix(threshold))
        guard let first = lastN.first else { return false }
        return lastN.allSatisfy { abs($0 - first) < 2.5 } // within 2.5 lbs = plateau
    }

    /// Get the last used weight for an exercise from session history
    static func lastWeightFor(
        exerciseName: String,
        from sessions: [WorkoutSession]
    ) -> Double? {
        for session in sessions.reversed() {
            if let ex = session.exercises.first(where: { $0.name == exerciseName }) {
                return ex.topSetWeight
            }
        }
        return nil
    }
}
