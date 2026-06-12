import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No History Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Complete your first workout to see it here.")
                    )
                } else {
                    List {
                        ForEach(groupedSessions, id: \.month) { group in
                            Section(group.month) {
                                ForEach(group.sessions) { session in
                                    NavigationLink {
                                        SessionDetailView(session: session)
                                    } label: {
                                        HistoryRow(session: session)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }

    private var groupedSessions: [SessionGroup] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: sessions) { session in
            formatter.string(from: session.startedAt)
        }

        return grouped
            .map { SessionGroup(month: $0.key, sessions: $0.value) }
            .sorted { $0.sessions.first?.startedAt ?? .now > $1.sessions.first?.startedAt ?? .now }
    }

    struct SessionGroup {
        let month: String
        let sessions: [WorkoutSession]
    }
}

// MARK: - History Row

struct HistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.workoutName)
                    .font(.body.weight(.semibold))
                HStack(spacing: 8) {
                    Text(session.startedAt.relativeDisplay)
                    if let mins = session.durationMinutes {
                        Text("• \(mins) min")
                    }
                    Text("• \(session.exercises.count) exercises")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(Int(session.totalVolumeLbs))")
                    .font(.subheadline.bold())
                Text("lbs")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Session Detail

struct SessionDetailView: View {
    let session: WorkoutSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading) {
                    Text(session.workoutName)
                        .font(.largeTitle.bold())
                    Text(session.startedAt.formatted(date: .complete, time: .shortened))
                        .foregroundStyle(.secondary)
                }

                // Stats
                HStack(spacing: 16) {
                    SummaryStat(label: "Duration", value: session.durationMinutes.map { "\($0) min" } ?? "—", icon: "clock.fill")
                    SummaryStat(label: "Volume", value: "\(Int(session.totalVolumeLbs)) lbs", icon: "scalemass.fill")
                }

                Divider()

                // Exercises
                ForEach(session.exercises.sorted(by: { $0.order < $1.order })) { exSession in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(exSession.name)
                            .font(.headline)

                        ForEach(exSession.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                            HStack {
                                Text("Set \(set.setNumber)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 50, alignment: .leading)
                                Text(set.weightLbs.map { "\($0.weightDisplay) lbs" } ?? "BW")
                                    .frame(width: 80, alignment: .leading)
                                Text("× \(set.reps)")
                                Spacer()
                                Image(systemName: set.completed ? "checkmark.circle.fill" : "xmark.circle")
                                    .foregroundStyle(set.completed ? .green : .red)
                            }
                            .font(.subheadline)
                        }

                        if let notes = exSession.notes, !notes.isEmpty {
                            Text("📝 \(notes)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .cardStyle()
                }

                if let notes = session.overallNotes, !notes.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Session Notes")
                            .font(.headline)
                        Text(notes)
                    }
                    .cardStyle()
                }
            }
            .padding()
        }
        .background(Color.chungusBackground)
        .navigationTitle("Workout Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}
