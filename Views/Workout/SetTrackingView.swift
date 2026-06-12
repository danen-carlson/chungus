import SwiftUI

struct SetTrackingView: View {
    let exercise: ExerciseTemplate
    let exerciseSession: ExerciseSession?
    let onUpdateSet: (Int, Double?, Int, Bool) -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Text("Set")
                    .frame(width: 40, alignment: .leading)
                Text("Weight (lbs)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Reps")
                    .frame(width: 60, alignment: .center)
                Text("✓")
                    .frame(width: 40, alignment: .center)
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)

            // Sets
            if let session = exerciseSession {
                ForEach(Array(session.sets.enumerated()), id: \.element.id) { index, set in
                    SetRow(
                        set: set,
                        index: index,
                        onUpdate: { weight, reps, completed in
                            onUpdateSet(index, weight, reps, completed)
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SetRow: View {
    @Bindable var set: SetRecord
    let index: Int
    let onUpdate: (Double?, Int, Bool) -> Void

    @State private var weightText: String = ""
    @State private var repsText: String = ""

    var body: some View {
        HStack(spacing: 4) {
            // Set number
            Text(set.isWarmup ? "W" : "\(index + 1)")
                .font(.caption.bold())
                .frame(width: 36, height: 36)
                .background(set.isWarmup ? Color.gray.opacity(0.2) : Color.orange.opacity(0.15))
                .foregroundStyle(set.isWarmup ? .secondary : .orange)
                .clipShape(Circle())

            // Weight input
            TextField(
                "—",
                text: $weightText
            )
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: .infinity)
            .onAppear {
                weightText = set.weightLbs.map { $0.weightDisplay } ?? ""
            }

            // Reps input
            TextField("0", text: $repsText)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 56)
                .multilineTextAlignment(.center)
                .onAppear {
                    repsText = set.reps > 0 ? "\(set.reps)" : ""
                }

            // Done toggle
            Button {
                saveSet(completed: !set.completed)
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.completed ? .green : .gray)
            }
        }
        .onChange(of: weightText) { _, _ in saveSet(completed: set.completed) }
        .onChange(of: repsText) { _, _ in saveSet(completed: set.completed) }
    }

    private func saveSet(completed: Bool) {
        let weight = Double(weightText)
        let reps = Int(repsText) ?? 0
        onUpdate(weight, reps, completed)
    }
}
