import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class WorkoutViewModel {

    // Current workout state
    var template: WorkoutTemplate?
    var session: WorkoutSession?
    var currentExerciseIndex: Int = 0
    var isResting = false
    var restTimeRemaining: Int = 0
    var workoutStartTime: Date?
    var workoutElapsed: TimeInterval = 0
    var showSwapSuggestion = false
    var swapSuggestion: WorkoutGenerator.ExerciseSwap?
    var isSwapping = false
    var errorMessage: String?

    private let generator = WorkoutGenerator()

    // MARK: - Computed

    var currentExercise: ExerciseTemplate? {
        guard let template = template,
              currentExerciseIndex < template.exercises.count else { return nil }
        return template.exercises
            .sorted { $0.order < $1.order }[currentExerciseIndex]
    }

    var currentExerciseSession: ExerciseSession? {
        session?.exercises.first { ex in
            currentExercise.map { ex.templateExerciseId == $0.id } ?? false
        }
    }

    var totalExercises: Int {
        template?.exercises.count ?? 0
    }

    var progress: Double {
        guard totalExercises > 0 else { return 0 }
        return Double(currentExerciseIndex) / Double(totalExercises)
    }

    var isLastExercise: Bool {
        currentExerciseIndex >= totalExercises - 1
    }

    // MARK: - Lifecycle

    func startWorkout(template: WorkoutTemplate, context: ModelContext) {
        self.template = template
        self.workoutStartTime = Date()

        // Create session with exercise sessions for each exercise
        let sortedExercises = template.exercises.sorted { $0.order < $1.order }
        let exerciseSessions = sortedExercises.enumerated().map { (index, ex) in
            let exSession = ExerciseSession(
                templateExerciseId: ex.id,
                name: ex.name,
                order: index
            )

            // Pre-populate sets
            for setNum in 1...ex.sets {
                let set = SetRecord(
                    setNumber: setNum,
                    weightLbs: ex.targetWeightLbs,
                    reps: 0,
                    completed: false
                )
                exSession.sets.append(set)
            }

            return exSession
        }

        let workoutSession = WorkoutSession(
            templateId: template.id,
            workoutName: template.name,
            exercises: exerciseSessions
        )

        self.session = workoutSession
        context.insert(workoutSession)
    }

    // MARK: - Set Tracking

    func updateSet(setIndex: Int, weight: Double?, reps: Int, completed: Bool) {
        guard let exSession = currentExerciseSession,
              setIndex < exSession.sets.count else { return }

        let set = exSession.sets[setIndex]
        set.weightLbs = weight
        set.reps = reps
        set.completed = completed

        if completed {
            startRestTimer()
        }
    }

    func addSet() {
        guard let exSession = currentExerciseSession else { return }
        let nextNumber = (exSession.sets.map(\.setNumber).max() ?? 0) + 1

        // Default to same weight as last completed set
        let lastWeight = exSession.sets
            .filter { $0.completed }
            .last?
            .weightLbs

        let newSet = SetRecord(
            setNumber: nextNumber,
            weightLbs: lastWeight,
            reps: 0,
            completed: false
        )
        exSession.sets.append(newSet)
    }

    // MARK: - Navigation

    func nextExercise() {
        if currentExerciseIndex < totalExercises - 1 {
            currentExerciseIndex += 1
        }
    }

    func previousExercise() {
        if currentExerciseIndex > 0 {
            currentExerciseIndex -= 1
        }
    }

    func jumpToExercise(index: Int) {
        guard index >= 0 && index < totalExercises else { return }
        currentExerciseIndex = index
    }

    // MARK: - Rest Timer

    private func startRestTimer() {
        let restSeconds = currentExercise?.restSeconds ?? AppConstants.Defaults.restTimerSeconds
        restTimeRemaining = restSeconds
        isResting = true
    }

    func tickRestTimer() {
        guard isResting else { return }
        if restTimeRemaining > 0 {
            restTimeRemaining -= 1
        } else {
            isResting = false
        }
    }

    func skipRest() {
        isResting = false
        restTimeRemaining = 0
    }

    // MARK: - Exercise Swap

    func requestSwap(profileSummary: String, equipmentAccess: String) async {
        guard let exercise = currentExercise,
              let template = template else { return }

        isSwapping = true
        errorMessage = nil

        do {
            let suggestion = try await generator.suggestSwap(
                exerciseName: exercise.name,
                muscleGroup: exercise.muscleGroup,
                exerciseSets: exercise.sets,
                exerciseRepRange: exercise.repRange,
                exerciseRestSeconds: exercise.restSeconds,
                workoutName: template.name,
                targetMuscles: template.targetMuscles,
                profileSummary: profileSummary,
                equipmentAccess: equipmentAccess
            )
            swapSuggestion = suggestion
            showSwapSuggestion = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isSwapping = false
    }

    func acceptSwap() {
        guard let suggestion = swapSuggestion,
              let exSession = currentExerciseSession,
              let exercise = currentExercise else { return }

        exSession.wasSwapped = true
        exSession.originalExerciseName = exercise.name
        exSession.name = suggestion.name

        // Update template exercise too for this session context
        exercise.name = suggestion.name
        exercise.muscleGroup = suggestion.muscleGroup
        exercise.sets = suggestion.sets
        exercise.repRange = suggestion.repRange
        exercise.tips = suggestion.tips

        showSwapSuggestion = false
        swapSuggestion = nil
    }

    func rejectSwap() {
        showSwapSuggestion = false
        swapSuggestion = nil
    }

    // MARK: - Complete Workout

    func completeWorkout(context: ModelContext) async throws {
        guard let session = session else { return }
        session.completedAt = Date()

        try context.save()

        // Write to HealthKit
        try? await HealthKitService.shared.saveWorkout(session)

        // Trigger plan regeneration for this workout type in the background
        // (handled by the Dashboard when it reloads)
    }
}
