import Foundation
import CoreLocation

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var userLocation: CLLocationCoordinate2D?
    var isLoading = false
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }
    
    // MARK: - Public Methods
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        isLoading = true
        manager.requestLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        isLoading = false
        userLocation = locations.first?.coordinate
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
        print("Location error: \(error.localizedDescription)")
    }
}
