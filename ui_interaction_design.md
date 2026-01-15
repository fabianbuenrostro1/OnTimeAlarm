# UI/UX Interaction Design: "Map-First Mission Control"

> **Design Goal:** Feel exactly like a premium Apple app, but smarter with integrated mapping.
> **Philosophy:** "Invisible Intelligence." The map shows where you're going, the app tells you when to leave.

## 1. Visual Language: Apple Human Interface Guidelines (HIG)
We strictly adhere to iOS standards to ensure familiarity.
*   **Typography:** San Francisco (SF Pro). Large Title headers.
*   **Layout:** Standard SwiftUI `NavigationStack` with card-based content.
*   **Colors:** System Background, System Grouped Background, System Accents (Blue/Green/Red).
*   **Controls:** Native `Toggle`, `DatePicker`, segmented pickers.

## 2. The Main View: "Mission Control" Dashboard
A single-focus dashboard showing the active departure with live map.

### Primary Card (Active Departure)
The main card dominates the screen with these sections:

*   **Header:**
    *   "NEXT DEPARTURE" label
    *   Destination label (e.g., "Gym")
    *   Traffic status badge (Green: "Traffic Clear", Yellow: "Moderate", Red: "Heavy")

*   **Map Preview:**
    *   MapKit view showing route polyline from origin to destination
    *   Blue dot for origin ("You"), red pin for destination
    *   Non-interactive preview
    *   **Tap gesture:** Opens Apple Maps with directions

*   **From/To Section:**
    *   **FROM:** Current Location (with 📍 icon) OR saved address
    *   Visual connector line between From and To
    *   **TO:** Destination name (with 🎯 pin icon)

*   **Timing Section:**
    *   **LEAVE AT:** The calculated departure time (dynamic)
    *   Arrow with transport icon and travel duration
    *   **ARRIVE BY:** The user's target arrival (anchor)

*   **Alarm Toggle:**
    *   Large, prominent toggle button
    *   "🔔 Alarm On" (green) or "Alarm Off" (gray)

### Secondary List ("Later")
Additional departures shown in compact rows below the main card:
*   Departure time
*   Destination label
*   Simple toggle

## 3. The "Add/Edit" Sheet (Modal)
When tapping "+", a standard Form appears.

*   **Section 1: Route**
    *   Toggle: "Use Current Location" (default ON)
    *   Row (if toggle OFF): "From" (Opens MapKit search)
    *   Row: "To" (Opens MapKit search for destination)
    *   Label text field
    *   Transport picker (Driving/Biking/Walking) - segmented
    *   Live travel time display (with ⚡ for live data)

*   **Section 2: Timing**
    *   Picker: "Arrival Time" (When you need to be there)
    *   Picker: "Prep Duration" (15m, 30m, 45m, 1h, 1.5h, 2h)

*   **Section 3: Schedule Preview**
    *   Visual timeline: `[Wake Up] → [Leave] → [Arrive]`

## 4. Map Preview Behavior
*   **Route Display:** Blue polyline connecting origin to destination
*   **Markers:** Blue circle (origin), red pin (destination)
*   **Tap Action:** Opens Apple Maps with directions matching transport mode
*   **Traffic Status:** Compares live travel time to baseline for color coding

## 5. Origin Options
*   **Current Location (default):** Uses user's real-time GPS location
    *   Updates dynamically as user moves
    *   Shows "Current Location" label with location icon
*   **Saved Address:** User specifies a fixed origin
    *   Useful for: "After work, get to gym by 6pm"
    *   Shows building icon and address name

## 6. Implementation (SwiftUI Components)

| Component | Description |
|-----------|-------------|
| `DepartureListView` | Main dashboard with single-focus card layout |
| `DepartureCardView` | "Mission Control" card with map, From/To, timing |
| `MapPreviewView` | MapKit route preview with tap-to-open handler |
| `CompactDepartureRow` | Minimal row for secondary departures |
| `DepartureEditorView` | Form for creating/editing departures |
| `LocationSearchSheet` | MapKit address autocomplete |

## 7. Data Model Fields

| Field | Type | Purpose |
|-------|------|---------|
| `useCurrentLocation` | Bool | Whether origin is user's live location |
| `originLat/Long` | Double? | Saved origin coordinates |
| `originName` | String? | Saved origin label |
| `destinationLat/Long` | Double? | Destination coordinates |
| `destinationName` | String? | Destination label |
| `transportType` | String | "automobile", "walking", "cycling" |
| `liveTravelTime` | TimeInterval? | Current travel time from MapKit |
