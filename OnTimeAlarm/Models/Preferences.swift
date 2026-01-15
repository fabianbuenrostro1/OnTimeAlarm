import Foundation
import SwiftData

@Model
final class Preferences {
    var defaultPrepTime: TimeInterval    // seconds
    var defaultTravelTime: TimeInterval  // seconds
    var trafficBuffer: TimeInterval      // extra padding
    var defaultTransportType: String
    
    init(
        defaultPrepTime: TimeInterval = 1800,    // 30 minutes
        defaultTravelTime: TimeInterval = 1200,  // 20 minutes
        trafficBuffer: TimeInterval = 600,       // 10 minutes
        defaultTransportType: String = "automobile"
    ) {
        self.defaultPrepTime = defaultPrepTime
        self.defaultTravelTime = defaultTravelTime
        self.trafficBuffer = trafficBuffer
        self.defaultTransportType = defaultTransportType
    }
}
