import Foundation
import Observation

/// Simplified workout model for the Watch companion app
@Observable
@MainActor
final class WatchWorkoutViewModel {

    // Placeholder exercises — will sync from phone via WatchConnectivity in future
    var exercises: [WatchExercise] = []
    var currentExerciseIndex: Int = 0
    var currentSetIndex: Int = 0
    var currentReps: Int = 0
    var isResting: Bool = false
    var restTimeRemaining: Int = 90
    var startTime: Date?
    var elapsed: TimeInterval = 0
    var isWorkoutActive: Bool = false

    struct WatchExercise: Identifiable {
        let id = UUID()
        let name: String
        let sets: Int
        let repRange: String
        let targetWeightLbs: Double?

        var setsRepsDisplay: String {
            "\(sets)×\(repRange)"
        }
    }

    var currentExercise: WatchExercise? {
        guard currentExerciseIndex < exercises.count else { return nil }
        return exercises[currentExerciseIndex]
    }

    var totalExercises: Int {
        exercises.count
    }

    func startWorkout() {
        isWorkoutActive = true
        startTime = Date()

        // Load placeholder exercises
        exercises = [
            WatchExercise(name: "Barbell Bench Press", sets: 4, repRange: "8-10", targetWeightLbs: 135),
            WatchExercise(name: "Overhead Press", sets: 3, repRange: "8-12", targetWeightLbs: 95),
            WatchExercise(name: "Incline Dumbbell Press", sets: 3, repRange: "10-12", targetWeightLbs: 50),
            WatchExercise(name: "Lateral Raises", sets: 3, repRange: "12-15", targetWeightLbs: 20),
            WatchExercise(name: "Tricep Pushdowns", sets: 3, repRange: "10-12", targetWeightLbs: 50),
        ]
    }

    func adjustReps(_ delta: Int) {
        currentReps = max(0, currentReps + delta)
    }

    func completeSet() {
        isResting = true
        restTimeRemaining = 90
        currentReps = 0

        // Move to next set or exercise
        if let ex = currentExercise, currentSetIndex < ex.sets - 1 {
            currentSetIndex += 1
        } else {
            // Move to next exercise
            currentSetIndex = 0
            if currentExerciseIndex < exercises.count - 1 {
                currentExerciseIndex += 1
            }
        }
    }

    func tick() {
        if let start = startTime {
            elapsed = Date().timeIntervalSince(start)
        }

        if isResting {
            if restTimeRemaining > 0 {
                restTimeRemaining -= 1
            } else {
                isResting = false
            }
        }
    }

    func endWorkout() {
        isWorkoutActive = false
        // TODO: Send data back to phone via WatchConnectivity
    }
}
