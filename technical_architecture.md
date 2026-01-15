# Technical Architecture: iOS Native Implementation

> **Goal:** Build a robust, battery-efficient iOS application using strict native frameworks.

## 1. Data Persistence (SwiftData)
We will use modern **SwiftData** for managing the alarm models. It offers seamless SwiftUI integration and iCloud sync support (future proofing).

### Model: `DepartureAlarm`
*   `id`: UUID
*   `destination`: CodableLocation (Lat/Long/Name)
*   `targetArrivalTime`: Date (Time component matters)
*   `prepDuration`: TimeInterval (e.g., 30 mins)
*   `transportType`: Automobile / Transit / Walking
*   `isEnabled`: Bool
*   `homeKitSceneID`: String? (Optional)

## 2. Location & Traffic (MapKit & CoreLocation)
*   **MKDirections:** unique `MKDirections.Request` for each active alarm.
*   **Logic:**
    *   `CalculateRoute` allows us to get `expectedTravelTime`.
    *   We query this periodically (Background Fetch) or when the user opens the app.
*   **ETA Calculation:**
    `LeaveTime = TargetArrival - (ExpectedTravelTime + TrafficBuffer)`

## 3. Background Execution (BackgroundTasks Framework)
Since we need to check traffic while the user sleeps:
*   **BGAppRefreshTask:** Schedule fetches to check traffic conditions if the "Leave Time" is approaching.
*   *Note:* iOS limits background execution. We will primarily rely on **Local Notifications** scheduled conservatively, and update them if the user opens the app or if a background fetch *does* succeed.

## 4. Notifications (UserNotifications)
*   **Dynamic Scheduling:**
    *   When an alarm is set, we schedule a notification for the *estimated* wake-up time.
    *   If traffic changes significantly (detected via background fetch), we *update* the pending notification request.
*   **Time Sensitive:** We request "Time Sensitive" entitlement to break through Focus modes.

## 5. HomeKit Integration (HomeKit Framework)
*   **HMHomeManager:** To access homes.
*   **HMActionSet:** To trigger specific scenes (e.g., "Good Morning").
*   **Trigger:** We execute the scene at `LeaveTime - PrepDuration` (aka Wake Up Time).

## 6. View Architecture (MVVM)
*   **ViewModel:** `DepartureListViewModel`
    *   Holds `[DepartureAlarm]`
    *   Manages the timer for UI updates.
*   **Views:**
    *   `DepartureListView` (Main)
    *   `DepartureRow` (Cell)
    *   `EditDepartureView` (Form)
