import SwiftUI
import SwiftData
import MapKit
import CoreLocation
import MusicKit

struct DepartureWizardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationManager.self) private var locationManager

    let departure: Departure?
    
    init(departure: Departure? = nil) {
        self.departure = departure
    }
    
    // MARK: - State
    @State private var label: String = ""
    
    // Locations
    @State private var fromName: String = ""
    @State private var fromAddress: String?
    @State private var fromCoordinate: CLLocationCoordinate2D?

    @State private var toName: String?
    @State private var toAddress: String?
    @State private var toCoordinate: CLLocationCoordinate2D?
    
    // Timing
    @State private var arrivalTime: Date = {
        // Default to tomorrow at 9 AM
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.day! += 1
        components.hour = 9
        components.minute = 0
        return calendar.date(from: components) ?? Date()
    }()
    
    @State private var prepDuration: TimeInterval = 1800 // 30 min default
    
    // Travel
    @State private var travelTime: TimeInterval = 0
    @State private var transportMode: TravelTimeService.TransportMode = .automobile
    @State private var isLoadingTravel: Bool = false
    
    // Alarm Settings
    @State private var hasPreWakeAlarm: Bool = true
    @State private var hasLeaveAlarm: Bool = true

    // Per-alarm sounds (nil = default)
    @State private var preWakeSoundId: String? = nil
    @State private var wakeSoundId: String? = nil
    @State private var leaveSoundId: String? = nil

    // Sound type selection (sound vs voice message)
    enum AlarmSoundType: String, CaseIterable {
        case sound = "Sound"
        case voice = "Voice Message"
    }
    @State private var preWakeSoundType: AlarmSoundType = .sound
    @State private var wakeSoundType: AlarmSoundType = .sound
    @State private var leaveSoundType: AlarmSoundType = .sound

    // Repeat Days (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
    @State private var repeatDays: Set<Int> = []

    // Inline expansion
    @State private var isTimePickerExpanded: Bool = false
    @State private var isRepeatPickerExpanded: Bool = false
    @State private var isPrepPickerExpanded: Bool = false

    // Sound picker expansion
    @State private var isPreWakeSoundExpanded: Bool = false
    @State private var isWakeSoundExpanded: Bool = false
    @State private var isLeaveSoundExpanded: Bool = false

    // Sound confirmation state (which sound is waiting for confirm tap)
    @State private var confirmingSoundId: String? = nil

    // Sound category selection
    @State private var selectedSoundCategory: SoundManager.SoundCategory = .iOS

    // Prep time music selection
    @State private var prepTimeMediaType: PrepTimeMediaType = .silence
    @State private var prepTimeMediaId: String? = nil
    @State private var prepTimeMediaName: String? = nil
    @State private var prepTimeMediaArtworkURL: String? = nil
    @State private var isPrepTimeMusicExpanded: Bool = false
    @State private var confirmingPlaylistId: String? = nil

    // Custom prep time input
    @State private var isCustomPrepTime: Bool = false
    @State private var customPrepMinutes: String = ""
    @FocusState private var isCustomPrepFocused: Bool

    #if DEBUG
    @State private var debugMinutesFromNow: Int = 2
    #endif

    private var isEditing: Bool { departure != nil }
    
    // MARK: - Calculations
    private var wakeUpTime: Date {
        TimeCalculator.wakeUpTime(
            arrivalTime: arrivalTime,
            prepDuration: prepDuration,
            travelTime: travelTime
        )
    }
    
    private var leaveTime: Date {
        TimeCalculator.departureTime(
            arrivalTime: arrivalTime,
            travelTime: travelTime
        )
    }
    
    private var canSave: Bool {
        toCoordinate != nil && fromCoordinate != nil
    }
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }
    
    private var repeatSummary: String {
        if repeatDays.isEmpty {
            return "Just once"
        } else if repeatDays.count == 7 {
            return "Every day"
        } else if repeatDays == [1, 7] {
            return "Weekends"
        } else if repeatDays == [2, 3, 4, 5, 6] {
            return "Weekdays"
        } else {
            let calendar = Calendar.current
            let weekdays = calendar.shortWeekdaySymbols
            let sortedDays = repeatDays.sorted().map { weekdays[$0 - 1] }
            return sortedDays.joined(separator: ", ")
        }
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    madLibsSection

                    alarmSentenceSection
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onChange(of: fromCoordinate?.latitude) { _, _ in
                calculateTravelTime()
            }
            .onChange(of: toCoordinate?.latitude) { _, _ in
                calculateTravelTime()
            }
            .onChange(of: transportMode) { _, _ in
                calculateTravelTime()
            }
            .onAppear {
                loadExistingDeparture()
            }
        }
    }
    
    // MARK: - Mad Libs Section
    @ViewBuilder
    private var madLibsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Label/title field - pill style input
            TextField("This trip is for...", text: $label)
                .font(.title2)
                .fontWeight(.semibold)
                .italic()
                .multilineTextAlignment(.center)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("I need to")
                .font(.title3)
                .foregroundStyle(.secondary)

            // Transport mode picker - chip style
            HStack(spacing: 12) {
                Image(systemName: transportMode.icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 32)

                HStack(spacing: 0) {
                    ForEach(TravelTimeService.TransportMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.snappy) { transportMode = mode }
                        } label: {
                            Text(mode.rawValue)
                                .font(.subheadline.weight(transportMode == mode ? .semibold : .regular))
                                .foregroundStyle(transportMode == mode ? .white : .primary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(transportMode == mode ? Color.blue : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text("from")
                .font(.title3)
                .foregroundStyle(.secondary)

            InlineLocationField(
                coordinate: $fromCoordinate,
                locationName: $fromName,
                locationAddress: $fromAddress,
                placeholder: "Starting location",
                icon: "circle.fill",
                iconColor: .blue,
                showUseMyLocation: true
            )
            .zIndex(2) // Ensure dropdown appears above other content

            Text("to")
                .font(.title3)
                .foregroundStyle(.secondary)

            InlineLocationField(
                coordinate: $toCoordinate,
                locationName: Binding(
                    get: { toName ?? "" },
                    set: { toName = $0.isEmpty ? nil : $0 }
                ),
                locationAddress: $toAddress,
                placeholder: "Destination location",
                icon: "circle.fill",
                iconColor: .red
            )
            .zIndex(1) // Ensure dropdown appears above other content
            .onChange(of: toName) { _, newValue in
                if let name = newValue, label.isEmpty {
                    label = name
                }
            }
            
            Text("arriving")
                .font(.title3)
                .foregroundStyle(.secondary)

            // Expandable inline time picker
            VStack(spacing: 0) {
                // Header row (always visible)
                HStack(spacing: 12) {
                    Image(systemName: "clock.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                        .frame(width: 32)

                    Text(timeFormatter.string(from: arrivalTime))
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isTimePickerExpanded ? 180 : 0))
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.snappy) {
                        isTimePickerExpanded.toggle()
                    }
                }

                // Expandable picker
                if isTimePickerExpanded {
                    DatePicker(
                        "",
                        selection: $arrivalTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text("repeating")
                .font(.title3)
                .foregroundStyle(.secondary)

            // Expandable inline repeat picker
            VStack(spacing: 0) {
                // Header row (always visible)
                HStack(spacing: 12) {
                    Image(systemName: "repeat")
                        .font(.title2)
                        .foregroundStyle(repeatDays.isEmpty ? .gray : .orange)
                        .frame(width: 32)

                    Text(repeatSummary)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isRepeatPickerExpanded ? 180 : 0))
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.snappy) {
                        isRepeatPickerExpanded.toggle()
                    }
                }

                // Expandable day selector
                if isRepeatPickerExpanded {
                    repeatDaysStrip
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text("with")
                .font(.title3)
                .foregroundStyle(.secondary)

            // Expandable inline prep time picker
            VStack(spacing: 0) {
                // Header row (always visible)
                HStack(spacing: 12) {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                        .frame(width: 32)

                    Text("\(Int(prepDuration / 60)) min to get ready")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isPrepPickerExpanded ? 180 : 0))
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.snappy) {
                        isPrepPickerExpanded.toggle()
                    }
                }

                // Expandable prep time bubbles
                if isPrepPickerExpanded {
                    prepDurationBubbles
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text("During my prep time, I'd like")
                .font(.title3)
                .foregroundStyle(.secondary)

            // Prep time music picker
            prepTimeMusicPicker

            #if DEBUG
            debugQuickTestSection
            #endif
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Prep Time Music Picker
    @ViewBuilder
    private var prepTimeMusicPicker: some View {
        VStack(spacing: 0) {
            // Header row (always visible)
            HStack(spacing: 12) {
                Image(systemName: prepTimeMediaType == .silence ? "speaker.slash" : "music.note")
                    .font(.title2)
                    .foregroundStyle(prepTimeMediaType == .silence ? .gray : .purple)
                    .frame(width: 32)

                Text(prepTimeMediaType == .silence ? "Silence" : (prepTimeMediaName ?? "Select Music"))
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isPrepTimeMusicExpanded ? 180 : 0))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.snappy) {
                    isPrepTimeMusicExpanded.toggle()
                    confirmingPlaylistId = nil
                }
            }

            // Expanded content
            if isPrepTimeMusicExpanded {
                VStack(spacing: 16) {
                    // Type selector chips (Silence / Apple Music)
                    HStack(spacing: 0) {
                        ForEach(PrepTimeMediaType.allCases, id: \.rawValue) { type in
                            Button {
                                withAnimation(.snappy) {
                                    prepTimeMediaType = type
                                    if type == .silence {
                                        prepTimeMediaId = nil
                                        prepTimeMediaName = nil
                                        prepTimeMediaArtworkURL = nil
                                    } else {
                                        // Request authorization when Apple Music is selected
                                        Task {
                                            await PrepTimeMusicManager.shared.requestAuthorization()
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: type.icon)
                                        .font(.caption)
                                    Text(type.displayName)
                                        .font(.subheadline.weight(prepTimeMediaType == type ? .semibold : .regular))
                                }
                                .foregroundStyle(prepTimeMediaType == type ? .white : .primary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(prepTimeMediaType == type ? Color.purple : Color.clear)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    // Content based on selection
                    if prepTimeMediaType == .appleMusic {
                        prepTimeMusicContent
                    } else {
                        // Silence selected - show info
                        HStack {
                            Image(systemName: "speaker.slash")
                                .foregroundStyle(.secondary)
                            Text("No music will play during prep time")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var prepTimeMusicContent: some View {
        let musicManager = PrepTimeMusicManager.shared

        VStack(spacing: 12) {
            // Authorization check
            if musicManager.authorizationStatus == .notDetermined {
                Button {
                    Task {
                        await musicManager.requestAuthorization()
                    }
                } label: {
                    HStack {
                        Image(systemName: "lock.shield")
                        Text("Grant Music Access")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 16)
            } else if musicManager.authorizationStatus == .denied {
                VStack(spacing: 8) {
                    Image(systemName: "lock.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Music access denied")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Enable in Settings → Privacy → Media & Apple Music")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
            } else if musicManager.authorizationStatus == .authorized {
                // Show playlists
                if musicManager.isLoadingPlaylists {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else if musicManager.userPlaylists.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "music.note.list")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No playlists found")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Refresh") {
                            Task {
                                try? await musicManager.fetchPlaylists()
                            }
                        }
                        .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                } else {
                    // Playlist grid
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Playlists")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(musicManager.userPlaylists, id: \.id) { playlist in
                                    playlistItem(playlist)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func playlistItem(_ playlist: Playlist) -> some View {
        let isSelected = prepTimeMediaId == playlist.id.rawValue
        let isConfirming = confirmingPlaylistId == playlist.id.rawValue

        Button {
            if isConfirming {
                // Second tap: confirm and close
                prepTimeMediaId = playlist.id.rawValue
                prepTimeMediaName = playlist.name
                if let url = PrepTimeMusicManager.shared.artworkURL(for: playlist) {
                    prepTimeMediaArtworkURL = url.absoluteString
                }
                confirmingPlaylistId = nil
                PrepTimeMusicManager.shared.stop()
                withAnimation(.snappy) {
                    isPrepTimeMusicExpanded = false
                }
            } else {
                // First tap: preview and enter confirm state
                confirmingPlaylistId = playlist.id.rawValue
                Task {
                    try? await PrepTimeMusicManager.shared.preview(mediaId: playlist.id.rawValue)
                }
            }
        } label: {
            VStack(spacing: 8) {
                // Artwork
                ZStack {
                    if let artwork = playlist.artwork {
                        ArtworkImage(artwork, width: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray4))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "music.note.list")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            )
                    }

                    // Selection indicator
                    if isConfirming {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.purple, lineWidth: 3)
                            .frame(width: 80, height: 80)

                        Image(systemName: "questionmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.purple))
                    } else if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.purple, lineWidth: 3)
                            .frame(width: 80, height: 80)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.purple))
                    }
                }

                // Name
                Text(playlist.name)
                    .font(.caption)
                    .foregroundStyle(isSelected || isConfirming ? .purple : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var prepDurationBubbles: some View {
        let steps = [5] + Array(stride(from: 10, through: 60, by: 5)) + [75, 90]
        let isCustomSelected = isCustomPrepTime || !steps.contains(Int(prepDuration / 60))

        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 50), spacing: 12)], spacing: 12) {
                ForEach(steps, id: \.self) { minutes in
                    let duration = TimeInterval(minutes * 60)
                    let isSelected = !isCustomSelected && prepDuration == duration

                    Button {
                        withAnimation(.snappy) {
                            isCustomPrepTime = false
                            prepDuration = duration
                        }
                    } label: {
                        Text("\(minutes)")
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? .white : .primary)
                            .frame(width: 48, height: 48)
                            .background(isSelected ? Color.orange : Color(.systemGray5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                // Custom "+" button
                Button {
                    withAnimation(.snappy) {
                        isCustomPrepTime = true
                        customPrepMinutes = ""
                        isCustomPrepFocused = true
                    }
                } label: {
                    Image(systemName: isCustomSelected ? "pencil" : "plus")
                        .font(.subheadline.weight(isCustomSelected ? .semibold : .regular))
                        .foregroundStyle(isCustomSelected ? .white : .primary)
                        .frame(width: 48, height: 48)
                        .background(isCustomSelected ? Color.orange : Color(.systemGray5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Custom input field
            if isCustomPrepTime {
                HStack(spacing: 8) {
                    TextField("", text: $customPrepMinutes)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.headline)
                        .frame(width: 60)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .focused($isCustomPrepFocused)
                        .onSubmit {
                            applyCustomPrepTime()
                        }

                    Text("minutes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Set") {
                        applyCustomPrepTime()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func applyCustomPrepTime() {
        if let minutes = Int(customPrepMinutes), minutes > 0 {
            withAnimation(.snappy) {
                prepDuration = TimeInterval(minutes * 60)
                isCustomPrepFocused = false
                isCustomPrepTime = false
                isPrepPickerExpanded = false
            }
        }
    }
    
    @ViewBuilder
    private var prepDurationRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Text("I need")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Text("\(Int(prepDuration / 60)) min")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                
                Text("to get ready")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 10 to 60 in steps of 5, then 75 and 90
                    let steps = Array(stride(from: 10, through: 60, by: 5)) + [75, 90]
                    
                    ForEach(steps, id: \.self) { minutes in
                        let duration = TimeInterval(minutes * 60)
                        let isSelected = prepDuration == duration
                        
                        Button {
                            withAnimation(.snappy) {
                                prepDuration = duration
                            }
                        } label: {
                            Text("\(minutes)")
                                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .frame(width: 44, height: 44)
                                .background(isSelected ? Color.orange : Color(.systemGray6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    @ViewBuilder
    private var repeatDaysStrip: some View {
        let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
        
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { day in
                let isSelected = repeatDays.contains(day)
                
                Button {
                    withAnimation(.snappy) {
                        if isSelected {
                            repeatDays.remove(day)
                        } else {
                            repeatDays.insert(day)
                        }
                    }
                } label: {
                    Text(dayLabels[day - 1])
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .frame(width: 40, height: 40)
                        .background(isSelected ? Color.orange : Color(.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Result Hero Section
    @ViewBuilder
    private var resultHeroSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Wake Up")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(timeFormatter.string(from: wakeUpTime))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
            }
            
            HStack(spacing: 20) {
                resultItem(label: "Leave", time: leaveTime, color: .orange)
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.tertiary)
                
                resultItem(label: "Arrive", time: arrivalTime, color: .green)
            }
            
            travelTimeLabel
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var travelTimeLabel: some View {
        if travelTime > 0 {
            Text("\(Int(travelTime / 60)) min \(transportModeLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
        } else if isLoadingTravel {
            ProgressView()
                .scaleEffect(0.8)
        }
    }
    
    // MARK: - Alarm Sentence Section
    @ViewBuilder
    private var alarmSentenceSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Pre-Wake Alarm (optional)
            preWakeAlarmSection

            // Wake Alarm (required)
            wakeAlarmSection

            // Leave Alarm (optional)
            leaveAlarmSection

            Text("to ensure I'm up and out.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: Pre-Wake Alarm
    @ViewBuilder
    private var preWakeAlarmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(hasPreWakeAlarm ? "I'd like a" : "I would not like a")
                .font(.title3)
                .foregroundStyle(.secondary)

            // Alarm row with toggle
            HStack(spacing: 12) {
                Image(systemName: "bell")
                    .font(.title2)
                    .foregroundStyle(hasPreWakeAlarm ? .blue : .gray)
                    .frame(width: 32)

                Text("pre-wake alarm")
                    .font(.headline)
                    .foregroundStyle(hasPreWakeAlarm ? .primary : .secondary)

                Spacer()

                Toggle("", isOn: $hasPreWakeAlarm)
                    .labelsHidden()
                    .tint(.blue)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Sound selection (only if enabled)
            if hasPreWakeAlarm {
                Text("that sounds like")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                inlineSoundPicker(
                    soundId: $preWakeSoundId,
                    soundType: $preWakeSoundType,
                    isExpanded: $isPreWakeSoundExpanded,
                    accentColor: .blue
                )
            }
        }
    }

    // MARK: Wake Alarm
    @ViewBuilder
    private var wakeAlarmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("And a")
                .font(.title3)
                .foregroundStyle(.secondary)

            // Alarm row (required - always on)
            HStack(spacing: 12) {
                Image(systemName: "bell.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .frame(width: 32)

                Text("wake-up alarm")
                    .font(.headline)

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text("that sounds like")
                .font(.title3)
                .foregroundStyle(.secondary)

            inlineSoundPicker(
                soundId: $wakeSoundId,
                soundType: $wakeSoundType,
                isExpanded: $isWakeSoundExpanded,
                accentColor: .orange
            )
        }
    }

    // MARK: Leave Alarm
    @ViewBuilder
    private var leaveAlarmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(hasLeaveAlarm ? "Plus a" : "But not a")
                .font(.title3)
                .foregroundStyle(.secondary)

            // Alarm row with toggle
            HStack(spacing: 12) {
                Image(systemName: "car.fill")
                    .font(.title2)
                    .foregroundStyle(hasLeaveAlarm ? .blue : .gray)
                    .frame(width: 32)

                Text("leave reminder")
                    .font(.headline)
                    .foregroundStyle(hasLeaveAlarm ? .primary : .secondary)

                Spacer()

                Toggle("", isOn: $hasLeaveAlarm)
                    .labelsHidden()
                    .tint(.blue)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Sound selection (only if enabled)
            if hasLeaveAlarm {
                Text("that sounds like")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                inlineSoundPicker(
                    soundId: $leaveSoundId,
                    soundType: $leaveSoundType,
                    isExpanded: $isLeaveSoundExpanded,
                    accentColor: .blue
                )
            }
        }
    }

    // MARK: Inline Sound Picker
    @ViewBuilder
    private func inlineSoundPicker(
        soundId: Binding<String?>,
        soundType: Binding<AlarmSoundType>,
        isExpanded: Binding<Bool>,
        accentColor: Color
    ) -> some View {
        VStack(spacing: 0) {
            // Header row (always visible)
            HStack(spacing: 12) {
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(accentColor)
                    .frame(width: 32)

                Text(soundType.wrappedValue == .voice ? "Voice Message" : SoundManager.shared.displayName(for: soundId.wrappedValue))
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 180 : 0))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.snappy) {
                    isExpanded.wrappedValue.toggle()
                    // Reset confirming state when opening/closing
                    confirmingSoundId = nil
                }
            }

            // Expanded content
            if isExpanded.wrappedValue {
                VStack(spacing: 16) {
                    // Type selector chips (Sound / Voice Message)
                    HStack(spacing: 0) {
                        ForEach(AlarmSoundType.allCases, id: \.rawValue) { type in
                            Button {
                                withAnimation(.snappy) { soundType.wrappedValue = type }
                            } label: {
                                Text(type.rawValue)
                                    .font(.subheadline.weight(soundType.wrappedValue == type ? .semibold : .regular))
                                    .foregroundStyle(soundType.wrappedValue == type ? .white : .primary)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(soundType.wrappedValue == type ? accentColor : Color.clear)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    // Sound content or Voice placeholder
                    if soundType.wrappedValue == .sound {
                        // Category selector chips (iOS / Motivational / Holiday)
                        HStack(spacing: 0) {
                            ForEach(SoundManager.SoundCategory.allCases) { category in
                                Button {
                                    withAnimation(.snappy) { selectedSoundCategory = category }
                                } label: {
                                    Text(category.displayName)
                                        .font(.subheadline.weight(selectedSoundCategory == category ? .semibold : .regular))
                                        .foregroundStyle(selectedSoundCategory == category ? .white : (category.isAvailable ? .primary : .secondary))
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 16)
                                        .background(selectedSoundCategory == category ? accentColor : Color.clear)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)

                        // Sound grid for selected category
                        if selectedSoundCategory.isAvailable {
                            soundGrid(
                                sounds: selectedSoundCategory.sounds,
                                selection: soundId,
                                isExpanded: isExpanded,
                                accentColor: accentColor
                            )
                        } else {
                            // Placeholder for unavailable categories
                            HStack {
                                Image(systemName: "speaker.slash")
                                    .foregroundStyle(.secondary)
                                Text("Coming soon")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, 16)
                        }
                    } else {
                        // Voice Message placeholder
                        HStack {
                            Image(systemName: "mic.fill")
                                .foregroundStyle(.secondary)
                            Text("Coming soon")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Sound Grid
    @ViewBuilder
    private func soundGrid(
        sounds: [SoundManager.NotificationSoundType],
        selection: Binding<String?>,
        isExpanded: Binding<Bool>,
        accentColor: Color
    ) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(sounds) { sound in
                soundGridItem(
                    name: sound.displayName,
                    identifier: sound.rawValue,
                    selection: selection,
                    isExpanded: isExpanded,
                    accentColor: accentColor
                )
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func soundGridItem(
        name: String,
        identifier: String,
        selection: Binding<String?>,
        isExpanded: Binding<Bool>,
        accentColor: Color
    ) -> some View {
        let isSelected = selection.wrappedValue == identifier
        let isConfirming = confirmingSoundId == identifier

        Button {
            if isConfirming {
                // Second tap: confirm and close
                selection.wrappedValue = identifier
                confirmingSoundId = nil
                withAnimation(.snappy) {
                    isExpanded.wrappedValue = false
                }
            } else {
                // First tap: preview sound and enter confirm state
                confirmingSoundId = identifier
                SoundManager.shared.previewSound(identifier)
            }
        } label: {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(isConfirming || isSelected ? .white : .primary)

                Spacer()

                if isConfirming {
                    // Show "?" to indicate tap again to confirm
                    Image(systemName: "questionmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isConfirming ? accentColor.opacity(0.7) : (isSelected ? accentColor : Color(.systemGray5)))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isConfirming ? accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func chipButton(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String? = nil,
        isPlaceholder: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isPlaceholder ? .secondary : .primary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Result Item
    @ViewBuilder
    private func resultItem(label: String, time: Date, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(timeFormatter.string(from: time))
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
        }
    }
    
    private var transportModeLabel: String {
        switch transportMode {
        case .automobile: return "driving"
        case .walking: return "walking"
        case .cycling: return "biking"
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
    
    // MARK: - Logic
    
    private func loadExistingDeparture() {
        guard let departure = departure else { return }

        label = departure.label
        arrivalTime = departure.targetArrivalTime
        prepDuration = departure.prepDuration
        travelTime = departure.staticTravelTime

        hasPreWakeAlarm = departure.hasPreWakeAlarm
        hasLeaveAlarm = departure.hasLeaveAlarm

        // Load per-alarm sounds
        preWakeSoundId = departure.preWakeSoundId
        wakeSoundId = departure.wakeSoundId
        leaveSoundId = departure.leaveSoundId

        // Load prep time media settings
        if let mediaType = departure.prepTimeMediaType,
           let type = PrepTimeMediaType(rawValue: mediaType) {
            prepTimeMediaType = type
        } else {
            prepTimeMediaType = .silence
        }
        prepTimeMediaId = departure.prepTimeMediaId
        prepTimeMediaName = departure.prepTimeMediaName
        prepTimeMediaArtworkURL = departure.prepTimeMediaArtworkURL

        // Load transport mode
        if let mode = TravelTimeService.TransportMode.allCases.first(where: { $0.rawValue == departure.transportType }) {
            transportMode = mode
        }

        if let destName = departure.destinationName {
            toName = destName
            toAddress = departure.destinationAddress
            if let lat = departure.destinationLat, let lon = departure.destinationLong {
                toCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }

        if let originName = departure.originName {
            fromName = originName
            fromAddress = departure.originAddress
            if let lat = departure.originLat, let lon = departure.originLong {
                fromCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
    }
    
    private func calculateTravelTime() {
        guard let to = toCoordinate, let from = fromCoordinate else { return }
        
        // Guard against same origin/destination
        if abs(from.latitude - to.latitude) < 0.0001 && abs(from.longitude - to.longitude) < 0.0001 {
            travelTime = 0
            return
        }
        
        isLoadingTravel = true
        
        Task {
            if let time = await TravelTimeService.calculateTravelTime(
                from: from,
                to: to,
                transportMode: transportMode
            ) {
                await MainActor.run {
                    isLoadingTravel = false
                    travelTime = time
                }
            } else {
                await MainActor.run {
                    isLoadingTravel = false
                    travelTime = 1200 // 20 min fallback
                }
            }
        }
    }
    
    private func save() {
        let dep = departure ?? Departure(
            label: label.isEmpty ? (toName ?? "Alarm") : label,
            targetArrivalTime: arrivalTime,
            prepDuration: prepDuration,
            staticTravelTime: travelTime
        )
        
        if departure == nil {
            modelContext.insert(dep)
        }
        
        dep.label = label.isEmpty ? (toName ?? "Alarm") : label
        dep.targetArrivalTime = arrivalTime
        dep.prepDuration = prepDuration
        dep.staticTravelTime = travelTime
        
        dep.destinationName = toName
        dep.destinationAddress = toAddress
        dep.destinationLat = toCoordinate?.latitude
        dep.destinationLong = toCoordinate?.longitude

        dep.originName = fromName
        dep.originAddress = fromAddress
        dep.originLat = fromCoordinate?.latitude
        dep.originLong = fromCoordinate?.longitude

        dep.hasPreWakeAlarm = hasPreWakeAlarm
        dep.hasLeaveAlarm = hasLeaveAlarm
        dep.transportType = transportMode.rawValue

        // Save per-alarm sounds
        dep.preWakeSoundId = preWakeSoundId
        dep.wakeSoundId = wakeSoundId
        dep.leaveSoundId = leaveSoundId

        // Save prep time media settings
        dep.prepTimeMediaType = prepTimeMediaType == .silence ? nil : prepTimeMediaType.rawValue
        dep.prepTimeMediaId = prepTimeMediaId
        dep.prepTimeMediaName = prepTimeMediaName
        dep.prepTimeMediaArtworkURL = prepTimeMediaArtworkURL

        // Debug logging AFTER all assignments
        print("----- DEBUG: SAVING DEPARTURE -----")
        print("State vars - toCoordinate: \(String(describing: toCoordinate))")
        print("State vars - fromCoordinate: \(String(describing: fromCoordinate))")
        print("Departure - destinationLat: \(String(describing: dep.destinationLat))")
        print("Departure - originLat: \(String(describing: dep.originLat))")
        dump(dep)
        print("-----------------------------------")

        // Explicitly save to SwiftData before dismissing
        do {
            try modelContext.save()
            print("SwiftData: Departure saved successfully - \(dep.label)")
        } catch {
            print("SwiftData: Failed to save departure: \(error)")
            return  // Don't dismiss if save failed
        }

        // Schedule alarms with AlarmKit
        Task {
            do {
                try await AlarmKitManager.shared.scheduleAlarms(for: dep)
            } catch {
                print("Failed to schedule alarms: \(error)")
            }
        }

        dismiss()
    }

    // MARK: - DEBUG Quick Test
    #if DEBUG
    @ViewBuilder
    private var debugQuickTestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.vertical, 8)

            Text("DEBUG: Quick Test")
                .font(.headline)
                .foregroundStyle(.red)

            HStack(spacing: 12) {
                Text("Fire wake alarm in:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Minutes", selection: $debugMinutesFromNow) {
                    ForEach([1, 2, 3, 5], id: \.self) { min in
                        Text("\(min) min").tag(min)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            Button {
                applyDebugTiming()
            } label: {
                HStack {
                    Image(systemName: "clock.badge.exclamationmark.fill")
                    Text("Set Times for Quick Test")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Text("Sets arrival time so wake alarm fires in \(debugMinutesFromNow) min. Fill locations first!")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func applyDebugTiming() {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("DEBUG QUICK TEST - APPLYING TIMING")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Current time: \(formatter.string(from: now))")
        print("Minutes from now: \(debugMinutesFromNow)")
        print("Prep duration: \(Int(prepDuration / 60)) min")
        print("Travel time: \(Int(travelTime / 60)) min")

        let targetWakeTime = now.addingTimeInterval(TimeInterval(debugMinutesFromNow * 60))
        print("Target wake time: \(formatter.string(from: targetWakeTime))")

        // arrivalTime = wakeUpTime + prepDuration + travelTime
        let calculatedArrival = targetWakeTime
            .addingTimeInterval(prepDuration)
            .addingTimeInterval(travelTime)

        arrivalTime = calculatedArrival
        print("Calculated arrival time: \(formatter.string(from: calculatedArrival))")

        // Also enable all alarms for full sequence test
        hasPreWakeAlarm = true
        hasLeaveAlarm = true

        print("Enabled: Pre-wake alarm, Wake alarm, Leave alarm")
        print("Sounds configured:")
        print("   Pre-wake: \(preWakeSoundId ?? "default")")
        print("   Wake: \(wakeSoundId ?? "default")")
        print("   Leave: \(leaveSoundId ?? "default")")
        print("Prep music: \(prepTimeMediaType.rawValue) - \(prepTimeMediaName ?? "none")")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Now tap SAVE to schedule the alarms!")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    #endif
}

#Preview {
    DepartureWizardView()
        .environment(LocationManager())
}
