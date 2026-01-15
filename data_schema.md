# Data Schema: SwiftData Models

## 1. Context Strategy
We use `SwiftData` (`@Model` macro) for seamless generic persistence.
*   **Container:** `AppContainer` (Single source of truth).
*   **Context:** Main Actor for UI, Background Context for traffic updates.

## 2. Model: `Departure`
The core entity representing an "Alarm."

```swift
@Model
final class Departure {
    // Identity
    @Attribute(.unique) var id: UUID
    var label: String // e.g., "Gym", "Work"
    var createdDate: Date
    
    // The "Hard Constraints"
    var targetArrivalTime: Date // The anchor (e.g., 8:00 AM)
    var prepDuration: TimeInterval // Buffer (e.g., 1800s = 30m)
    
    // Travel Logic
    var staticTravelTime: TimeInterval // Manual fallback (e.g., 1200s = 20m)
    var useLiveTraffic: Bool // Toggle
    var transportType: String // "automobile", "walking", "cycling" (RawValue)
    
    // Location (Embedded or Relation)
    var destinationLat: Double?
    var destinationLong: Double?
    var destinationName: String?
    
    // State
    var isEnabled: Bool
    var isSnoozed: Bool
    
    // Barrage Mode (Fail-Safe)
    var isBarrageEnabled: Bool // If true, alarm re-arms automatically
    var barrageInterval: TimeInterval // Default 60s
    
    // Intelligence
    var homeKitSceneUUID: String? // Stored string ID for HMActionSet
    
    // Computed (Non-Persistent Concept)
    // wakeUpTime = targetArrivalTime - (prepDuration + staticTravelTime)
}
```

## 3. Model: `Preferences`
Global user settings.

```swift
@Model
final class Preferences {
    var defaultPrepTime: TimeInterval // Default 30 mins
    var defaultTransportType: String
    var trafficBuffer: TimeInterval // Extra padding (e.g., 10 mins)
}
```
