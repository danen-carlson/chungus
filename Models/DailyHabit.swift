import Foundation
import SwiftData

@Model
final class DailyHabit {
    @Attribute(.unique) var id: UUID
    var name: String
    var targetCount: Int
    var icon: String
    var isActive: Bool
    
    @Relationship(deleteRule: .cascade, inverse: \HabitCompletion.habit)
    var completions: [HabitCompletion] = []
    
    init(name: String, targetCount: Int, icon: String = "figure.walk", isActive: Bool = true) {
        self.id = UUID()
        self.name = name
        self.targetCount = targetCount
        self.icon = icon
        self.isActive = isActive
    }
    
    /// Number of times this habit was completed today
    var todayCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return completions.filter { calendar.isDate($0.date, inSameDayAs: today) }.reduce(0) { $0 + $1.count }
    }
    
    /// Whether the target has been met for today
    var isCompletedToday: Bool {
        todayCount >= targetCount
    }
    
    /// Progress fraction for today (capped at 1.0)
    var todayProgress: Double {
        min(Double(todayCount) / Double(targetCount), 1.0)
    }
}

@Model
final class HabitCompletion {
    @Attribute(.unique) var id: UUID
    var date: Date
    var count: Int
    
    @Relationship var habit: DailyHabit?
    
    init(date: Date, count: Int = 1) {
        self.id = UUID()
        self.date = date
        self.count = count
    }
}
