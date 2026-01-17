import Foundation
import SwiftData

@Model
final class Preferences {
    // MARK: - Default Alarm Settings
    var defaultPrepTime: TimeInterval    // seconds
    var defaultTravelTime: TimeInterval  // seconds
    var trafficBuffer: TimeInterval      // extra padding
    var defaultTransportType: String

    // MARK: - Alarm Sound Settings
    var selectedSoundIdentifier: String

    // MARK: - Voice Announcement Settings
    var isVoiceEnabled: Bool
    var selectedVoiceIdentifier: String?
    var voiceSpeechRate: Float

    init(
        defaultPrepTime: TimeInterval = 1800,    // 30 minutes
        defaultTravelTime: TimeInterval = 1200,  // 20 minutes
        trafficBuffer: TimeInterval = 600,       // 10 minutes
        defaultTransportType: String = "automobile",
        selectedSoundIdentifier: String = "default",
        isVoiceEnabled: Bool = true,
        selectedVoiceIdentifier: String? = nil,
        voiceSpeechRate: Float = 0.5
    ) {
        self.defaultPrepTime = defaultPrepTime
        self.defaultTravelTime = defaultTravelTime
        self.trafficBuffer = trafficBuffer
        self.defaultTransportType = defaultTransportType
        self.selectedSoundIdentifier = selectedSoundIdentifier
        self.isVoiceEnabled = isVoiceEnabled
        self.selectedVoiceIdentifier = selectedVoiceIdentifier
        self.voiceSpeechRate = voiceSpeechRate
    }
}
