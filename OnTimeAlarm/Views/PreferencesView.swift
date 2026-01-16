import SwiftUI
import SwiftData
import AVFoundation

struct PreferencesView: View {
    @Query private var allPreferences: [Preferences]
    @Environment(\.modelContext) private var modelContext

    private var preferences: Preferences {
        if let existing = allPreferences.first {
            return existing
        }
        let newPrefs = Preferences()
        modelContext.insert(newPrefs)
        return newPrefs
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Alarm Sound Section
                Section {
                    NavigationLink {
                        SoundPickerView(selectedSound: Binding(
                            get: { preferences.selectedSoundIdentifier },
                            set: { preferences.selectedSoundIdentifier = $0 }
                        ))
                    } label: {
                        HStack {
                            Text("Alarm Sound")
                            Spacer()
                            Text(SoundManager.shared.displayName(for: preferences.selectedSoundIdentifier))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Alarm Sound")
                } footer: {
                    Text("This sound plays when your alarm notifications fire.")
                }

                // MARK: - Voice Announcements Section
                Section {
                    Toggle("Voice Announcements", isOn: Binding(
                        get: { preferences.isVoiceEnabled },
                        set: { preferences.isVoiceEnabled = $0 }
                    ))

                    if preferences.isVoiceEnabled {
                        NavigationLink {
                            VoicePickerView(selectedVoice: Binding(
                                get: { preferences.selectedVoiceIdentifier },
                                set: { preferences.selectedVoiceIdentifier = $0 }
                            ))
                        } label: {
                            HStack {
                                Text("Voice")
                                Spacer()
                                Text(VoiceAnnouncementService.shared.displayName(for: preferences.selectedVoiceIdentifier))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Speech Rate")
                            HStack {
                                Image(systemName: "tortoise.fill")
                                    .foregroundStyle(.secondary)
                                Slider(value: Binding(
                                    get: { Double(preferences.voiceSpeechRate) },
                                    set: { preferences.voiceSpeechRate = Float($0) }
                                ), in: 0.3...0.6)
                                Image(systemName: "hare.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            VoiceAnnouncementService.shared.speak(
                                "You have 5 minutes left. Time to head out!",
                                voiceIdentifier: preferences.selectedVoiceIdentifier,
                                rate: preferences.voiceSpeechRate
                            )
                        } label: {
                            Label("Preview Voice", systemImage: "play.circle.fill")
                        }
                    }
                } header: {
                    Text("Voice Announcements")
                } footer: {
                    Text("Voice announcements help guide you through your morning routine.")
                }

                // MARK: - Test Section
                Section {
                    Button {
                        // Play sound then voice
                        SoundManager.shared.previewSound(preferences.selectedSoundIdentifier)
                        if preferences.isVoiceEnabled {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                VoiceAnnouncementService.shared.speak(
                                    "Good morning! Time to wake up for your appointment.",
                                    voiceIdentifier: preferences.selectedVoiceIdentifier,
                                    rate: preferences.voiceSpeechRate
                                )
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Test Alarm", systemImage: "bell.badge.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                // MARK: - Support Section (Placeholders)
                Section("Support") {
                    Button {
                        // TODO: Implement app store review
                    } label: {
                        Label("Rate On Time Alarm", systemImage: "star.fill")
                    }
                    .disabled(true)

                    Button {
                        // TODO: Implement referral
                    } label: {
                        Label("Refer a Friend", systemImage: "person.badge.plus")
                    }
                    .disabled(true)
                }

                // MARK: - About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Preferences")
        }
    }
}

// MARK: - Sound Picker View
struct SoundPickerView: View {
    @Binding var selectedSound: String

    var body: some View {
        List {
            ForEach(SoundManager.NotificationSoundType.allCases, id: \.rawValue) { sound in
                Button {
                    selectedSound = sound.rawValue
                    SoundManager.shared.previewSound(sound.rawValue)
                } label: {
                    HStack {
                        Text(sound.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedSound == sound.rawValue {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Alarm Sound")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Voice Picker View
struct VoicePickerView: View {
    @Binding var selectedVoice: String?
    @State private var voices: [VoiceAnnouncementService.VoiceOption] = []

    var body: some View {
        List {
            Section {
                Button {
                    selectedVoice = nil
                    VoiceAnnouncementService.shared.speak(
                        "This is the system default voice.",
                        voiceIdentifier: nil,
                        rate: 0.5
                    )
                } label: {
                    HStack {
                        Text("System Default")
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedVoice == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }

            Section("Available Voices") {
                ForEach(voices) { voice in
                    Button {
                        selectedVoice = voice.identifier
                        VoiceAnnouncementService.shared.speak(
                            "Hello! This is \(voice.name).",
                            voiceIdentifier: voice.identifier,
                            rate: 0.5
                        )
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(voice.name)
                                    .foregroundStyle(.primary)
                                Text(voice.qualityLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedVoice == voice.identifier {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Voice")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            voices = VoiceAnnouncementService.shared.availableVoices()
        }
    }
}

#Preview {
    PreferencesView()
        .modelContainer(for: [Preferences.self], inMemory: true)
}
