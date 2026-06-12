import SwiftUI

struct WorkoutSummaryView: View {
    let session: WorkoutSession
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Celebration header
                VStack(spacing: 8) {
                    Text("💪")
                        .font(.system(size: 64))
                    Text("Workout Complete!")
                        .font(.largeTitle.bold())
                    Text(session.workoutName)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                // Stats cards
                HStack(spacing: 16) {
                    SummaryStat(
                        label: "Duration",
                        value: session.durationMinutes.map { "\($0) min" } ?? "—",
                        icon: "clock.fill"
                    )
                    SummaryStat(
                        label: "Exercises",
                        value: "\(session.exercises.count)",
                        icon: "dumbbell.fill"
                    )
                    SummaryStat(
                        label: "Volume",
                        value: "\(Int(session.totalVolumeLbs)) lbs",
                        icon: "scalemass.fill"
                    )
                }

                Divider()

                // Exercise breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Exercise Breakdown")
                        .font(.headline)

                    ForEach(session.exercises.sorted(by: { $0.order < $1.order })) { exSession in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(exSession.name)
                                    .font(.subheadline.weight(.semibold))
                                if exSession.wasSwapped {
                                    Text("(swapped)")
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                }
                                Spacer()
                                Text("Best: \(exSession.topSetWeight?.weightDisplay ?? "—") lbs")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            let completedSets = exSession.sets.filter { $0.completed && !$0.isWarmup }
                            Text("\(completedSets.count) sets • \(exSession.totalReps) total reps")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let notes = exSession.notes, !notes.isEmpty {
                                Text("📝 \(notes)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Done button
                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.large)
                    .padding(.top, 20)
            }
            .padding()
        }
        .background(Color.chungusBackground)
    }
}

struct SummaryStat: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}
