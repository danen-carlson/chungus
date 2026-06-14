import SwiftUI

struct ActiveWorkoutView: View {
    @State private var viewModel = WatchWorkoutViewModel()
    @State private var restTimer: Timer?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Workout timer
                Text(viewModel.elapsed.workoutTimerDisplay)
                    .font(.system(.title2, design: .rounded).monospacedDigit())
                    .foregroundStyle(.orange)

                if let exercise = viewModel.currentExercise {
                    // Current exercise
                    VStack(spacing: 4) {
                        Text("\(viewModel.currentExerciseIndex + 1)/\(viewModel.totalExercises)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(exercise.name)
                            .font(.headline)
                            .multilineTextAlignment(.center)

                        Text(exercise.setsRepsDisplay)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Current set info
                    if viewModel.currentSetIndex < exercise.sets {
                        VStack(spacing: 4) {
                            Text("Set \(viewModel.currentSetIndex + 1)")
                                .font(.caption.bold())

                            // Quick weight display
                            Text(exercise.targetWeightLbs.map { "\(Int($0)) lbs" } ?? "—")
                                .font(.title3.bold())

                            // Reps input
                            HStack(spacing: 8) {
                                Button {
                                    viewModel.adjustReps(-1)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                                .buttonStyle(.plain)

                                Text("\(viewModel.currentReps)")
                                    .font(.title3.bold().monospacedDigit())
                                    .frame(minWidth: 30)

                                Button {
                                    viewModel.adjustReps(1)
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                }
                                .buttonStyle(.plain)
                            }
                            .foregroundStyle(.orange)

                            // Complete set button
                            Button {
                                viewModel.completeSet()
                            } label: {
                                Text("Done ✓")
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .controlSize(.small)
                        }
                        .padding()
                        .background(Color(.darkGray).opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Rest timer
                    if viewModel.isResting {
                        VStack(spacing: 4) {
                            Text("Rest")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(viewModel.restTimeRemaining)")
                                .font(.title.bold())
                                .foregroundStyle(.blue)
                                .contentTransition(.numericText())
                        }
                    }
                } else {
                    Text("No exercises loaded")
                        .foregroundStyle(.secondary)
                }

                // End workout
                Button(role: .destructive) {
                    viewModel.endWorkout()
                } label: {
                    Text("End Workout")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .onAppear {
            viewModel.startWorkout()
            startTimer()
        }
        .onDisappear {
            restTimer?.invalidate()
        }
    }

    private func startTimer() {
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                viewModel.tick()
            }
        }
    }
}
