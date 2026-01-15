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
}
