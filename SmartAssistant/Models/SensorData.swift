import Foundation
import CoreMotion
import CoreLocation

// MARK: - 传感器数据模型

/// 加速度计数据
struct AccelerometerData {
    let x: Double
    let y: Double
    let z: Double
    let timestamp: Date
    
    var magnitude: Double {
        sqrt(x * x + y * y + z * z)
    }
    
    var isMoving: Bool {
        magnitude > 1.2 // 超过重力加速度+阈值表示在移动
    }
}

/// 陀螺仪数据
struct GyroscopeData {
    let x: Double
    let y: Double
    let z: Double
    let timestamp: Date
}

/// 磁力计数据
struct MagnetometerData {
    let x: Double
    let y: Double
    let z: Double
    let timestamp: Date
}

/// 设备姿态数据
struct DeviceAttitude {
    let roll: Double
    let pitch: Double
    let yaw: Double
    let timestamp: Date
    
    var orientation: String {
        let absPitch = abs(pitch)
        let absRoll = abs(roll)
        
        if absPitch < 0.5 && absRoll < 0.5 {
            return "平放"
        } else if pitch < -0.8 {
            return "竖直"
        } else if pitch > 0.8 {
            return "倒置"
        } else if roll > 0.8 {
            return "左倾"
        } else if roll < -0.8 {
            return "右倾"
        }
        return "倾斜"
    }
}

/// 位置数据
struct LocationData {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let speed: Double
    let course: Double
    let timestamp: Date
    
    var coordinateString: String {
        String(format: "%.6f, %.6f", latitude, longitude)
    }
    
    var speedKMH: Double {
        speed * 3.6 // m/s 转 km/h
    }
}

/// 环境数据（综合传感器读数）
struct EnvironmentData {
    var accelerometer: AccelerometerData?
    var gyroscope: GyroscopeData?
    var magnetometer: MagnetometerData?
    var attitude: DeviceAttitude?
    var location: LocationData?
    var isCameraActive: Bool = false
    var isMicrophoneActive: Bool = false
    var isSpeaking: Bool = false
    
    /// 生成传感器状态摘要，用于 AI 上下文
    var contextSummary: String {
        var parts: [String] = []
        
        if let accel = accelerometer {
            parts.append("加速度: x=\(String(format: "%.2f", accel.x)), y=\(String(format: "%.2f", accel.y)), z=\(String(format: "%.2f", accel.z))")
            parts.append(accel.isMoving ? "设备正在移动" : "设备静止")
        }
        
        if let att = attitude {
            parts.append("姿态: \(att.orientation) (roll:\(String(format: "%.1f", att.roll)), pitch:\(String(format: "%.1f", att.pitch)))")
        }
        
        if let loc = location {
            parts.append("位置: \(loc.coordinateString), 速度: \(String(format: "%.1f", loc.speedKMH))km/h")
        }
        
        return parts.joined(separator: "; ")
    }
}

// MARK: - 权限状态

enum PermissionStatus {
    case notDetermined
    case authorized
    case denied
    case restricted
    
    var description: String {
        switch self {
        case .notDetermined: return "未请求"
        case .authorized: return "已授权"
        case .denied: return "已拒绝"
        case .restricted: return "受限制"
        }
    }
}
