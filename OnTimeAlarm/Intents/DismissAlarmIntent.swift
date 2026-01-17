import AppIntents
import SwiftData

/// App Intent that triggers when the user dismisses the wake-up alarm
/// This intent starts playing music during prep time if configured
@available(iOS 26.0, *)
struct DismissAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Dismiss Alarm"
    static var description = IntentDescription("Dismisses the alarm and starts prep time music if configured")

    /// Don't open the app - just play music in background
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Departure ID")
    var departureId: String

    init() {
        self.departureId = ""
    }

    init(departureId: String) {
        self.departureId = departureId
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        print("DismissAlarmIntent: Triggered for departure \(departureId)")

        // Look up the departure to check media settings
        // Note: In a real implementation, you'd fetch from SwiftData
        // For now, we'll use a shared store pattern

        await startPrepTimeMusic(departureId: departureId)

        return .result()
    }

    @MainActor
    private func startPrepTimeMusic(departureId: String) async {
        // Access the departure data through a shared mechanism
        // Since we can't easily access SwiftData from an intent,
        // we'll use UserDefaults to store the prep time media settings

        let mediaType = UserDefaults.standard.string(forKey: "prepTimeMediaType_\(departureId)")
        let mediaId = UserDefaults.standard.string(forKey: "prepTimeMediaId_\(departureId)")

        guard mediaType == PrepTimeMediaType.appleMusic.rawValue,
              let mediaId = mediaId else {
            print("DismissAlarmIntent: No music configured for prep time (type: \(mediaType ?? "nil"))")
            return
        }

        do {
            try await PrepTimeMusicManager.shared.play(mediaId: mediaId)
            print("DismissAlarmIntent: Started playing prep time music")
        } catch {
            print("DismissAlarmIntent: Failed to play music - \(error)")
        }
    }
}

// MARK: - Helper for storing prep time settings

extension Departure {
    /// Save prep time media settings to UserDefaults for intent access
    func savePrepTimeSettingsForIntent() {
        let defaults = UserDefaults.standard
        let key = id.uuidString

        if let mediaType = prepTimeMediaType {
            defaults.set(mediaType, forKey: "prepTimeMediaType_\(key)")
        } else {
            defaults.removeObject(forKey: "prepTimeMediaType_\(key)")
        }

        if let mediaId = prepTimeMediaId {
            defaults.set(mediaId, forKey: "prepTimeMediaId_\(key)")
        } else {
            defaults.removeObject(forKey: "prepTimeMediaId_\(key)")
        }
    }

    /// Clear prep time media settings from UserDefaults
    func clearPrepTimeSettingsForIntent() {
        let defaults = UserDefaults.standard
        let key = id.uuidString
        defaults.removeObject(forKey: "prepTimeMediaType_\(key)")
        defaults.removeObject(forKey: "prepTimeMediaId_\(key)")
    }
}
