import Foundation
import AVFoundation
import CoreLocation
import CoreMotion
import Speech
import Photos

/// 权限管理器 — 统一管理所有传感器和硬件权限
class PermissionManager: ObservableObject {
    
    @Published var cameraStatus: PermissionStatus = .notDetermined
    @Published var microphoneStatus: PermissionStatus = .notDetermined
    @Published var speechRecognitionStatus: PermissionStatus = .notDetermined
    @Published var locationStatus: PermissionStatus = .notDetermined
    @Published var photoLibraryStatus: PermissionStatus = .notDetermined
    
    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionActivityManager()
    
    // MARK: - 摄像头权限
    
    func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            await MainActor.run { cameraStatus = .authorized }
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run { cameraStatus = granted ? .authorized : .denied }
            return granted
        case .denied:
            await MainActor.run { cameraStatus = .denied }
            return false
        case .restricted:
            await MainActor.run { cameraStatus = .restricted }
            return false
        @unknown default:
            return false
        }
    }
    
    // MARK: - 麦克风权限
    
    func requestMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            await MainActor.run { microphoneStatus = .authorized }
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            await MainActor.run { microphoneStatus = granted ? .authorized : .denied }
            return granted
        case .denied:
            await MainActor.run { microphoneStatus = .denied }
            return false
        case .restricted:
            await MainActor.run { microphoneStatus = .restricted }
            return false
        @unknown default:
            return false
        }
    }
    
    // MARK: - 语音识别权限
    
    func requestSpeechRecognitionPermission() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
            await MainActor.run { speechRecognitionStatus = .authorized }
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    Task { @MainActor in
                        self.speechRecognitionStatus = status == .authorized ? .authorized : .denied
                        continuation.resume(returning: status == .authorized)
                    }
                }
            }
        case .denied:
            await MainActor.run { speechRecognitionStatus = .denied }
            return false
        case .restricted:
            await MainActor.run { speechRecognitionStatus = .restricted }
            return false
        @unknown default:
            return false
        }
    }
    
    // MARK: - 定位权限
    
    func requestLocationPermission() {
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationStatus = .authorized
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            locationStatus = .notDetermined
        case .denied:
            locationStatus = .denied
        case .restricted:
            locationStatus = .restricted
        @unknown default:
            break
        }
    }
    
    func updateLocationStatus(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationStatus = .authorized
        case .denied:
            locationStatus = .denied
        case .restricted:
            locationStatus = .restricted
        case .notDetermined:
            locationStatus = .notDetermined
        @unknown default:
            break
        }
    }
    
    // MARK: - 相册权限
    
    func requestPhotoLibraryPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            await MainActor.run { photoLibraryStatus = .authorized }
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            await MainActor.run { photoLibraryStatus = newStatus == .authorized ? .authorized : .denied }
            return newStatus == .authorized
        case .denied:
            await MainActor.run { photoLibraryStatus = .denied }
            return false
        case .restricted:
            await MainActor.run { photoLibraryStatus = .restricted }
            return false
        @unknown default:
            return false
        }
    }
    
    // MARK: - 请求所有权限
    
    func requestAllPermissions() async {
        _ = await requestCameraPermission()
        _ = await requestMicrophonePermission()
        _ = await requestSpeechRecognitionPermission()
        requestLocationPermission()
        _ = await requestPhotoLibraryPermission()
    }
    
    // MARK: - 打开系统设置
    
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
