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

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("ALARMKIT: SCHEDULING ALARMS FOR '\(departure.label)'")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Current time: \(formatter.string(from: Date()))")
        print("Calculated wake time: \(formatter.string(from: wakeUpTime))")
        print("Calculated departure time: \(formatter.string(from: departureTime))")
        print("Target arrival: \(formatter.string(from: departure.targetArrivalTime))")

        // Pre-wake alarm (if enabled) - 5 minutes before wake time
        if departure.hasPreWakeAlarm {
            let preWakeTime = wakeUpTime.addingTimeInterval(-5 * 60)
            if preWakeTime > Date() {
                print("Scheduling PRE-WAKE alarm at \(formatter.string(from: preWakeTime)) (sound: \(departure.preWakeSoundId ?? "default"))")
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
                print("   Pre-wake scheduled successfully")
            } else {
                print("   Pre-wake time already passed, skipping")
            }
        }

        // Main wake alarm (always on)
        if wakeUpTime > Date() {
            // Save prep time settings to UserDefaults for the intent to access
            departure.savePrepTimeSettingsForIntent()

            // Create the dismiss intent that will trigger prep time music
            let dismissIntent = DismissAlarmIntent(departureId: departure.id.uuidString)

            print("Scheduling MAIN WAKE alarm at \(formatter.string(from: wakeUpTime)) (sound: \(departure.wakeSoundId ?? "default"))")
            print("   Prep music configured: \(departure.prepTimeMediaType ?? "none")")
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
            print("   Main wake scheduled successfully with DismissIntent")
        } else {
            print("   Wake time already passed, skipping")
        }

        // Leave alarm (if enabled)
        if departure.hasLeaveAlarm && departureTime > Date() {
            print("Scheduling LEAVE alarm at \(formatter.string(from: departureTime)) (sound: \(departure.leaveSoundId ?? "default"))")
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
            print("   Leave alarm scheduled successfully")
        }

        let alarmCount = (departure.hasPreWakeAlarm ? 1 : 0) + 1 + (departure.hasLeaveAlarm ? 1 : 0)
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("TOTAL: Scheduled \(alarmCount) alarms for '\(departure.label)'")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
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

    // MARK: - Debug/Test Methods

    /// Track test alarm IDs for cleanup
    @Published private(set) var testAlarmIds: [UUID] = []

    /// Get human-readable authorization status
    func getAuthorizationStatusString() -> String {
        if #available(iOS 26.0, *) {
            let manager = AlarmManager.shared
            switch manager.authorizationState {
            case .authorized:
                return "Authorized"
            case .denied:
                return "Denied"
            case .notDetermined:
                return "Not Determined"
            @unknown default:
                return "Unknown"
            }
        } else {
            return "iOS 26+ Required"
        }
    }

    /// Check if iOS 26+ is available for AlarmKit
    var isAlarmKitAvailable: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }

    /// Schedule a test alarm that fires after the specified number of seconds
    func scheduleTestAlarm(inSeconds seconds: TimeInterval) async throws -> UUID {
        let alarmId = UUID()

        if #available(iOS 26.0, *) {
            let manager = AlarmManager.shared
            let fireDate = Date().addingTimeInterval(seconds)

            let stopButton = AlarmButton(
                text: "Stop Test",
                textColor: .red,
                systemImageName: "xmark.circle.fill"
            )

            let alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: "Test Alarm"),
                stopButton: stopButton
            )

            let metadata = DepartureAlarmMetadata(
                departureId: "test-\(alarmId.uuidString)",
                alarmType: .mainWake,
                destinationName: "Debug Test"
            )

            let attributes = AlarmAttributes(
                presentation: AlarmPresentation(alert: alert),
                metadata: metadata,
                tintColor: .red
            )

            let schedule = Alarm.Schedule.fixed(fireDate)

            _ = try await manager.schedule(
                id: alarmId,
                configuration: .alarm(
                    schedule: schedule,
                    attributes: attributes,
                    sound: .default
                )
            )

            testAlarmIds.append(alarmId)
            print("AlarmKitManager: Scheduled test alarm \(alarmId) for \(fireDate)")
        } else {
            print("AlarmKitManager: [Stub] Would schedule test alarm (iOS 26 required)")
        }

        return alarmId
    }

    /// Cancel a specific test alarm
    func cancelTestAlarm(id: UUID) async {
        if #available(iOS 26.0, *) {
            let manager = AlarmManager.shared
            try? await manager.cancel(id: id)
            testAlarmIds.removeAll { $0 == id }
            print("AlarmKitManager: Cancelled test alarm \(id)")
        }
    }

    /// Cancel all test alarms
    func cancelAllTestAlarms() async {
        if #available(iOS 26.0, *) {
            let manager = AlarmManager.shared
            for id in testAlarmIds {
                try? await manager.cancel(id: id)
            }
            print("AlarmKitManager: Cancelled \(testAlarmIds.count) test alarms")
            testAlarmIds.removeAll()
        }
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
        // Note: Using .default sound for now. To use custom sounds, bundle .caf files
        // and use AlertSound.named(soundIdentifier) instead.
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
                    stopIntent: stopIntent,
                    sound: .default
                )
            )
        } else {
            _ = try await manager.schedule(
                id: id,
                configuration: .alarm(
                    schedule: schedule,
                    attributes: attributes,
                    sound: .default
                )
            )
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        print("   AlarmKit.schedule() called: id=\(id.uuidString.prefix(8)), date=\(formatter.string(from: date)), type=\(alarmType.rawValue), sound=default ✓")
    }
}
