import SwiftUI
import SwiftData

struct AddHabitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var targetCount: Int = 3
    @State private var selectedIcon: String = "figure.walk"
    
    let commonIcons = [
        "figure.walk", "figure.run", "figure.strengthtraining.traditional",
        "figure.archery", "figure.yoga", "heart.text.square",
        "drop", "lungs", "brain.head.profile", "eye", "hand.raised"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Habit Details") {
                    TextField("e.g., 10 Bodyweight Squats", text: $name)
                        .autocorrectionDisabled()
                    
                    Stepper("Target: \(targetCount)x per day", value: $targetCount, in: 1...20)
                }
                
                Section("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(commonIcons, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
                                        .background(selectedIcon == icon ? Color.orange : Color(.systemGray5))
                                        .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section {
                    Button("Save Habit") {
                        saveHabit()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("New Daily Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func saveHabit() {
        let habit = DailyHabit(
            name: name.trimmingCharacters(in: .whitespaces),
            targetCount: targetCount,
            icon: selectedIcon
        )
        modelContext.insert(habit)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddHabitView()
}
