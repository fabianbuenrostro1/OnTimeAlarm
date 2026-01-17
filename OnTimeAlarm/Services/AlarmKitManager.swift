import Foundation
import SwiftUI
import AlarmKit
import AppIntents

/// Metadata attached to alarms for identifying departure-related alarms
@available(iOS 26.0, *)
nonisolated struct DepartureAlarmMetadata: AlarmMetadata {
    let departureId: String
    let alarmType: AlarmType
    let destinationName: String

    enum AlarmType: String, Codable {
        case preWake
        case mainWake
        case leave
    }
}

/// Manages scheduling and cancelling AlarmKit alarms for departures.
@MainActor
final class AlarmKitManager: ObservableObject {
    static let shared = AlarmKitManager()

    @Published private(set) var isAuthorized: Bool = false

    private init() {
        // Check initial authorization state
        if #available(iOS 26.0, *) {
            Task { @MainActor in
                updateAuthorizationState()
            }
        }
    }

    // MARK: - Authorization

    /// Request AlarmKit authorization from the user
    @discardableResult
    func requestAuthorization() async throws -> Bool {
        if #available(iOS 26.0, *) {
            do {
                let manager = AlarmManager.shared
                let state = try await manager.requestAuthorization()
                isAuthorized = (state == .authorized)
                return isAuthorized
            } catch {
                print("AlarmKitManager: Authorization error - \(error)")
                throw error
            }
        } else {
            // Fallback for older iOS - just mark as authorized
            isAuthorized = true
            return true
        }
    }

    @available(iOS 26.0, *)
    private func updateAuthorizationState() {
        let manager = AlarmManager.shared
        isAuthorized = (manager.authorizationState == .authorized)
    }

    // MARK: - Scheduling

    /// Schedule all alarms for a departure
    func scheduleAlarms(for departure: Departure) async throws {
        guard departure.isEnabled else {
            await cancelAlarms(for: departure)
            return
        }

        // Cancel existing alarms first
        await cancelAlarms(for: departure)

        if #available(iOS 26.0, *) {
            try await scheduleAlarmKitAlarms(for: departure)
        } else {
            print("AlarmKitManager: [Stub] Would schedule alarms for '\(departure.label)' (iOS 26 required)")
        }
    }

    /// Cancel all alarms for a departure
    func cancelAlarms(for departure: Departure) async {
        if #available(iOS 26.0, *) {
            await cancelAlarmKitAlarms(for: departure)
        } else {
            print("AlarmKitManager: [Stub] Would cancel alarms for '\(departure.label)'")
        }
    }

    // MARK: - AlarmKit Implementation (iOS 26+)

    @available(iOS 26.0, *)
    private func scheduleAlarmKitAlarms(for departure: Departure) async throws {
        let manager = AlarmManager.shared
        let wakeUpTime = departure.wakeUpTime
        let departureTime = departure.departureTime

        // Pre-wake alarm (if enabled) - 5 minutes before wake time
        if departure.hasPreWakeAlarm {
            let preWakeTime = wakeUpTime.addingTimeInterval(-5 * 60)
            if preWakeTime > Date() {
                try await scheduleAlarm(
                    manager: manager,
                    id: departure.preWakeAlarmId ?? UUID(),
                    date: preWakeTime,
                    title: "Wake up soon for \(departure.label)",
                    tintColor: .blue,
                    departureId: departure.id.uuidString,
                    alarmType: .preWake,
                    destinationName: departure.destinationName ?? departure.label,
                    soundIdentifier: departure.preWakeSoundId
                )
            }
        }

        // Main wake alarm (always on)
        if wakeUpTime > Date() {
            // Save prep time settings to UserDefaults for the intent to access
            departure.savePrepTimeSettingsForIntent()

            // Create the dismiss intent that will trigger prep time music
            let dismissIntent = DismissAlarmIntent(departureId: departure.id.uuidString)

            try await scheduleAlarm(
                manager: manager,
                id: departure.mainWakeAlarmId ?? UUID(),
                date: wakeUpTime,
                title: "Time to wake up!",
                tintColor: .orange,
                departureId: departure.id.uuidString,
                alarmType: .mainWake,
                destinationName: departure.destinationName ?? departure.label,
                soundIdentifier: departure.wakeSoundId,
                stopIntent: dismissIntent
            )
        }

        // Leave alarm (if enabled)
        if departure.hasLeaveAlarm && departureTime > Date() {
            try await scheduleAlarm(
                manager: manager,
                id: departure.leaveAlarmId ?? UUID(),
                date: departureTime,
                title: "Time to leave for \(departure.label)!",
                tintColor: .blue,
                departureId: departure.id.uuidString,
                alarmType: .leave,
                destinationName: departure.destinationName ?? departure.label,
                soundIdentifier: departure.leaveSoundId
            )
        }

        let alarmCount = (departure.hasPreWakeAlarm ? 1 : 0) + 1 + (departure.hasLeaveAlarm ? 1 : 0)
        print("AlarmKitManager: Scheduled \(alarmCount) alarms for '\(departure.label)'")
    }

    @available(iOS 26.0, *)
    private func cancelAlarmKitAlarms(for departure: Departure) async {
        let manager = AlarmManager.shared

        // Cancel all alarm IDs
        if let preWakeId = departure.preWakeAlarmId {
            try? await manager.cancel(id: preWakeId)
        }
        if let mainWakeId = departure.mainWakeAlarmId {
            try? await manager.cancel(id: mainWakeId)
        }
        if let leaveId = departure.leaveAlarmId {
            try? await manager.cancel(id: leaveId)
        }

        print("AlarmKitManager: Cancelled alarms for '\(departure.label)'")
    }

    // MARK: - Private Helpers

    @available(iOS 26.0, *)
    private func scheduleAlarm(
        manager: AlarmManager,
        id: UUID,
        date: Date,
        title: String,
        tintColor: Color,
        departureId: String,
        alarmType: DepartureAlarmMetadata.AlarmType,
        destinationName: String,
        soundIdentifier: String? = nil,
        stopIntent: DismissAlarmIntent? = nil
    ) async throws {
        // Note: soundIdentifier is stored for future AlarmKit sound API integration.
        // When AlarmKit supports custom sounds, we can pass AlertSound.named(soundIdentifier) here.
        _ = soundIdentifier

        let stopButton = AlarmButton(
            text: LocalizedStringResource(stringLiteral: alarmType == .mainWake ? "I'm Up" : "Dismiss"),
            textColor: tintColor,
            systemImageName: alarmType == .mainWake ? "sun.max.fill" : "checkmark"
        )

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: title),
            stopButton: stopButton
        )

        let metadata = DepartureAlarmMetadata(
            departureId: departureId,
            alarmType: alarmType,
            destinationName: destinationName
        )

        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: metadata,
            tintColor: tintColor
        )

        let schedule = Alarm.Schedule.fixed(date)

        // Schedule with or without stop intent
        if let stopIntent = stopIntent {
            _ = try await manager.schedule(
                id: id,
                configuration: .alarm(
                    schedule: schedule,
                    attributes: attributes,
                    stopIntent: stopIntent
                )
            )
        } else {
            _ = try await manager.schedule(
                id: id,
                configuration: .alarm(
                    schedule: schedule,
                    attributes: attributes
                )
            )
        }
    }
}
