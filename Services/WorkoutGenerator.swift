import Foundation

/// Generates workout plans and exercise suggestions via OpenClaw Gateway (RAG + Venice AI)
struct WorkoutGenerator {

    private let gateway = GatewayWorkoutService.shared

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

    func generateInitialPlan(profileSummary: String) async throws -> GeneratedPlan {
        // The Gateway will automatically trigger the fitness-rag skill based on this prompt
        let prompt = """
        Create a workout plan. Profile: \(profileSummary)

        Rules:
        - Choose the best split for their days/goal
        - 5-6 exercises per workout max
        - Rep ranges like "8-12"
        - Weights: null for beginners, estimated for experienced
        - Rest: 60-90s hypertrophy, 120-180s strength
        - Short tip per exercise
        - CRITICAL: User has a history of bilateral shoulder dislocations (left shoulder recovering). NO behind-the-neck movements, deep dips, or heavy overhead barbell work. ALWAYS include scapular/rotator cuff prehab.

        Return JSON exactly matching this schema:
        {"splitType":"string","workouts":[{"name":"string","targetMuscles":["string"],"estimatedDurationMin":60,"exercises":[{"name":"string","muscleGroup":"string","sets":3,"repRange":"8-12","targetWeightLbs":null,"restSeconds":90,"tips":"string","alternatives":[]}]}]}
        """

        // Retry up to 3 times with increasing delays
        var lastError: Error?
        for attempt in 1...3 {
            do {
                print("[Chungus] Plan generation attempt \(attempt)/3 via Gateway...")
                let rawJSON = try await gateway.generateWorkoutJSON(prompt: prompt, timeout: 45.0)
                
                guard let jsonData = rawJSON.data(using: .utf8) else {
                    throw NSError(domain: "WorkoutGenerator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode response to UTF-8"])
                }
                
                let decoder = JSONDecoder()
                return try decoder.decode(GeneratedPlan.self, from: jsonData)
            } catch {
                lastError = error
                if attempt < 3 {
                    let delay = Double(attempt) * 3.0
                    print("[Chungus] Attempt \(attempt) failed, waiting \(delay)s before retry...")
                    try? await Task.sleep(for: .seconds(delay))
                }
            }
        }
        throw lastError!
    }

    // MARK: - Regenerate Next Workout

    func regenerateWorkout(
        workoutName: String,
        targetMuscles: [String],
        sessionSummaries: String,
        profileSummary: String
    ) async throws -> GeneratedWorkout {
        let prompt = """
        You are an expert personal trainer. Generate the NEXT version of this workout:

        User profile: \(profileSummary)

        Previous workout: \(workoutName)
        Target muscles: \(targetMuscles.joined(separator: ", "))

        Recent performance on this workout type:
        \(sessionSummaries)

        Based on their performance, adjust:
        - Weights (increase if sets were completed easily, decrease if struggling)
        - Reps/sets (progressive overload principles)
        - Exercise variety (rotate exercises every few weeks to prevent staleness)
        - Consider deload if this is approximately every 4th week
        - CRITICAL: User has a history of bilateral shoulder dislocations (left shoulder recovering). NO behind-the-neck movements, deep dips, or heavy overhead barbell work. ALWAYS include scapular/rotator cuff prehab.

        Return the same JSON format as a single workout.
        """

        let rawJSON = try await gateway.generateWorkoutJSON(prompt: prompt, timeout: 45.0)
        guard let jsonData = rawJSON.data(using: .utf8) else {
            throw NSError(domain: "WorkoutGenerator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode response to UTF-8"])
        }
        let decoder = JSONDecoder()
        return try decoder.decode(GeneratedWorkout.self, from: jsonData)
    }

    // MARK: - Exercise Swap

    func suggestSwap(
        exerciseName: String,
        muscleGroup: String,
        exerciseSets: Int,
        exerciseRepRange: String,
        exerciseRestSeconds: Int,
        workoutName: String,
        targetMuscles: [String],
        profileSummary: String,
        equipmentAccess: String
    ) async throws -> ExerciseSwap {
        let prompt = """
        You are an expert personal trainer. Suggest an alternative exercise.

        User profile: \(profileSummary)

        Current exercise: \(exerciseName) (\(muscleGroup))
        Workout context: \(workoutName) targeting \(targetMuscles.joined(separator: ", "))

        Suggest ONE alternative exercise that:
        - Targets the same muscle group (\(muscleGroup))
        - Fits the user's equipment (\(equipmentAccess))
        - Maintains similar difficulty level
        - Respects any injuries/limitations mentioned
        - CRITICAL: User has a history of bilateral shoulder dislocations (left shoulder recovering). NO behind-the-neck movements, deep dips, or heavy overhead barbell work.

        Return JSON:
        {
            "name": "Exercise Name",
            "muscleGroup": "same group",
            "sets": \(exerciseSets),
            "repRange": "\(exerciseRepRange)",
            "targetWeightLbs": null,
            "restSeconds": \(exerciseRestSeconds),
            "tips": "Brief form cue",
            "reason": "Why this is a good swap"
        }
        """

        let rawJSON = try await gateway.generateWorkoutJSON(prompt: prompt, timeout: 30.0)
        guard let jsonData = rawJSON.data(using: .utf8) else {
            throw NSError(domain: "WorkoutGenerator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode response to UTF-8"])
        }
        let decoder = JSONDecoder()
        return try decoder.decode(ExerciseSwap.self, from: jsonData)
    }
}
