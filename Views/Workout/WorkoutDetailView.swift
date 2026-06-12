import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let template: WorkoutTemplate

    @State private var showExerciseExecution = false
    @State private var workoutVM = WorkoutViewModel()
    @State private var swappingExerciseId: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.largeTitle.bold())

                    HStack(spacing: 16) {
                        Label("\(template.exercises.count) exercises", systemImage: "list.bullet")
                        Label("\(template.estimatedDurationMin) min", systemImage: "clock")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                // Target muscles
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(template.targetMuscles, id: \.self) { muscle in
                            Text(muscle.capitalized)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.15))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }
                }

                Divider()

                // Exercise list
                ForEach(Array(template.exercises.sorted(by: { $0.order < $1.order }).enumerated()), id: \.element.id) { index, exercise in
                    ExerciseRow(
                        exercise: exercise,
                        index: index + 1,
                        onSwap: { swapExercise(exercise) }
                    )
                }
            }
            .padding()
        }
        .background(Color.chungusBackground)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                startWorkout()
            } label: {
                Text("Start Workout")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showExerciseExecution) {
            NavigationStack {
                ExerciseExecutionView(viewModel: workoutVM)
                    .environment(\.modelContext, modelContext)
            }
        }
    }

    private func startWorkout() {
        workoutVM.startWorkout(template: template, context: modelContext)
        showExerciseExecution = true
    }

    private func swapExercise(_ exercise: ExerciseTemplate) {
        // TODO: Present swap UI
        swappingExerciseId = exercise.id
    }
}

// MARK: - Exercise Row

struct ExerciseRow: View {
    let exercise: ExerciseTemplate
    let index: Int
    let onSwap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text("\(index)")
                    .font(.caption.bold())
                    .frame(width: 24, height: 24)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.body.weight(.semibold))

                    HStack(spacing: 8) {
                        Text(exercise.setsRepsDisplay)
                        Text("•")
                        Text(exercise.muscleGroup.capitalized)
                        if let weight = exercise.targetWeightLbs {
                            Text("•")
                            Text("\(Int(weight)) lbs")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button("Swap Exercise", systemImage: "arrow.triangle.2.circlepath", action: onSwap)
                } label: {
                    Image(systemName: "ellipsis")
                        .padding(8)
                }
            }

            if let tips = exercise.tips, !tips.isEmpty {
                Text(tips)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 32)
            }
        }
        .cardStyle()
    }
}
