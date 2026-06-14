import SwiftUI
import SwiftData

struct ExerciseExecutionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: WorkoutViewModel

    @State private var restTimer: Timer?
    @State private var workoutTimer: Timer?
    @State private var showJumpToList = false
    @State private var showSummary = false
    @Query private var profiles: [UserProfile]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Progress bar
                ProgressView(value: viewModel.progress)
                    .tint(.orange)

                if let exercise = viewModel.currentExercise {
                    // Exercise header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Exercise \(viewModel.currentExerciseIndex + 1) of \(viewModel.totalExercises)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(exercise.name)
                            .font(.title2.bold())

                        Text(exercise.setsRepsDisplay + " • Rest \(exercise.restSeconds)s")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Exercise image
                    if let imageUrl = exercise.imageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            case .failure:
                                EmptyView()
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 100)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }

                    // Tips
                    if let tips = exercise.tips, !tips.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Tips", systemImage: "lightbulb.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.yellow)
                            Text(tips)
                                .font(.subheadline)
                        }
                        .cardStyle()
                    }

                    // Set tracking table
                    SetTrackingView(
                        exercise: exercise,
                        exerciseSession: viewModel.currentExerciseSession,
                        onUpdateSet: { index, weight, reps, completed in
                            viewModel.updateSet(setIndex: index, weight: weight, reps: reps, completed: completed)
                        }
                    )

                    // Add set button
                    Button {
                        viewModel.addSet()
                    } label: {
                        Label("Add Set", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)

                    // Notes
                    if let exSession = viewModel.currentExerciseSession {
                        VStack(alignment: .leading) {
                            Text("Notes")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            TextField("How did it feel?", text: Binding(
                                get: { exSession.notes ?? "" },
                                set: { exSession.notes = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                    }

                    // Swap button
                    Button {
                        if let profile = profiles.first {
                            let summary = profile.promptSummary
                            let equipment = profile.equipmentAccess
                            Task {
                                await viewModel.requestSwap(profileSummary: summary, equipmentAccess: equipment)
                            }
                        }
                    } label: {
                        if viewModel.isSwapping {
                            ProgressView()
                        } else {
                            Label("Swap Exercise", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .disabled(viewModel.isSwapping)
                }
            }
            .padding()
        }
        .background(Color.chungusBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("End") {
                    dismiss()
                }
                .foregroundStyle(.red)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showJumpToList = true
                } label: {
                    Image(systemName: "list.number")
                }
            }
            ToolbarItem(placement: .principal) {
                Text(viewModel.workoutElapsed.workoutTimerDisplay)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .safeAreaInset(edge: .bottom) {
            navigationBar
        }
        // Rest timer overlay
        .overlay {
            if viewModel.isResting {
                RestTimerOverlay(
                    timeRemaining: viewModel.restTimeRemaining,
                    onSkip: { viewModel.skipRest() }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        // Swap suggestion sheet
        .sheet(isPresented: $viewModel.showSwapSuggestion) {
            if let swap = viewModel.swapSuggestion {
                SwapSuggestionView(
                    suggestion: swap,
                    onAccept: { viewModel.acceptSwap() },
                    onReject: { viewModel.rejectSwap() }
                )
                .presentationDetents([.medium])
            }
        }
        // Jump to exercise list
        .sheet(isPresented: $showJumpToList) {
            JumpToExerciseView(
                exercises: viewModel.template?.exercises.sorted { $0.order < $1.order } ?? [],
                currentIndex: viewModel.currentExerciseIndex,
                onSelect: { index in
                    viewModel.jumpToExercise(index: index)
                    showJumpToList = false
                }
            )
            .presentationDetents([.medium])
        }
        // Workout summary
        .fullScreenCover(isPresented: $showSummary) {
            if let session = viewModel.session {
                WorkoutSummaryView(session: session, onDone: { dismiss() })
            }
        }
        .onAppear {
            startTimers()
        }
        .onDisappear {
            stopTimers()
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.previousExercise()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(viewModel.currentExerciseIndex == 0)

            if viewModel.isLastExercise {
                Button {
                    Task {
                        try? await viewModel.completeWorkout(context: modelContext)
                        showSummary = true
                    }
                } label: {
                    Text("Finish 💪")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Button {
                    viewModel.nextExercise()
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
    }

    // MARK: - Timers

    private func startTimers() {
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if let start = viewModel.workoutStartTime {
                viewModel.workoutElapsed = Date().timeIntervalSince(start)
            }
        }

        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            viewModel.tickRestTimer()
        }
    }

    private func stopTimers() {
        workoutTimer?.invalidate()
        restTimer?.invalidate()
    }
}

// MARK: - Rest Timer Overlay

struct RestTimerOverlay: View {
    let timeRemaining: Int
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Rest")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("\(timeRemaining)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
                .contentTransition(.numericText())

            Button("Skip", action: onSkip)
                .buttonStyle(.bordered)
        }
        .padding(40)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 10)
        .padding(40)
    }
}

// MARK: - Swap Suggestion

struct SwapSuggestionView: View {
    let suggestion: WorkoutGenerator.ExerciseSwap
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Exercise Swap")
                .font(.headline)

            VStack(spacing: 8) {
                Text(suggestion.name)
                    .font(.title3.bold())
                Text(suggestion.muscleGroup.capitalized)
                    .foregroundStyle(.secondary)
                Text("\(suggestion.sets)×\(suggestion.repRange)")
                    .font(.subheadline)
                if let tips = suggestion.tips {
                    Text(tips)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(suggestion.reason)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                Button("Cancel", action: onReject)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                Button("Accept Swap", action: onAccept)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }
}

// MARK: - Jump To Exercise

struct JumpToExerciseView: View {
    let exercises: [ExerciseTemplate]
    let currentIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        NavigationStack {
            List(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                Button {
                    onSelect(index)
                } label: {
                    HStack {
                        Text("\(index + 1). \(exercise.name)")
                            .foregroundStyle(.primary)
                        Spacer()
                        if index == currentIndex {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Jump to Exercise")
        }
    }
}
