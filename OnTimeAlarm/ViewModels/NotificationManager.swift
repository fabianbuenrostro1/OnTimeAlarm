import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Scheduling
    
    func scheduleNotifications(for departure: Departure) {
        guard departure.isEnabled else { return }
        
        // Cancel existing notifications first
        cancelNotifications(for: departure)
        
        let wakeUpTime = departure.wakeUpTime
        let departureTime = departure.departureTime
        
        // Schedule wake-up notification
        scheduleNotification(
            identifier: wakeUpNotificationId(for: departure),
            title: "Good Morning for \(departure.label)",
            body: "Your departure is in \(TimeCalculator.formatDuration(departure.prepDuration)). Time to start preparing!",
            date: wakeUpTime
        )
        
        // Schedule departure notification
        scheduleNotification(
            identifier: departureNotificationId(for: departure),
            title: "Time to Leave for \(departure.label)",
            body: "Leave now to arrive by \(formatTime(departure.targetArrivalTime)).",
            date: departureTime
        )
    }
    
    func cancelNotifications(for departure: Departure) {
        let identifiers = [
            wakeUpNotificationId(for: departure),
            departureNotificationId(for: departure)
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    // MARK: - Private Helpers
    
    private func wakeUpNotificationId(for departure: Departure) -> String {
        "\(departure.id.uuidString)-wakeup"
    }
    
    private func departureNotificationId(for departure: Departure) -> String {
        "\(departure.id.uuidString)-departure"
    }
    
    private func scheduleNotification(identifier: String, title: String, body: String, date: Date) {
        // Only schedule if the date is in the future
        guard date > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
