import Foundation
import SwiftData

@Model
final class Departure {
    // Identity
    @Attribute(.unique) var id: UUID
    var label: String
    var createdDate: Date

    // Hard Constraints
    var targetArrivalTime: Date
    var prepDuration: TimeInterval    // seconds
    var staticTravelTime: TimeInterval // seconds

    // State
    var isEnabled: Bool

    // Origin (From) - Snapshot of location when created/edited
    var originLat: Double?
    var originLong: Double?
    var originName: String?
    var originAddress: String? // Detailed address (optional)

    // Destination (To)
    var destinationLat: Double?
    var destinationLong: Double?
    var destinationName: String?
    var destinationAddress: String? // Detailed address (optional)

    // Settings
    var useLiveTraffic: Bool
    var transportType: String
    var homeKitSceneUUID: String?
    var liveTravelTime: TimeInterval? // From MapKit

    // Alarm Configuration
    var hasPreWakeAlarm: Bool  // Whether to show a gentle reminder 5 min before wake

    // AlarmKit Alarm IDs (for tracking and cancellation)
    var preWakeAlarmId: UUID?
    var mainWakeAlarmId: UUID?
    var leaveAlarmId: UUID?

    // Schedule (Repeat Days)
    var repeatDays: [Int]  // 0 = Sunday, 1 = Monday, ... 6 = Saturday

    // MARK: - Computed Properties

    /// Use live travel time if available, else static
    var effectiveTravelTime: TimeInterval {
        liveTravelTime ?? staticTravelTime
    }

    /// The time to wake up (start preparing)
    var wakeUpTime: Date {
        targetArrivalTime.addingTimeInterval(-(prepDuration + effectiveTravelTime))
    }

    /// The time to leave the house
    var departureTime: Date {
        targetArrivalTime.addingTimeInterval(-effectiveTravelTime)
    }

    /// Pre-wake alarm time (5 minutes before wake up)
    var preWakeTime: Date? {
        guard hasPreWakeAlarm else { return nil }
        return wakeUpTime.addingTimeInterval(-5 * 60)
    }

    /// Total alarm count (for display purposes)
    var totalAlarmCount: Int {
        var count = 2 // Main wake + Leave
        if hasPreWakeAlarm { count += 1 }
        return count
    }

    /// All scheduled alarm times (sorted)
    var scheduledAlarmTimes: [Date] {
        var times: [Date] = []

        // Pre-wake alarm (if enabled)
        if let preWake = preWakeTime {
            times.append(preWake)
        }

        // Main wake up alarm
        times.append(wakeUpTime)

        // Leave alarm
        times.append(departureTime)

        return times
    }

    // MARK: - Initialization

    init(
        label: String = "Untitled",
        targetArrivalTime: Date = Date(),
        prepDuration: TimeInterval = 1800, // 30 minutes
        staticTravelTime: TimeInterval = 1200 // 20 minutes
    ) {
        self.id = UUID()
        self.label = label
        self.createdDate = Date()
        self.targetArrivalTime = targetArrivalTime
        self.prepDuration = prepDuration
        self.staticTravelTime = staticTravelTime
        self.isEnabled = true

        // Settings defaults
        self.useLiveTraffic = false
        self.transportType = "automobile"

        // Alarm defaults
        self.hasPreWakeAlarm = true  // Enable pre-wake by default

        // Generate alarm IDs
        self.preWakeAlarmId = UUID()
        self.mainWakeAlarmId = UUID()
        self.leaveAlarmId = UUID()

        // Schedule defaults (empty = no repeat)
        self.repeatDays = []
    }
}
