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
    
    // Destination (To)
    var destinationLat: Double?
    var destinationLong: Double?
    var destinationName: String?
    
    // Settings
    var useLiveTraffic: Bool
    var transportType: String
    var homeKitSceneUUID: String?
    var liveTravelTime: TimeInterval? // From MapKit
    
    // Barrage Mode Configuration
    var isBarrageEnabled: Bool
    var preWakeAlarms: Int      // Alarms BEFORE wake up time (0-5)
    var postWakeAlarms: Int     // Alarms AFTER wake up time (0-30)
    var barrageInterval: TimeInterval  // Seconds between each alarm
    
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
    
    /// Total barrage alarm count
    var totalBarrageAlarms: Int {
        guard isBarrageEnabled else { return 0 }
        return preWakeAlarms + 1 + postWakeAlarms // pre + main + post
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
        
        // Barrage defaults
        self.isBarrageEnabled = false
        self.preWakeAlarms = 2
        self.postWakeAlarms = 5
        self.barrageInterval = 120 // 2 minutes
        
        // Schedule defaults (empty = no repeat)
        self.repeatDays = []
    }
}
