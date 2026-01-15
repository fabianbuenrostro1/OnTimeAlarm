# UI/UX Interaction Design: "Native Plus"

> **Design Goal:** Feel exactly like the Apple Clock app, but smarter.
> **Philosophy:** "Invisible Intelligence." It looks like a standard alarm, but it behaves like a personal assistant.

## 1. Visual Language: Apple Human Interface Guidelines (HIG)
We strictly adhere to iOS standards to ensure familiarity.
*   **Typography:** San Francisco (SF Pro). Large Title headers.
*   **Layout:** Standard SwiftUI `List` and `NavigationStack`.
*   **Colors:** System Background, System Grouped Background, System Accents (Orange/Green).
*   **Controls:** Native `Toggle`, `DatePicker`, and Swipe actions.

## 2. The Main View: "Departures" (Replaces "Alarms")
A standard list view, visually similar to the Clock app, but significantly more information-dense.

### The List Row (Cell)
Instead of just "7:00 AM", the row displays:

*   **Leading (Left):**
    *   **Large Time:** "7:45 AM" (This is the calculated *Leave Time*, dynamically updating).
    *   **Label:** "Gym" (Destination).
    *   **Sub-label:** "Arrive by 8:30 AM • 15m Prep" (The constraints).
*   **Trailing (Right):**
    *   **Live Status Badge:**
        *   *Green Bus/Car Icon:* "Traffic Clear"
        *   *Red Icon:* "+10m Delay"
    *   **Toggle:** Enables/Disables the "Monitoring" for this departure.

### Edit Mode
Standard "Edit" button in top left. allowing distinct "Delete" and reordering.

## 3. The "Add/Edit" Sheet (Modal)
When tapping "+", a standard Form appears.

*   **Section 1: Destination (The Anchor)**
    *   Row: "Location" (Opens MapKit search).
    *   Row: "Transport Type" (Driving, Walking, Cycling).
*   **Section 2: Timing**
    *   Picker: "Arrival Time" (When you need to be there).
    *   Picker: "Prep Duration" (How long you need before leaving).
*   **Section 3: Intelligence**
    *   Toggle: "Smart Wake" (Adjust wake up time based on traffic).
    *   Toggle: "HomeKit Scenes" (Select a Scene to trigger at Wake Up).
*   **Section 4: Label & Sound**
    *   Standard text input and sound picker.

## 4. The "Alarm" Experience (Notifications)
We use critical alerts and rich notifications.

*   **The "Wake Up" Notification:**
    *   *Title:* "Good Morning for Gym"
    *   *Body:* "Traffic is light. 25 min drive. Take your time."
    *   *Action:* "Snooze" (Smart Snooze checks if you have buffer).
*   **The "Leave Now" Notification:**
    *   *Title:* "Time to Leave"
    *   *Body:* "Traffic building up on I-405. Leave now to arrive by 8:30 AM."
    *   *Sound:* Distinct, urgent (but not annoying) chime.

## 5. Implementation Strategy (SwiftUI)
*   `NavigationStack` as root.
*   `List` with `ForEach` for the alarms.
*   `CoreData` or `SwiftData` for persistence (matching native app reliability).
*   `MapKit` for live travel time calculations.
