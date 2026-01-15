import Foundation
import UserNotifications

/// Generates a sequence of notification dates for Barrage Mode.
struct BarrageScheduler {
    
    /// A scheduled barrage alarm with context
    struct BarrageAlarm {
        let date: Date
        let message: String
        let identifier: String
        let position: AlarmPosition
        
        enum AlarmPosition {
            case preWake(minutesBefore: Int)
            case mainWake
            case postWake(minutesAfter: Int)
            case leave
        }
    }
    
    /// Generate the full barrage alarm sequence for a departure
    /// - Parameters:
    ///   - departure: The departure to generate alarms for
    ///   - baseDate: The calculated wake up time
    /// - Returns: Array of BarrageAlarm objects ready for scheduling
    static func generateSequence(for departure: Departure) -> [BarrageAlarm] {
        var alarms: [BarrageAlarm] = []
        let wakeUpTime = departure.wakeUpTime
        let departureId = departure.id.uuidString
        let intervalMinutes = Int(departure.barrageInterval / 60)
        
        guard departure.isBarrageEnabled else {
            // If barrage is disabled, just return the main wake and leave alarms
            alarms.append(BarrageAlarm(
                date: wakeUpTime,
                message: "Time to wake up for \(departure.label)!",
                identifier: "\(departureId)-wake-main",
                position: .mainWake
            ))
            alarms.append(BarrageAlarm(
                date: departure.departureTime,
                message: "Leave now to arrive on time!",
                identifier: "\(departureId)-leave",
                position: .leave
            ))
            return alarms
        }
        
        // Pre-Wake Alarms (countdown to wake up)
        for i in stride(from: departure.preWakeAlarms, through: 1, by: -1) {
            let offset = TimeInterval(i) * departure.barrageInterval
            let alarmDate = wakeUpTime.addingTimeInterval(-offset)
            let minutesBefore = i * intervalMinutes
            
            alarms.append(BarrageAlarm(
                date: alarmDate,
                message: "⏰ \(minutesBefore)m until wake up for \(departure.label)",
                identifier: "\(departureId)-pre-\(i)",
                position: .preWake(minutesBefore: minutesBefore)
            ))
        }
        
        // Main Wake Up Alarm
        alarms.append(BarrageAlarm(
            date: wakeUpTime,
            message: "🔔 WAKE UP for \(departure.label)!",
            identifier: "\(departureId)-wake-main",
            position: .mainWake
        ))
        
        // Post-Wake Alarms (safety net)
        for i in 1...departure.postWakeAlarms {
            let offset = TimeInterval(i) * departure.barrageInterval
            let alarmDate = wakeUpTime.addingTimeInterval(offset)
            let minutesAfter = i * intervalMinutes
            
            // Escalating urgency
            let urgencyEmoji = i <= 3 ? "⚠️" : (i <= 6 ? "🚨" : "🔥")
            
            alarms.append(BarrageAlarm(
                date: alarmDate,
                message: "\(urgencyEmoji) GET UP! Missed wake by \(minutesAfter)m",
                identifier: "\(departureId)-post-\(i)",
                position: .postWake(minutesAfter: minutesAfter)
            ))
        }
        
        // Final Leave Alarm
        alarms.append(BarrageAlarm(
            date: departure.departureTime,
            message: "🚗 Leave NOW for \(departure.label)!",
            identifier: "\(departureId)-leave",
            position: .leave
        ))
        
        // Filter out any alarms in the past
        let now = Date()
        return alarms.filter { $0.date > now }
    }
}
