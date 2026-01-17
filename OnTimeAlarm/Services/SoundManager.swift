import Foundation
import AudioToolbox
import UserNotifications

/// Manages alarm sounds for notifications and previews
final class SoundManager {
    static let shared = SoundManager()
    private init() {}

    // MARK: - Sound Types

    /// Available notification sounds
    /// These map to iOS system sounds that work with UNNotificationSound
    enum NotificationSoundType: String, CaseIterable {
        case `default` = "default"
        case triTone = "tri-tone"
        case alert = "alert"
        case beacon = "beacon"
        case bulletin = "bulletin"
        case chord = "chord"
        case complete = "complete"
        case anticipate = "anticipate"

        var displayName: String {
            switch self {
            case .default: return "Default"
            case .triTone: return "Tri-Tone"
            case .alert: return "Alert"
            case .beacon: return "Beacon"
            case .bulletin: return "Bulletin"
            case .chord: return "Chord"
            case .complete: return "Complete"
            case .anticipate: return "Anticipate"
            }
        }

        /// System sound ID for preview playback
        var systemSoundID: SystemSoundID {
            switch self {
            case .default: return 1007      // Default SMS tone
            case .triTone: return 1007      // Tri-tone
            case .alert: return 1005        // Alert
            case .beacon: return 1023       // Beacon
            case .bulletin: return 1028     // Bulletin
            case .chord: return 1025        // Chord
            case .complete: return 1022     // Complete/Mail Sent
            case .anticipate: return 1020   // Anticipate
            }
        }
    }

    // MARK: - Preview

    /// Play a preview of the selected sound
    func previewSound(_ identifier: String) {
        guard let soundType = NotificationSoundType(rawValue: identifier) else {
            // Fall back to default
            AudioServicesPlaySystemSound(NotificationSoundType.default.systemSoundID)
            return
        }
        AudioServicesPlaySystemSound(soundType.systemSoundID)
    }

    // MARK: - Notification Sound

    /// Get the UNNotificationSound for scheduling
    func notificationSound(for identifier: String, isCritical: Bool) -> UNNotificationSound {
        if isCritical {
            // Critical alerts use the critical sound
            return .defaultCritical
        }

        guard let soundType = NotificationSoundType(rawValue: identifier) else {
            return .default
        }

        switch soundType {
        case .default:
            return .default
        case .triTone, .alert, .beacon, .bulletin, .chord, .complete, .anticipate:
            // For custom system sounds, we'd need to bundle audio files
            // For now, use default - can be enhanced with bundled .caf files
            return .default
        }
    }

    // MARK: - Display

    /// Get display name for a sound identifier
    func displayName(for identifier: String) -> String {
        NotificationSoundType(rawValue: identifier)?.displayName ?? "Default"
    }
}
