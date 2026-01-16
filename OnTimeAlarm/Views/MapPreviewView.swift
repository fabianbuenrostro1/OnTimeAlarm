import SwiftUI
import MapKit

/// A non-interactive map preview showing the route from origin to destination
struct MapPreviewView: View {
    let originCoordinate: CLLocationCoordinate2D?
    let destinationCoordinate: CLLocationCoordinate2D?
    let transportType: MKDirectionsTransportType
    let onTap: () -> Void
    
    @State private var route: MKRoute?
    @State private var region: MKCoordinateRegion = .init()
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Map {
                // Origin marker
                if let origin = originCoordinate {
                    Annotation("", coordinate: origin) {
                        ZStack {
                            Circle()
                                .fill(.blue)
                                .frame(width: 24, height: 24)
                            Circle()
                                .fill(.white)
                                .frame(width: 10, height: 10)
                        }
                    }
                }
                
                // Destination marker with white backing
                if let destination = destinationCoordinate {
                    Annotation("", coordinate: destination) {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 32, height: 32)
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                // Route polyline
                if let route = route {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 4)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .disabled(true) // Non-interactive
            
            // Loading overlay
            if isLoading && originCoordinate != nil && destinationCoordinate != nil {
                ProgressView()
                    .scaleEffect(1.2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
            
            // Empty state
            if originCoordinate == nil || destinationCoordinate == nil {
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Set origin and destination")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGray6))
            }
            
            // Tap hint overlay (bottom-right)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Label("Open Maps", systemImage: "arrow.up.forward.app")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.trailing, 10)
                .padding(.bottom, 10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .task {
            await calculateRoute()
        }
        .onChange(of: originCoordinate?.latitude) { _, _ in
            Task { await calculateRoute() }
        }
        .onChange(of: destinationCoordinate?.latitude) { _, _ in
            Task { await calculateRoute() }
        }
    }
    
    private func calculateRoute() async {
        guard let origin = originCoordinate, let destination = destinationCoordinate else {
            isLoading = false
            return
        }
        
        isLoading = true
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = transportType
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            if let firstRoute = response.routes.first {
                withAnimation {
                    route = firstRoute
                    
                    // Fit map to show entire route with padding
                    let rect = firstRoute.polyline.boundingMapRect
                    let paddedRect = rect.insetBy(dx: -rect.width * 0.2, dy: -rect.height * 0.2)
                    region = MKCoordinateRegion(paddedRect)
                    isLoading = false
                }
            }
        } catch {
            print("Route calculation error: \(error.localizedDescription)")
            isLoading = false
        }
    }
}

#Preview {
    MapPreviewView(
        originCoordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        destinationCoordinate: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.2712),
        transportType: .automobile,
        onTap: {}
    )
    .frame(height: 200)
    .padding()
}
