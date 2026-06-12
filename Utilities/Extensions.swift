import SwiftUI

// MARK: - Date Extensions

extension Date {
    /// "Today", "Yesterday", or formatted date
    var relativeDisplay: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            return self.formatted(date: .abbreviated, time: .omitted)
        }
    }

    /// "Mon, Jun 12" style
    var shortDisplay: String {
        self.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    /// Format as "45:32" or "1:02:15"
    var workoutTimerDisplay: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Color Extensions

extension Color {
    static let chungusPrimary = Color.orange
    static let chungusAccent = Color.red
    static let chungusBackground = Color(.systemGroupedBackground)
    static let chungusCard = Color(.secondarySystemGroupedBackground)
}

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.chungusCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Double Extensions

extension Double {
    /// Format weight for display: "135" or "135.5"
    var weightDisplay: String {
        if self == self.rounded() {
            return "\(Int(self))"
        } else {
            return String(format: "%.1f", self)
        }
    }
}
