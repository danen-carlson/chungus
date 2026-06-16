import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DashboardViewModel()
    @State private var selectedWorkout: WorkoutTemplate?
    @State private var showRebuildPlan = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Stats header
                    statsHeader

                    // Upcoming workouts
                    if viewModel.upcomingWorkouts.isEmpty {
                        VStack(spacing: 16) {
                            ContentUnavailableView(
                                "No Workouts Yet",
                                systemImage: "dumbbell",
                                description: Text("Generate your AI workout plan to get started.")
                            )

                            if viewModel.isGenerating {
                                HStack {
                                    ProgressView()
                                    Text("Generating your plan...")
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            } else {
                                Button {
                                    Task {
                                        await viewModel.generatePlan(context: modelContext)
                                    }
                                } label: {
                                    Label("Generate Workout Plan", systemImage: "sparkles")
                                        .font(.headline)
                                        .padding()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                            }

                            if let error = viewModel.generationError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.top, 40)
                    } else {
                        ForEach(viewModel.upcomingWorkouts) { workout in
                            WorkoutCard(
                                workout: workout,
                                lastSession: viewModel.lastSession(for: workout)
                            )
                            .onTapGesture {
                                selectedWorkout = workout
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.chungusBackground)
            .navigationTitle("Chungus")
            .toolbar {
                if !viewModel.upcomingWorkouts.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showRebuildPlan = true
                        } label: {
                            Label("Rebuild", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                }
            }
            .onAppear {
                viewModel.loadData(context: modelContext)
            }
            .navigationDestination(item: $selectedWorkout) { workout in
                WorkoutDetailView(template: workout)
            }
            .sheet(isPresented: $showRebuildPlan) {
                RebuildPlanView()
            }
        }
    }

    private var statsHeader: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Workouts",
                value: "\(viewModel.totalWorkoutsCompleted)",
                icon: "dumbbell.fill"
            )
            StatCard(
                title: "Streak",
                value: "\(viewModel.currentStreak)",
                icon: "flame.fill"
            )
            StatCard(
                title: "Split",
                value: viewModel.activePlan?.splitType ?? "—",
                icon: "calendar"
            )
        }
    }
}

// MARK: - Workout Card

struct WorkoutCard: View {
    let workout: WorkoutTemplate
    let lastSession: WorkoutSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workout.name)
                    .font(.title3.bold())
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Label("\(workout.exercises.count) exercises", systemImage: "list.bullet")
                Label("\(workout.estimatedDurationMin) min", systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Target muscles chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(workout.targetMuscles, id: \.self) { muscle in
                        Text(muscle.capitalized)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
            }

            if let last = lastSession {
                Text("Last: \(last.startedAt.relativeDisplay) • \(last.durationMinutes ?? 0) min")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .cardStyle()
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}
