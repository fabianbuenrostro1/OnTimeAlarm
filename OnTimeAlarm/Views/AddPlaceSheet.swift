import SwiftUI
import CoreLocation
import SwiftData
import MapKit

enum AddPlaceStep: Int, CaseIterable {
    case location = 0
    case name = 1
    case icon = 2

    var title: String {
        switch self {
        case .location: return "Where?"
        case .name: return "Name it"
        case .icon: return "Pick an icon"
        }
    }
}

struct AddPlaceSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Step state
    @State private var currentStep: AddPlaceStep = .location
    @State private var isNavigatingForward = true

    // Data state
    @State private var name: String = ""
    @State private var selectedIcon: String = "📍"
    @State private var address: String = ""
    @State private var coordinate: CLLocationCoordinate2D?

    // Search state
    @State private var searchService = LocationSearchService()
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isNameFocused: Bool

    // Placeholder cycling for name
    @State private var placeholderIndex = 0
    private let placeholders = ["Home", "Work", "Gym", "School"]
    private let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    // Emoji options
    private let emojiOptions = ["🏠", "💼", "💪", "🎓", "🛒", "☕️", "🍔", "🍻", "🏥", "✈️", "❤️", "📍", "🌳", "🏖️", "🎉"]

    // Map camera position
    @State private var cameraPosition: MapCameraPosition = .automatic

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && coordinate != nil
    }

    var body: some View {
        GeometryReader { geometry in
            let cardHeight: CGFloat = 400

            ZStack(alignment: .bottom) {
                // MARK: - Hero Map
                Map(position: $cameraPosition) {
                    if let coord = coordinate {
                        Annotation("", coordinate: coord) {
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                                Text(selectedIcon)
                                    .font(.title)
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls {
                    MapCompass()
                }
                .ignoresSafeArea()
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: cardHeight)
                }

                // MARK: - Bottom Card
                VStack(spacing: 0) {
                    // Drag indicator
                    Capsule()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)
                        .padding(.bottom, 8)

                    // Custom header row
                    HStack {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(.blue)
                        Spacer()
                        Text("New Place")
                            .font(.headline)
                        Spacer()
                        // Invisible balance element
                        Text("Cancel").opacity(0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    // Step indicator
                    stepIndicator
                        .padding(.bottom, 16)

                    // Step content
                    VStack(spacing: 16) {
                        // Step title
                        Text(currentStep.title)
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Step content (with transitions)
                        ZStack {
                            switch currentStep {
                            case .location:
                                locationStepContent
                                    .transition(stepTransition)
                            case .name:
                                nameStepContent
                                    .transition(stepTransition)
                            case .icon:
                                iconStepContent
                                    .transition(stepTransition)
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.background)
                        .shadow(color: .black.opacity(0.12), radius: 20, y: -5)
                )
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(stepColor(for: index))
                    .frame(width: index == currentStep.rawValue ? 10 : 8,
                           height: index == currentStep.rawValue ? 10 : 8)
                    .animation(.spring(response: 0.3), value: currentStep)
            }
        }
    }

    private func stepColor(for index: Int) -> Color {
        if index < currentStep.rawValue {
            return .blue // Completed
        } else if index == currentStep.rawValue {
            return .blue // Current
        } else {
            return .secondary.opacity(0.3) // Future
        }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: isNavigatingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: isNavigatingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    // MARK: - Step 1: Location

    @ViewBuilder
    private var locationStepContent: some View {
        VStack(spacing: 12) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 16, weight: .medium))

                TextField("Search for a place", text: $searchService.searchQuery)
                    .font(.subheadline)
                    .focused($isSearchFocused)
                    .submitLabel(.search)

                if !searchService.searchQuery.isEmpty {
                    Button {
                        searchService.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Results
            if searchService.searchQuery.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("Search for a place")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else if searchService.results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "mappin.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No results found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(searchService.results.prefix(5), id: \.self) { result in
                            Button {
                                selectSearchResult(result)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)

                            if result != searchService.results.prefix(5).last {
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: 160)
            }
        }
    }

    // MARK: - Step 2: Name

    @ViewBuilder
    private var nameStepContent: some View {
        VStack(spacing: 20) {
            // Selected location preview
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(address.isEmpty ? "Location selected" : address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Name input
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .leading) {
                    if name.isEmpty {
                        Text(placeholders[placeholderIndex])
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                            .id("placeholder-\(placeholderIndex)")
                    }

                    TextField("", text: $name)
                        .font(.system(size: 32, weight: .medium))
                        .textFieldStyle(.plain)
                        .focused($isNameFocused)
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: placeholderIndex)
                .onReceive(timer) { _ in
                    if name.isEmpty && !isNameFocused {
                        withAnimation {
                            placeholderIndex = (placeholderIndex + 1) % placeholders.count
                        }
                    }
                }
            }
            .frame(minHeight: 60)

            Spacer()

            // Navigation buttons
            HStack {
                Button {
                    navigateBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                        Text("Back")
                    }
                    .foregroundStyle(.blue)
                }

                Spacer()

                Button {
                    navigateForward()
                } label: {
                    HStack(spacing: 4) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(!name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.blue : Color(.systemGray5))
                    .foregroundStyle(!name.trimmingCharacters(in: .whitespaces).isEmpty ? .white : .secondary)
                    .clipShape(Capsule())
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isNameFocused = true
            }
        }
    }

    // MARK: - Step 3: Icon

    @ViewBuilder
    private var iconStepContent: some View {
        VStack(spacing: 20) {
            // Preview
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 56, height: 56)
                    Text(selectedIcon)
                        .font(.system(size: 32))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.headline)
                    Text(address.isEmpty ? "Location selected" : address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Emoji grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                ForEach(emojiOptions, id: \.self) { emoji in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedIcon = emoji
                        }
                    } label: {
                        Text(emoji)
                            .font(.system(size: 32))
                            .frame(width: 52, height: 52)
                            .background(
                                Circle()
                                    .fill(selectedIcon == emoji ? Color.blue.opacity(0.15) : Color(.systemGray6))
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(selectedIcon == emoji ? Color.blue : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Navigation buttons
            HStack {
                Button {
                    navigateBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                        Text("Back")
                    }
                    .foregroundStyle(.blue)
                }

                Spacer()

                Button {
                    savePlace()
                } label: {
                    Text("Save Place")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Navigation

    private func navigateForward() {
        isNavigatingForward = true
        withAnimation(.easeInOut(duration: 0.3)) {
            if let nextStep = AddPlaceStep(rawValue: currentStep.rawValue + 1) {
                currentStep = nextStep
            }
        }
    }

    private func navigateBack() {
        isNavigatingForward = false
        withAnimation(.easeInOut(duration: 0.3)) {
            if let prevStep = AddPlaceStep(rawValue: currentStep.rawValue - 1) {
                currentStep = prevStep
            }
        }
    }

    // MARK: - Actions

    private func selectSearchResult(_ result: MKLocalSearchCompletion) {
        Task {
            if let (coord, _, formattedAddress) = await searchService.getCoordinates(for: result) {
                await MainActor.run {
                    coordinate = coord
                    address = formattedAddress
                    searchService.searchQuery = ""
                    isSearchFocused = false

                    // Fly to location
                    withAnimation(.easeInOut(duration: 0.5)) {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        ))
                    }

                    // Navigate to next step
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigateForward()
                    }
                }
            }
        }
    }

    private func savePlace() {
        guard let coord = coordinate else { return }
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let newPlace = SavedPlace(
            name: name,
            icon: selectedIcon,
            address: address,
            latitude: coord.latitude,
            longitude: coord.longitude
        )

        modelContext.insert(newPlace)
        dismiss()
    }
}

#Preview {
    AddPlaceSheet()
        .modelContainer(for: SavedPlace.self, inMemory: true)
}
