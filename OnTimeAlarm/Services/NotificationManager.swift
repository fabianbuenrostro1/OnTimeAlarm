import Foundation
import UserNotifications

/// Manages scheduling and cancelling local notifications for departures.
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .criticalAlert]) { granted, error in
            if let error = error {
                print("NotificationManager: Authorization error - \(error.localizedDescription)")
            } else {
                print("NotificationManager: Authorization granted = \(granted)")
            }
        }
    }
    
    // MARK: - Scheduling
    
    /// Schedule all notifications for a departure (including barrage if enabled)
    func scheduleNotifications(for departure: Departure) {
        guard departure.isEnabled else {
            cancelNotifications(for: departure)
            return
        }
        
        // Clear existing notifications for this departure
        cancelNotifications(for: departure)
        
        // Generate barrage sequence
        let alarms = BarrageScheduler.generateSequence(for: departure)
        
        print("NotificationManager: Scheduling \(alarms.count) alarms for '\(departure.label)'")
        
        for alarm in alarms {
            scheduleNotification(
                identifier: alarm.identifier,
                title: getTitle(for: alarm.position, label: departure.label),
                body: alarm.message,
                date: alarm.date,
                isCritical: isCriticalAlarm(alarm.position)
            )
        }
    }
    
    /// Cancel all notifications for a departure
    func cancelNotifications(for departure: Departure) {
        let baseId = departure.id.uuidString
        
        // Generate all possible identifiers
        var identifiers = [
            "\(baseId)-wake-main",
            "\(baseId)-leave"
        ]
        
        // Add pre-wake identifiers
        for i in 1...10 {
            identifiers.append("\(baseId)-pre-\(i)")
        }
        
        // Add post-wake identifiers
        for i in 1...30 {
            identifiers.append("\(baseId)-post-\(i)")
        }
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        print("NotificationManager: Cancelled notifications for '\(departure.label)'")
    }
    
    // MARK: - Private Helpers
    
    private func scheduleNotification(
        identifier: String,
        title: String,
        body: String,
        date: Date,
        isCritical: Bool = false
    ) {
        guard date > Date() else {
            print("NotificationManager: Skipping past alarm at \(date)")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = isCritical ? .defaultCritical : .default
        content.interruptionLevel = isCritical ? .critical : .timeSensitive
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("NotificationManager: Failed to schedule '\(identifier)' - \(error.localizedDescription)")
            }
        }
    }
    
    private func getTitle(for position: BarrageScheduler.BarrageAlarm.AlarmPosition, label: String) -> String {
        switch position {
        case .preWake:
            return "Approaching Wake Up"
        case .mainWake:
            return "WAKE UP - \(label)"
        case .postWake:
            return "⚠️ \(label) - Get Up!"
        case .leave:
            return "🚗 Time to Leave"
        }
    }
    
    private func isCriticalAlarm(_ position: BarrageScheduler.BarrageAlarm.AlarmPosition) -> Bool {
        switch position {
        case .mainWake, .postWake, .leave:
            return true
        case .preWake:
            return false
        }
    }
}
