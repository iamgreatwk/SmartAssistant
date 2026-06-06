import CoreLocation
import Combine

/// 定位服务 — GPS 定位、方向、速度
class LocationService: NSObject, ObservableObject {
    
    @Published var currentLocation: LocationData?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isUpdatingLocation = false
    @Published var locationError: String?
    @Published var heading: Double = 0  // 方向角（度）
    
    private let locationManager = CLLocationManager()
    
    // 模拟坐标（用于开发测试）
    private let useSimulatedLocation: Bool = false
    private let simulatedLatitude: Double = 39.9042   // 北京
    private let simulatedLongitude: Double = 116.4074
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10  // 10米更新一次
        locationManager.headingFilter = 5    // 5度更新一次
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    // MARK: - 开始/停止定位
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        
        DispatchQueue.main.async { self.isUpdatingLocation = true }
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        
        DispatchQueue.main.async { self.isUpdatingLocation = false }
    }
    
    // MARK: - 单次定位
    
    func requestSingleLocation() async -> LocationData? {
        if useSimulatedLocation {
            return LocationData(
                latitude: simulatedLatitude,
                longitude: simulatedLongitude,
                altitude: 50,
                speed: 0,
                course: 0,
                timestamp: Date()
            )
        }
        
        return currentLocation
    }
    
    // MARK: - 计算距离
    
    func distance(from: LocationData, to: LocationData) -> CLLocationDistance {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2)
    }
    
    // MARK: - 反向地理编码
    
    func reverseGeocode(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            
            var address: [String] = []
            if let country = placemark.country { address.append(country) }
            if let locality = placemark.locality { address.append(locality) }
            if let subLocality = placemark.subLocality { address.append(subLocality) }
            if let thoroughfare = placemark.thoroughfare { address.append(thoroughfare) }
            
            return address.joined(separator: " ")
        } catch {
            print("反向地理编码失败: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            locationError = "定位权限被拒绝，请在设置中开启"
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let data = LocationData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            speed: location.speed >= 0 ? location.speed : 0,
            course: location.course >= 0 ? location.course : 0,
            timestamp: location.timestamp
        )
        
        DispatchQueue.main.async { self.currentLocation = data }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { self.locationError = error.localizedDescription }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async { self.heading = newHeading.trueHeading }
    }
}
