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
    
    // Future-proofing (Phase 2+)
    var destinationLat: Double?
    var destinationLong: Double?
    var destinationName: String?
    var useLiveTraffic: Bool
    var transportType: String
    var isBarrageEnabled: Bool
    var barrageInterval: TimeInterval
    var homeKitSceneUUID: String?
    
    // MARK: - Computed Properties
    
    /// The time to wake up (start preparing)
    var wakeUpTime: Date {
        targetArrivalTime.addingTimeInterval(-(prepDuration + staticTravelTime))
    }
    
    /// The time to leave the house
    var departureTime: Date {
        targetArrivalTime.addingTimeInterval(-staticTravelTime)
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
        
        // Future defaults
        self.useLiveTraffic = false
        self.transportType = "automobile"
        self.isBarrageEnabled = false
        self.barrageInterval = 60
    }
}
