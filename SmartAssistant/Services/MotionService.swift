import CoreMotion
import Combine

/// 运动传感器服务 — 加速度计、陀螺仪、磁力计、设备姿态
class MotionService: ObservableObject {
    
    @Published var accelerometerData: AccelerometerData?
    @Published var gyroscopeData: GyroscopeData?
    @Published var magnetometerData: MagnetometerData?
    @Published var deviceAttitude: DeviceAttitude?
    @Published var isDeviceMoving: Bool = false
    @Published var stepCount: Int = 0
    
    private let motionManager = CMMotionManager()
    private let pedometer = CMPedometer()
    
    private var updateInterval: TimeInterval = 1.0 / 60.0  // 60Hz
    
    // MARK: - 启动所有传感器
    
    func startAllSensors() {
        startAccelerometer()
        startGyroscope()
        startMagnetometer()
        startDeviceMotion()
        startPedometer()
    }
    
    func stopAllSensors() {
        stopAccelerometer()
        stopGyroscope()
        stopMagnetometer()
        stopDeviceMotion()
        stopPedometer()
    }
    
    // MARK: - 加速度计
    
    func startAccelerometer() {
        guard motionManager.isAccelerometerAvailable else { return }
        
        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let data = data else { return }
            let accel = AccelerometerData(
                x: data.acceleration.x,
                y: data.acceleration.y,
                z: data.acceleration.z,
                timestamp: Date()
            )
            self?.accelerometerData = accel
            self?.isDeviceMoving = accel.isMoving
        }
    }
    
    func stopAccelerometer() {
        motionManager.stopAccelerometerUpdates()
        accelerometerData = nil
    }
    
    // MARK: - 陀螺仪
    
    func startGyroscope() {
        guard motionManager.isGyroAvailable else { return }
        
        motionManager.gyroUpdateInterval = updateInterval
        motionManager.startGyroUpdates(to: .main) { [weak self] data, error in
            guard let data = data else { return }
            self?.gyroscopeData = GyroscopeData(
                x: data.rotationRate.x,
                y: data.rotationRate.y,
                z: data.rotationRate.z,
                timestamp: Date()
            )
        }
    }
    
    func stopGyroscope() {
        motionManager.stopGyroUpdates()
        gyroscopeData = nil
    }
    
    // MARK: - 磁力计
    
    func startMagnetometer() {
        guard motionManager.isMagnetometerAvailable else { return }
        
        motionManager.magnetometerUpdateInterval = updateInterval
        motionManager.startMagnetometerUpdates(to: .main) { [weak self] data, error in
            guard let data = data else { return }
            self?.magnetometerData = MagnetometerData(
                x: data.magneticField.x,
                y: data.magneticField.y,
                z: data.magneticField.z,
                timestamp: Date()
            )
        }
    }
    
    func stopMagnetometer() {
        motionManager.stopMagnetometerUpdates()
        magnetometerData = nil
    }
    
    // MARK: - 设备姿态（融合数据）
    
    func startDeviceMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
            guard let data = data else { return }
            let attitude = DeviceAttitude(
                roll: data.attitude.roll,
                pitch: data.attitude.pitch,
                yaw: data.attitude.yaw,
                timestamp: Date()
            )
            self?.deviceAttitude = attitude
        }
    }
    
    func stopDeviceMotion() {
        motionManager.stopDeviceMotionUpdates()
        deviceAttitude = nil
    }
    
    // MARK: - 计步器
    
    func startPedometer() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        
        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let data = data else { return }
            self?.stepCount = data.numberOfSteps.intValue
        }
    }
    
    func stopPedometer() {
        pedometer.stopUpdates()
    }
    
    // MARK: - 震动反馈
    
    func generateHapticFeedback(intensity: Float = 1.0) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred(intensity: CGFloat(intensity))
    }
    
    func generateNotificationHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
