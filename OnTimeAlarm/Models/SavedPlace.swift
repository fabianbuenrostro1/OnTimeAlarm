import Foundation
import SwiftData
import CoreLocation

/// Represents a saved location (e.g., Home, Work, Gym)
@Model
final class SavedPlace {
    var id: UUID
    var name: String
    var icon: String // SF Symbol name
    var address: String
    var latitude: Double
    var longitude: Double
    var createdAt: Date
    
    init(
        name: String,
        icon: String = "📍",
        address: String,
        latitude: Double,
        longitude: Double
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = Date()
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // Default preset icons
    // Default preset icons / smart emojis
    static let icons = [
        "🏠", "💼", "💪", "🎓", "🛒", 
        "☕️", "🍔", "🍻", "🏥", "✈️",
        "❤️", "📍", "🌳", "🏖️", "🎉"
    ]
}
