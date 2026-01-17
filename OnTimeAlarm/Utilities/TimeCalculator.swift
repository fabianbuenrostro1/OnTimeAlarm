import Foundation

struct TimeCalculator {
    /// Calculate wake-up time based on arrival, prep, and travel
    static func wakeUpTime(
        arrivalTime: Date,
        prepDuration: TimeInterval,
        travelTime: TimeInterval
    ) -> Date {
        arrivalTime.addingTimeInterval(-(prepDuration + travelTime))
    }
    
    /// Calculate departure time based on arrival and travel
    static func departureTime(
        arrivalTime: Date,
        travelTime: TimeInterval
    ) -> Date {
        arrivalTime.addingTimeInterval(-travelTime)
    }
    
    /// Format a time interval as human-readable duration
    static func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(remainingMinutes)m"
        }
    }

    /// Format a time interval as conversational readable text (e.g., "30 min", "1 hour 30 min")
    static func formatDurationReadable(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return "\(minutes) min"
        } else if minutes == 0 {
            return hours == 1 ? "1 hour" : "\(hours) hours"
        } else {
            let hourText = hours == 1 ? "1 hour" : "\(hours) hours"
            return "\(hourText) \(minutes) min"
        }
    }
}
