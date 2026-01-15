# Project Roadmap: On Time Alarm

> **Philosophy:** "Crawl, Walk, Run." We will build the robust core first, then add the intelligence layers.

## Phase 1: The "Backwards" Clock (MVP)
**Goal:** A fully functional alarm app that calculates "Wake Up Time" based on inputs, without live external data.
*   **Core Feature:** "Departure Logic" engine.
    *   Input: Arrival Time (8:00 AM).
    *   Input: Manual Travel Estimation (e.g., user types "20 mins").
    *   Input: Prep Buffer (e.g., "30 mins").
    *   Output: Alarm fires at 7:10 AM.
*   **UI:** Native List View, CRUD operations (Create, Read, Update, Delete).
*   **Notifications:** Standard local notifications.

## Phase 2: Intelligence (MapKit Integration)
**Goal:** Replace manual travel estimates with live data.
*   **Feature:** Location Search (MapKit).
*   **Feature:** Live Route Calculation.
    *   User selects "Gym" (Location).
    *   App fetches driving time (e.g., 18 mins).
    *   App auto-adjusts the "Manual Travel Estimation" field.
*   **Feature:** "Traffic Pad."
    *   Adds a safety buffer (e.g., +10 mins) to all live routes to account for variance.

## Phase 3: The Environment (HomeKit)
**Goal:** The room wakes up with you.
*   **Feature:** HomeKit Authorization.
*   **Feature:** Scene Selection Picker.
*   **Feature:** "Sunrise" Logic.
    *   Trigger light scene 15 mins *before* the audible alarm.

## Phase 4: Polish & Publish
**Goal:** App Store ready.
*   **Feature:** Marketing Assets & App Icon.
*   **Feature:** Widget (Lock Screen countdown).
*   **Feature:** "Critical Alerts" entitlement (for overriding Silent Mode).
