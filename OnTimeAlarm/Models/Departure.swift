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
    var hasLeaveAlarm: Bool    // Whether to show a leave reminder

    // Per-alarm sound identifiers (nil = use default)
    var preWakeSoundId: String?
    var wakeSoundId: String?
    var leaveSoundId: String?

    // Prep time media settings
    var prepTimeMediaType: String?       // "silence" or "appleMusic" (nil = silence)
    var prepTimeMediaId: String?         // MusicKit persistent ID for the content
    var prepTimeMediaName: String?       // Display name (e.g., "Morning Vibes")
    var prepTimeMediaArtworkURL: String? // Artwork URL for display

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
        var count = 1 // Main wake is always on
        if hasPreWakeAlarm { count += 1 }
        if hasLeaveAlarm { count += 1 }
        return count
    }

    /// All scheduled alarm times (sorted)
    var scheduledAlarmTimes: [Date] {
        var times: [Date] = []

        // Pre-wake alarm (if enabled)
        if let preWake = preWakeTime {
            times.append(preWake)
        }

        // Main wake up alarm (always on)
        times.append(wakeUpTime)

        // Leave alarm (if enabled)
        if hasLeaveAlarm {
            times.append(departureTime)
        }

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
        self.hasLeaveAlarm = true    // Enable leave alarm by default

        // Sound defaults (nil = use system default)
        self.preWakeSoundId = nil
        self.wakeSoundId = nil
        self.leaveSoundId = nil

        // Prep time media defaults (nil = silence)
        self.prepTimeMediaType = nil
        self.prepTimeMediaId = nil
        self.prepTimeMediaName = nil
        self.prepTimeMediaArtworkURL = nil

        // Generate alarm IDs
        self.preWakeAlarmId = UUID()
        self.mainWakeAlarmId = UUID()
        self.leaveAlarmId = UUID()

        // Schedule defaults (empty = no repeat)
        self.repeatDays = []
    }
}
