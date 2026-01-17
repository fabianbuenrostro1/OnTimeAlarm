import Foundation
import AudioToolbox
import UserNotifications
import SwiftUI

/// Manages alarm sounds for notifications and previews
final class SoundManager {
    static let shared = SoundManager()
    private init() {}

    // MARK: - Sound Categories

    /// Sound categories for organizing notification sounds
    enum SoundCategory: String, CaseIterable, Identifiable {
        case iOS = "iOS"
        case motivational = "Motivational"
        case holiday = "Holiday"

        var id: String { rawValue }
        var displayName: String { rawValue }

        /// Whether this category has sounds available (not a placeholder)
        var isAvailable: Bool {
            switch self {
            case .iOS: return true
            case .motivational, .holiday: return false
            }
        }

        /// Sounds belonging to this category (max 8 per category)
        var sounds: [NotificationSoundType] {
            switch self {
            case .iOS:
                return NotificationSoundType.allCases
            case .motivational, .holiday:
                return [] // Placeholder - no sounds yet
            }
        }
    }

    // MARK: - Sound Types

    /// Available notification sounds (8 sounds per category max)
    /// These map to iOS system sounds that work with UNNotificationSound
    enum NotificationSoundType: String, CaseIterable, Identifiable {
        case triTone = "tri-tone"
        case alert = "alert"
        case beacon = "beacon"
        case bulletin = "bulletin"
        case chord = "chord"
        case complete = "complete"
        case anticipate = "anticipate"
        case chime = "chime"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .triTone: return "Tri-Tone"
            case .alert: return "Alert"
            case .beacon: return "Beacon"
            case .bulletin: return "Bulletin"
            case .chord: return "Chord"
            case .complete: return "Complete"
            case .anticipate: return "Anticipate"
            case .chime: return "Chime"
            }
        }

        /// System sound ID for preview playback
        var systemSoundID: SystemSoundID {
            switch self {
            case .triTone: return 1007      // Tri-tone
            case .alert: return 1005        // Alert
            case .beacon: return 1023       // Beacon
            case .bulletin: return 1028     // Bulletin
            case .chord: return 1025        // Chord
            case .complete: return 1022     // Complete/Mail Sent
            case .anticipate: return 1020   // Anticipate
            case .chime: return 1008        // Chime
            }
        }
    }

    // MARK: - Preview

    /// Play a preview of the selected sound
    func previewSound(_ identifier: String) {
        guard let soundType = NotificationSoundType(rawValue: identifier) else {
            // Fall back to Tri-Tone
            AudioServicesPlaySystemSound(NotificationSoundType.triTone.systemSoundID)
            return
        }
        AudioServicesPlaySystemSound(soundType.systemSoundID)
    }

    // MARK: - Notification Sound

    /// Get the UNNotificationSound for scheduling
    func notificationSound(for identifier: String?, isCritical: Bool) -> UNNotificationSound {
        if isCritical {
            // Critical alerts use the critical sound
            return .defaultCritical
        }

        // For custom system sounds, we'd need to bundle audio files
        // For now, use default system sound - can be enhanced with bundled .caf files
        return .default
    }

    // MARK: - Display

    /// Get display name for a sound identifier
    func displayName(for identifier: String) -> String {
        NotificationSoundType(rawValue: identifier)?.displayName ?? "Tri-Tone"
    }

    /// Get display name for an optional sound identifier (nil = Tri-Tone)
    func displayName(for identifier: String?) -> String {
        guard let id = identifier else { return "Tri-Tone" }
        return NotificationSoundType(rawValue: id)?.displayName ?? "Tri-Tone"
    }
}
