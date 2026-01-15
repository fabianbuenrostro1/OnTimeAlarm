# Mission Brief: On Time Alarm

> **Target:** Eliminate "Time Blindness" and "Alarm Fatigue."
> **Strategy:** Shift from "Setting an Alarm" to "Setting a Departure."
> **Status:** Planning Complete. Ready for Execution.

## 1. The Core Objective
We are building a **native iOS utility** that replaces the standard "Clock" app for critical events (Work, Gym, Meetings). It focuses on *Arrival Time* and *Prep Duration* to calculate the optimal *Wake Up Time*, powered by live traffic data and environmental cues (HomeKit).

## 2. The Mission Manual (Deliverables)
The following documents constitute the comprehensive plan for this project:

### Strategy & Design
*   [Product Concept: "Precision & Control"](product_concept.md) - The philosophy of professional time management.
*   [UI/UX Design: "Native Plus"](ui_interaction_design.md) - The Apple HIG-compliant interface specification.
*   [Project Roadmap](roadmap.md) - Phased execution plan (MVP -> Intelligence -> Environment).

### Technical Blueprints
*   [Technical Architecture](technical_architecture.md) - The iOS framework strategy (SwiftData, BackgroundTasks).
*   [Data Schema](data_schema.md) - The `Departure` and `Preferences` data models.
*   [Component Inventory](component_inventory.md) - The SwiftUI view hierarchy checklist.

## 3. Execution Plan (Phase 1)
Our immediate next step is to initialize the project and build the **MVP Core**.

1.  **Project Setup (Xcode):** Initialize "OnTime" app with SwiftData.
2.  **Data Layer:** Implement `Departure` SwiftData model.
3.  **UI Skeleton:** Build `DepartureListView` and `DepartureEditorView`.
4.  **Logic:** Implement the `wakeUpTime` calculation (Arrival - (Travel + Prep)).

> "We are go for launch on user command."
