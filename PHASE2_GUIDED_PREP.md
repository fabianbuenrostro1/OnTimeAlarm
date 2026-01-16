# Phase 2: Guided Prep Experience

## Overview

The guided prep experience transforms On Time Alarm from a notification scheduler into an intelligent morning companion. When a user "checks in" by tapping their wake-up notification, they enter a guided prep mode that helps them through their morning routine.

---

## Core Concepts

### The Barrage = Wake-Up Insurance
- Multiple alarms exist solely to ensure the user wakes up
- Pre-wake and post-wake alarms are "just in case" redundancy
- Once the user checks in, **cancel all remaining barrage alarms**

### Check-In Flow
1. Wake-up notification fires
2. User taps notification (or opens app)
3. App recognizes this as a "check-in"
4. Cancel all remaining wake/post-wake notifications
5. Enter **Guided Prep Mode**

### Guided Prep Mode
- In-app UI showing countdown to departure
- Voice announcements at key intervals
- The app becomes a companion: "You have 30 minutes to get ready"

---

## User Scenarios

### Scenario 1: Morning Wake-Up
```
6:00 AM - Pre-wake notification: "15 minutes until wake up"
6:15 AM - WAKE UP notification fires
6:15 AM - User taps notification
         → Cancel 6:16, 6:17, 6:18... post-wake alarms
         → Enter Guided Prep Mode
         → "Good morning! You have 45 minutes to get ready for Work."
6:30 AM - Voice: "30 minutes until you need to leave"
6:45 AM - Voice: "15 minutes left. Start wrapping up."
6:55 AM - Voice: "5 minutes! Time to head out."
7:00 AM - Leave alarm: "Time to leave now for Work!"
```

### Scenario 2: Midday Appointment (User Already Awake)
```
User sets alarm for 2:00 PM dentist appointment
- No barrage needed (user is already awake)
- Single alarm at 1:00 PM (1 hour before leave time)
- User taps notification → enters Guided Prep Mode
- Voice announcements guide them to leave on time
```

---

## Technical Implementation

### 1. Notification Delegate (Check-In Detection)

```swift
// NotificationManager.swift
extension NotificationManager: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let identifier = response.notification.request.identifier

        // Extract departure ID from notification identifier
        // Format: "{departureId}-{type}-{number}"
        guard let departureId = extractDepartureId(from: identifier) else { return }

        // Check if this is a wake-up related alarm
        if isWakeUpAlarm(identifier) {
            // Cancel remaining barrage alarms
            cancelRemainingBarrageAlarms(for: departureId)

            // Post notification to enter guided prep mode
            NotificationCenter.default.post(
                name: .didCheckIn,
                object: nil,
                userInfo: ["departureId": departureId]
            )
        }
    }
}
```

### 2. Guided Prep View

```swift
struct GuidedPrepView: View {
    let departure: Departure
    @State private var timeRemaining: TimeInterval = 0

    var body: some View {
        VStack(spacing: 24) {
            // Greeting
            Text(greeting)
                .font(.title)

            // Countdown
            Text(formattedTimeRemaining)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text("until you leave for \(departure.label)")
                .font(.title3)
                .foregroundStyle(.secondary)

            // Progress ring
            CircularProgressView(progress: prepProgress)

            // Destination card
            DestinationCard(departure: departure)
        }
    }
}
```

### 3. Voice Announcement Schedule

| Time Remaining | Announcement |
|----------------|-------------|
| On check-in | "Good morning! You have X minutes to get ready for [destination]." |
| 30 min | "30 minutes until you need to leave." |
| 15 min | "15 minutes left. Start wrapping up." |
| 10 min | "10 minutes. Almost time to head out." |
| 5 min | "5 minutes! Time to grab your things and go." |
| 0 min | "Time to leave now! Have a great trip to [destination]." |

### 4. State Management

```swift
// PrepSession.swift
@Observable
class PrepSession {
    var isActive: Bool = false
    var departure: Departure?
    var startTime: Date?
    var leaveTime: Date?

    var timeRemaining: TimeInterval {
        guard let leaveTime else { return 0 }
        return max(0, leaveTime.timeIntervalSinceNow)
    }

    func start(for departure: Departure) {
        self.departure = departure
        self.startTime = Date()
        self.leaveTime = departure.departureTime
        self.isActive = true
        scheduleVoiceAnnouncements()
    }

    func end() {
        isActive = false
        departure = nil
        cancelScheduledAnnouncements()
    }
}
```

---

## Files to Create

| File | Purpose |
|------|---------|
| `GuidedPrepView.swift` | Main countdown UI during prep |
| `PrepSession.swift` | State management for active prep session |
| `CircularProgressView.swift` | Visual progress indicator |
| `CheckInHandler.swift` | Handles notification tap → check-in logic |

## Files to Modify

| File | Changes |
|------|---------|
| `NotificationManager.swift` | Add UNUserNotificationCenterDelegate, check-in detection |
| `OnTimeAlarmApp.swift` | Set notification delegate, observe check-in events |
| `AlarmListView.swift` | Conditionally show GuidedPrepView when session active |
| `VoiceAnnouncementService.swift` | Add scheduled announcement methods |

---

## UI/UX Considerations

### Guided Prep Screen Should Show:
- Large countdown timer (primary focus)
- Destination name and travel info
- Quick access to maps/navigation
- "I'm leaving now" button (ends session)
- "Cancel" option (if plans changed)

### Voice Announcement Preferences:
- Enable/disable voice during prep
- Customize announcement intervals
- Choose voice character

### Edge Cases:
- What if user doesn't check in? Keep barrage going.
- What if user closes app during prep? Continue in background? Send reminder notifications?
- What if departure time passes? End session gracefully.

---

## Implementation Order

1. **Notification delegate setup** - Detect when user taps notification
2. **PrepSession state** - Track active prep sessions
3. **GuidedPrepView UI** - Countdown interface
4. **Voice scheduling** - Announce time remaining at intervals
5. **App integration** - Show GuidedPrepView when session active
6. **Polish** - Animations, edge cases, preferences

---

## Questions to Resolve

1. Should the app auto-launch into Guided Prep when tapping notification? (Probably yes)
2. Background announcements - worth the complexity? Or voice only when app is open?
3. Should there be a "quick glance" widget for the countdown?
4. Integration with CarPlay for the "time to leave" moment?
