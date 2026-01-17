import Foundation
import AVFoundation

/// Manages text-to-speech voice announcements
final class VoiceAnnouncementService: NSObject {
    static let shared = VoiceAnnouncementService()

    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Voice Options

    struct VoiceOption: Identifiable {
        let id: String
        let identifier: String
        let name: String
        let language: String
        let quality: AVSpeechSynthesisVoiceQuality

        var qualityLabel: String {
            switch quality {
            case .enhanced:
                return "Enhanced"
            case .premium:
                return "Premium"
            default:
                return "Standard"
            }
        }
    }

    /// Get available English voices sorted by quality
    func availableVoices() -> [VoiceOption] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.starts(with: "en") }
            .map { voice in
                VoiceOption(
                    id: voice.identifier,
                    identifier: voice.identifier,
                    name: voice.name,
                    language: voice.language,
                    quality: voice.quality
                )
            }
            .sorted { v1, v2 in
                // Sort by quality (higher first), then by name
                if v1.quality.rawValue != v2.quality.rawValue {
                    return v1.quality.rawValue > v2.quality.rawValue
                }
                return v1.name < v2.name
            }
    }

    /// Get display name for a voice identifier
    func displayName(for identifier: String?) -> String {
        guard let identifier = identifier else {
            return "System Default"
        }

        if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice.name
        }

        return "System Default"
    }

    // MARK: - Speech

    /// Speak a message with the specified voice and rate
    func speak(_ message: String, voiceIdentifier: String?, rate: Float) {
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Configure audio session for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("VoiceAnnouncementService: Failed to configure audio session - \(error)")
        }

        let utterance = AVSpeechUtterance(string: message)

        // Set voice
        if let identifier = voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            utterance.voice = voice
        } else {
            // Use default English voice
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }

        // Set rate (0.0 to 1.0, default is 0.5)
        utterance.rate = rate

        // Slight pause before speaking for better UX
        utterance.preUtteranceDelay = 0.1

        synthesizer.speak(utterance)
    }

    /// Stop any current speech
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    // MARK: - Message Generation

    /// Generate a contextual message based on alarm type and time remaining
    func generateMessage(
        alarmLabel: String,
        minutesUntilLeave: Int,
        isWakeUp: Bool
    ) -> String {
        if isWakeUp {
            return "Good morning! Time to wake up for \(alarmLabel). You have \(minutesUntilLeave) minutes until you need to leave."
        } else if minutesUntilLeave <= 0 {
            return "Time to leave now for \(alarmLabel). You should be heading out the door."
        } else if minutesUntilLeave <= 5 {
            return "You have \(minutesUntilLeave) minutes left. Time to head out for \(alarmLabel)!"
        } else if minutesUntilLeave <= 15 {
            return "You have \(minutesUntilLeave) minutes left before you need to leave for \(alarmLabel)."
        } else {
            return "You have \(minutesUntilLeave) minutes to get ready. Take your time!"
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceAnnouncementService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Deactivate audio session when done
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("VoiceAnnouncementService: Failed to deactivate audio session - \(error)")
        }
    }
}
