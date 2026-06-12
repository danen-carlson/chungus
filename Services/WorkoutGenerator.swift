import Foundation

/// Generates workout plans and exercise suggestions via Gemini
struct WorkoutGenerator {

    private let gemini = GeminiService.shared

    // MARK: - Response Models (for JSON decoding)

    struct GeneratedPlan: Decodable {
        let splitType: String
        let workouts: [GeneratedWorkout]
    }

    struct GeneratedWorkout: Decodable {
        let name: String
        let targetMuscles: [String]
        let estimatedDurationMin: Int
        let exercises: [GeneratedExercise]
    }

    struct GeneratedExercise: Decodable {
        let name: String
        let muscleGroup: String
        let sets: Int
        let repRange: String
        let targetWeightLbs: Double?
        let restSeconds: Int
        let tips: String?
        let alternatives: [String]?
    }

    struct ExerciseSwap: Decodable {
        let name: String
        let muscleGroup: String
        let sets: Int
        let repRange: String
        let targetWeightLbs: Double?
        let restSeconds: Int
        let tips: String?
        let reason: String
    }

    // MARK: - Initial Plan Generation

    func generateInitialPlan(for profile: UserProfile) async throws -> GeneratedPlan {
        let prompt = """
        You are an expert personal trainer. Generate a complete workout plan for this user:

        \(profile.promptSummary)

        Create a workout split that best fits their profile, goals, and available days.
        Choose the optimal split type (PPL, Upper/Lower, Full Body, Bro Split, etc.) based on their days available and goals.

        For each exercise:
        - Use rep ranges (e.g. "8-12") not fixed reps
        - Suggest starting weights based on their experience level (nil/0 for beginners who should find their weight)
        - Include rest periods appropriate for the goal (hypertrophy: 60-90s, strength: 2-3min)
        - Add brief form cues or tips
        - Provide 2-3 alternative exercises for swaps

        Return a JSON object with this structure:
        {
            "splitType": "PPL",
            "workouts": [
                {
                    "name": "Push Day",
                    "targetMuscles": ["chest", "shoulders", "triceps"],
                    "estimatedDurationMin": 60,
                    "exercises": [
                        {
                            "name": "Barbell Bench Press",
                            "muscleGroup": "chest",
                            "sets": 4,
                            "repRange": "8-10",
                            "targetWeightLbs": 135,
                            "restSeconds": 90,
                            "tips": "Keep shoulder blades retracted, control the negative",
                            "alternatives": ["Dumbbell Bench Press", "Machine Chest Press"]
                        }
                    ]
                }
            ]
        }
        """

        return try await gemini.generateJSON(prompt: prompt, responseType: GeneratedPlan.self)
    }

    // MARK: - Regenerate Next Workout

    func regenerateWorkout(
        currentTemplate: WorkoutTemplate,
        recentSessions: [WorkoutSession],
        profile: UserProfile
    ) async throws -> GeneratedWorkout {
        let sessionSummaries = recentSessions.map { session -> String in
            let exercises = session.exercises.map { ex -> String in
                let setsSummary = ex.sets
                    .filter { $0.completed }
                    .map { "\($0.weightLbs.map { "\($0)lbs" } ?? "BW")×\($0.reps)" }
                    .joined(separator: ", ")
                return "\(ex.name): \(setsSummary)"
            }.joined(separator: "\n")
            let date = session.startedAt.formatted(date: .abbreviated, time: .omitted)
            return "Session \(date):\n\(exercises)\nNotes: \(session.overallNotes ?? "none")"
        }.joined(separator: "\n\n")

        let prompt = """
        You are an expert personal trainer. Generate the NEXT version of this workout:

        User profile: \(profile.promptSummary)

        Previous workout: \(currentTemplate.name)
        Target muscles: \(currentTemplate.targetMuscles.joined(separator: ", "))

        Recent performance on this workout type:
        \(sessionSummaries)

        Based on their performance, adjust:
        - Weights (increase if sets were completed easily, decrease if struggling)
        - Reps/sets (progressive overload principles)
        - Exercise variety (rotate exercises every few weeks to prevent staleness)
        - Consider deload if this is approximately every 4th week

        Return the same JSON format as a single workout.
        """

        return try await gemini.generateJSON(prompt: prompt, responseType: GeneratedWorkout.self)
    }

    // MARK: - Exercise Swap

    func suggestSwap(
        for exercise: ExerciseTemplate,
        in workout: WorkoutTemplate,
        profile: UserProfile
    ) async throws -> ExerciseSwap {
        let prompt = """
        You are an expert personal trainer. Suggest an alternative exercise.

        User profile: \(profile.promptSummary)

        Current exercise: \(exercise.name) (\(exercise.muscleGroup))
        Workout context: \(workout.name) targeting \(workout.targetMuscles.joined(separator: ", "))

        Suggest ONE alternative exercise that:
        - Targets the same muscle group (\(exercise.muscleGroup))
        - Fits the user's equipment (\(profile.equipmentAccess))
        - Maintains similar difficulty level
        - Respects any injuries/limitations mentioned

        Return JSON:
        {
            "name": "Exercise Name",
            "muscleGroup": "same group",
            "sets": \(exercise.sets),
            "repRange": "\(exercise.repRange)",
            "targetWeightLbs": null,
            "restSeconds": \(exercise.restSeconds),
            "tips": "Brief form cue",
            "reason": "Why this is a good swap"
        }
        """

        return try await gemini.generateJSON(prompt: prompt, responseType: ExerciseSwap.self)
    }
}
