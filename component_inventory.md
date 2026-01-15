# Component Inventory: SwiftUI

> A checklist of every View and sub-component needed to build the app.

## 1. Screens (Views)

### `DepartureListView` (Home)
*   **Role:** The main dashboard.
*   **Components:**
    *   `StandardNavigationStack`
    *   `DepartureListRow` (The custom cell)
    *   `EmptyStateView` (Invitation to add first alarm)

### `DepartureEditorView` (Sheet)
*   **Role:** The "Add/Edit" form.
*   **Components:**
    *   `LocationSearchRow` (Button triggering search)
    *   `TimeCirclePicker` or `NativeDatePicker`
    *   `PrepDurationSlider`
    *   `SmartToggle` (For HomeKit/Traffic)

### `LocationSearchView` (Sheet)
*   **Role:** Wrapper around `MKLocalSearch`.
*   **Components:**
    *   `SearchField`
    *   `MapResultRow`

## 2. Reusable Components (Widgets)

### `DepartureCell`
*   **Visuals:**
    *   Main Time (The logic-derived "Wake Up" time).
    *   Subtext (Arrival Time + Prep Duration).
    *   `TrafficBadge`: A stylized Icon + Text (e.g., "Heavy Traffic").
    *   `ToggleSwitch`: Custom styled toggle.

### `TimeDifferenceVisualizer`
*   **Role:** Used in the Editor to show the math.
*   **Visual:** `[Arrival]  <-- [Travel] -- [Prep] --> [Wake Up]`
*   Shows the user exactly how the time is calculated.

### `HomeKitPicker`
*   **Role:** A horizontal scroll of available HomeKit Scenes.
*   Icon + Name.
