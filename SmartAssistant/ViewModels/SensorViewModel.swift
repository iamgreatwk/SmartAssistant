import Foundation
import Combine

/// 传感器 ViewModel — 管理所有传感器数据并生成摘要
@MainActor
class SensorViewModel: ObservableObject {
    
    // MARK: - 传感器数据
    
    @Published var accelerometer: AccelerometerData?
    @Published var gyroscope: GyroscopeData?
    @Published var magnetometer: MagnetometerData?
    @Published var attitude: DeviceAttitude?
    @Published var location: LocationData?
    @Published var isDeviceMoving: Bool = false
    @Published var stepCount: Int = 0
    @Published var heading: Double = 0
    
    // 摄像头/麦克风状态
    @Published var isCameraActive: Bool = false
    @Published var isMicrophoneActive: Bool = false
    @Published var audioLevel: Float = 0
    @Published var sensorsRunning: Bool = false
    
    // 权限状态
    @Published var permissionStatuses: [String: PermissionStatus] = [:]
    
    // MARK: - 服务
    
    private let motionService = MotionService()
    private let locationService = LocationService()
    private let microphoneService = MicrophoneService()
    private let cameraService = CameraService()
    private let permissionManager = PermissionManager()
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初始化
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // 运动传感器
        motionService.$accelerometerData
            .assign(to: \.accelerometer, on: self)
            .store(in: &cancellables)
        
        motionService.$gyroscopeData
            .assign(to: \.gyroscope, on: self)
            .store(in: &cancellables)
        
        motionService.$magnetometerData
            .assign(to: \.magnetometer, on: self)
            .store(in: &cancellables)
        
        motionService.$deviceAttitude
            .assign(to: \.attitude, on: self)
            .store(in: &cancellables)
        
        motionService.$isDeviceMoving
            .assign(to: \.isDeviceMoving, on: self)
            .store(in: &cancellables)
        
        motionService.$stepCount
            .assign(to: \.stepCount, on: self)
            .store(in: &cancellables)
        
        // 位置
        locationService.$currentLocation
            .assign(to: \.location, on: self)
            .store(in: &cancellables)
        
        locationService.$heading
            .assign(to: \.heading, on: self)
            .store(in: &cancellables)
        
        // 麦克风
        microphoneService.$audioLevel
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
        
        microphoneService.$isRecording
            .assign(to: \.isMicrophoneActive, on: self)
            .store(in: &cancellables)
        
        // 摄像头
        cameraService.$isRunning
            .assign(to: \.isCameraActive, on: self)
            .store(in: &cancellables)
        
        // 权限
        permissionManager.$cameraStatus
            .sink { [weak self] status in
                self?.permissionStatuses["摄像头"] = status
            }
            .store(in: &cancellables)
        
        permissionManager.$microphoneStatus
            .sink { [weak self] status in
                self?.permissionStatuses["麦克风"] = status
            }
            .store(in: &cancellables)
        
        permissionManager.$locationStatus
            .sink { [weak self] status in
                self?.permissionStatuses["定位"] = status
            }
            .store(in: &cancellables)
        
        permissionManager.$speechRecognitionStatus
            .sink { [weak self] status in
                self?.permissionStatuses["语音识别"] = status
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 传感器控制
    
    func startAllSensors() {
        motionService.startAllSensors()
        locationService.startUpdatingLocation()
        microphoneService.startMonitoring()
        sensorsRunning = true
    }
    
    func stopAllSensors() {
        motionService.stopAllSensors()
        locationService.stopUpdatingLocation()
        microphoneService.stopMonitoring()
        sensorsRunning = false
    }
    
    func startCamera() {
        cameraService.start()
        isCameraActive = true
    }
    
    func stopCamera() {
        cameraService.stop()
        isCameraActive = false
    }
    
    func capturePhoto() {
        cameraService.capturePhoto()
    }
    
    func switchCamera() {
        cameraService.switchCamera()
    }
    
    // MARK: - 权限
    
    func requestAllPermissions() async {
        await permissionManager.requestAllPermissions()
    }
    
    // MARK: - 综合环境数据
    
    func getEnvironmentData() -> EnvironmentData {
        return EnvironmentData(
            accelerometer: accelerometer,
            gyroscope: gyroscope,
            magnetometer: magnetometer,
            attitude: attitude,
            location: location,
            isCameraActive: isCameraActive,
            isMicrophoneActive: isMicrophoneActive,
            isSpeaking: audioLevel > 0.1
        )
    }
    
    var contextSummary: String {
        getEnvironmentData().contextSummary
    }
}
