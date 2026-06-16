import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let template: WorkoutTemplate

    @State private var showExerciseExecution = false
    @State private var workoutVM = WorkoutViewModel()

    // Swap state
    @State private var swappingExercise: ExerciseTemplate?
    @State private var isSwapping = false
    @State private var swapSuggestion: WorkoutGenerator.ExerciseSwap?
    @State private var showSwapSheet = false
    @State private var showSwapNotesSheet = false
    @State private var swapNotes: String = ""
    @State private var swapError: String?

    // Image preview
    @State private var previewImage: (url: String, name: String)?

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
                        isSwapping: swappingExercise?.id == exercise.id && isSwapping,
                        initiateSwap: { initiateSwap(exercise) },
                        onImageTap: {
                            if let url = exercise.imageUrl {
                                previewImage = (url, exercise.name)
                            }
                        }
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
        .sheet(isPresented: $showSwapSheet) {
            if let suggestion = swapSuggestion {
                SwapSuggestionView(
                    suggestion: suggestion,
                    onAccept: { acceptSwap() },
                    onReject: { rejectSwap() }
                )
                .presentationDetents([.medium])
            }
        }
        .fullScreenCover(item: Binding(
            get: { previewImage.map { IdentifiedPreview(url: $0.url, name: $0.name) } },
            set: { previewImage = $0.map { ($0.url, $0.name) } }
        )) { preview in
            ExerciseImagePreview(url: preview.url, name: preview.name)
        }
        .sheet(isPresented: $showSwapNotesSheet) {
            NavigationStack {
                VStack(spacing: 16) {
                    Text("Why are you swapping \(swappingExercise?.name ?? "this exercise")?")
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    Text("Optional: Tell the AI what you want differently (e.g., 'too hard on my lower back', 'want a machine instead', 'need a dumbbell alternative').")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    TextEditor(text: $swapNotes)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4))
                        )
                        .padding(.horizontal)

                    Spacer()

                    Button {
                        executeSwap()
                    } label: {
                        HStack {
                            if isSwapping {
                                ProgressView().tint(.white)
                            }
                            Text(isSwapping ? "Generating..." : "Find Alternative")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(isSwapping)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding(.top)
                .navigationTitle("Swap Exercise")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            showSwapNotesSheet = false
                            swappingExercise = nil
                        }
                    }
                }
            }
        }
        .alert("Swap Failed", isPresented: Binding(
            get: { swapError != nil },
            set: { if !$0 { swapError = nil } }
        )) {
            Button("OK") { swapError = nil }
        } message: {
            Text(swapError ?? "Unknown error")
        }
    }

    private func startWorkout() {
        workoutVM.startWorkout(template: template, context: modelContext)
        showExerciseExecution = true
    }

    private func initiateSwap(_ exercise: ExerciseTemplate) {
        swappingExercise = exercise
        swapNotes = ""
        showSwapNotesSheet = true
    }

    private func executeSwap() {
        showSwapNotesSheet = false
        isSwapping = true
        swapError = nil

        Task {
            do {
                var descriptor = FetchDescriptor<UserProfile>(
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
                descriptor.fetchLimit = 1
                let profile = try? modelContext.fetch(descriptor).first
                let profileSummary = profile?.promptSummary ?? "Adult, hypertrophy goal"
                let equipmentAccess = profile?.equipmentAccess ?? "Full Gym"

                let generator = WorkoutGenerator()
                let suggestion = try await generator.suggestSwap(
                    exerciseName: swappingExercise!.name,
                    muscleGroup: swappingExercise!.muscleGroup,
                    exerciseSets: swappingExercise!.sets,
                    exerciseRepRange: swappingExercise!.repRange,
                    exerciseRestSeconds: swappingExercise!.restSeconds,
                    workoutName: template.name,
                    targetMuscles: template.targetMuscles,
                    profileSummary: profileSummary,
                    equipmentAccess: equipmentAccess,
                    userNotes: swapNotes.isEmpty ? nil : swapNotes
                )
                swapSuggestion = suggestion
                showSwapSheet = true
            } catch {
                swapError = error.localizedDescription
            }
            isSwapping = false
        }
    }

    private func acceptSwap() {
        guard let suggestion = swapSuggestion,
              let exercise = swappingExercise else { return }

        exercise.name = suggestion.name
        exercise.muscleGroup = suggestion.muscleGroup
        exercise.sets = suggestion.sets
        exercise.repRange = suggestion.repRange
        exercise.tips = suggestion.tips

        // Resolve image URL for the swap
        if let imageUrl = suggestion.imageUrl {
            exercise.imageUrl = imageUrl.hasPrefix("http") ? imageUrl : "https://fitness.hankbot.online\(imageUrl)"
        } else {
            exercise.imageUrl = nil
        }

        try? modelContext.save()

        showSwapSheet = false
        swapSuggestion = nil
        swappingExercise = nil
    }

    private func rejectSwap() {
        showSwapSheet = false
        swapSuggestion = nil
        swappingExercise = nil
    }
}

// MARK: - Preview Helper

struct IdentifiedPreview: Identifiable {
    let id = UUID()
    let url: String
    let name: String
}

// MARK: - Exercise Image Preview

struct ExerciseImagePreview: View {
    let url: String
    let name: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                AsyncImage(url: URL(string: url)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.5))
                            Text("Image unavailable")
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - Exercise Row

struct ExerciseRow: View {
    let exercise: ExerciseTemplate
    let index: Int
    var isSwapping: Bool = false
    let initiateSwap: () -> Void
    var onImageTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Exercise image thumbnail
                if let imageUrl = exercise.imageUrl, let url = URL(string: imageUrl) {
                    Button {
                        onImageTap?()
                    } label: {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.title2)
                                    .foregroundStyle(.orange)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color.orange.opacity(0.1))
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                } else {
                    // No image — show number badge
                    Text("\(index)")
                        .font(.caption.bold())
                        .frame(width: 60, height: 60)
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

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

                if isSwapping {
                    ProgressView()
                        .controlSize(.small)
                        .padding(8)
                } else {
                    Menu {
                        Button("Swap Exercise", systemImage: "arrow.triangle.2.circlepath", action: initiateSwap)
                    } label: {
                        Image(systemName: "ellipsis")
                            .padding(8)
                    }
                }
            }

            if let tips = exercise.tips, !tips.isEmpty {
                Text(tips)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 72)
            }
        }
        .cardStyle()
    }
}
