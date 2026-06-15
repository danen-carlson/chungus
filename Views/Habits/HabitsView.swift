import SwiftUI
import SwiftData

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyHabit.name) private var habits: [DailyHabit]
    
    @State private var showAddHabit = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if habits.isEmpty {
                    EmptyHabitsView()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(habits.filter { $0.isActive }) { habit in
                                HabitRow(habit: habit)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Daily Habits")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddHabit = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .sheet(isPresented: $showAddHabit) {
                AddHabitView()
            }
        }
    }
}

// MARK: - Empty State

struct EmptyHabitsView: View {
    @State private var showAddHabit = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 60))
                .foregroundStyle(.orange.opacity(0.5))
            
            Text("No Habits Yet")
                .font(.title2.bold())
            
            Text("Add daily exercise snacks or micro-habits to build consistency throughout your day.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showAddHabit = true
            } label: {
                Label("Add First Habit", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .sheet(isPresented: $showAddHabit) {
            AddHabitView()
        }
    }
}

// MARK: - Habit Row

struct HabitRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var habit: DailyHabit
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                // Icon
                Image(systemName: habit.icon)
                    .font(.title2)
                    .foregroundStyle(habit.isCompletedToday ? .green : .orange)
                    .frame(width: 44, height: 44)
                    .background(habit.isCompletedToday ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name)
                        .font(.body.weight(.semibold))
                    
                    Text("\(habit.todayCount) / \(habit.targetCount) today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Checkmark button
                Button {
                    addCompletion()
                } label: {
                    Image(systemName: habit.isCompletedToday ? "checkmark.circle.fill" : "circle")
                        .font(.title)
                        .foregroundStyle(habit.isCompletedToday ? .green : .gray.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            
            // Progress bar
            ProgressView(value: habit.todayProgress)
                .tint(habit.isCompletedToday ? .green : .orange)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .contextMenu {
            Button(role: .destructive) {
                deleteHabit()
            } label: {
                Label("Delete Habit", systemImage: "trash")
            }
        }
    }
    
    private func addCompletion() {
        let completion = HabitCompletion(date: Date(), count: 1)
        habit.completions.append(completion)
        
        // Clean up old completions to keep DB small (keep last 30 days)
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        habit.completions.removeAll { $0.date < cutoff }
        
        try? modelContext.save()
    }
    
    private func deleteHabit() {
        modelContext.delete(habit)
        try? modelContext.save()
    }
}

#Preview {
    HabitsView()
}
