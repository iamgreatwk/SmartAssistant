import Foundation

/// 从 expressions.json 加载的表情/交互配置
struct ExpressionConfig: Codable {
    let moods: [String: MoodConfig]
    let emotionKeywords: [String: [String]]
    let emotionClusters: [String: [String]]
    let emotionToSequence: [String: String]
    let sequences: [String: [SeqConfig]]
    let petEmpathy: [String: String]
    let commands: [String: CommandConfig]
    let soundMap: [String: String]
    let idleExpressions: [String]
    let listeningExpressions: [String]
    let thinkingExpressions: [String]
    let negativeEmotions: [String]
    let shake: ShakeConfig
    let knock: KnockConfig
    var speakingDurationSec: Double = 5.0
    var speakingCycleIntervalSec: Double = 3.0
    var commandDurationSec: Double = 3.0
    var errorRecoverSec: Double = 4.0
    var expressionEnrichIntervalSec: Double = 1.5
    let sensorTriggers: [String: SensorTriggerConfig]
    let camera: CameraConfig
    
    struct CameraConfig: Codable {
        let enabled: Bool
        let autoCapture: Bool
        let captureDelaySec: Double
        let modes: [String]
        let defaultMode: String
        let commands: [String: CameraCommandConfig]
        let faceTriggers: [String: SensorTriggerConfig]
    }
    
    struct CameraCommandConfig: Codable {
        let mode: String
        let e: String
        let s: String?
    }
    
    struct SensorTriggerConfig: Codable {
        let e: String         // 表情名
        let s: String?        // 音效名（可选）
        let t: Double         // 持续时间（秒）
        // 触发条件（根据类型不同，只有部分字段有效）
        let pitch: Double?     // 俯仰角度阈值（°）
        let roll: Double?      // 横滚角度阈值（°）
        let gyroRate: Double?  // 陀螺仪角速度阈值（°/s）
        let speedKmh: Double?  // GPS速度阈值（km/h）
        let accelBelow: Double? // 加速度低于此值（G）
        let stillSeconds: Double?
        let luxBelow: Double?
        let altChange: Double?
        let stepsPerMin: Int?
        let proximity: Bool?
        let tempAbove: Double?
    }
    
    // MARK: - 子结构
    
    struct MoodConfig: Codable {
        let eyeW: CGFloat
        let eyeH: CGFloat
        let br: CGFloat
        let sb: CGFloat
        let lT: CGFloat; let rT: CGFloat   // tired
        let lA: CGFloat; let rA: CGFloat   // angry
        let lH: CGFloat; let rH: CGFloat   // happy
        let lF: CGFloat; let rF: CGFloat   // flat
        let lM: CGFloat; let rM: CGFloat   // heightMul
        let yo: CGFloat                    // yOffset
    }
    
    struct SeqConfig: Codable {
        let e: String       // expression name
        let x: CGFloat?     // lookX
        let y: CGFloat?     // lookY
        let b: Bool?        // isBlink
    }
    
    struct CommandConfig: Codable {
        let e: String   // expression
        let c: String   // command id
    }
    
    struct ShakeConfig: Codable {
        let e: String
        let s: String
        var threshold: Double = 1.2
        var spikeCount: Int = 2
        var dizzySeconds: Double = 3.0
    }
    
    struct KnockConfig: Codable {
        let e: String
        let s: String
        let lx: CGFloat?
        let ly: CGFloat?
        var threshold: Double = 0.5
        var recoverSeconds: Double = 0.6
    }
    
    // MARK: - 加载（Documents 优先，可热更新）
    
    static let shared: ExpressionConfig = {
        // 1. 先检查 Documents 目录是否有自定义 JSON
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let docsURL = docsDir.appendingPathComponent("expressions.json")
        
        if FileManager.default.fileExists(atPath: docsURL.path),
           let data = try? Data(contentsOf: docsURL),
           let config = try? JSONDecoder().decode(ExpressionConfig.self, from: data) {
            print("✅ 使用 Documents/expressions.json")
            return config
        }
        
        // 2. 回退到 Bundle 内置版本
        guard let url = Bundle.main.url(forResource: "expressions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(ExpressionConfig.self, from: data) else {
            fatalError("无法加载 expressions.json")
        }
        return config
    }()
    
    // MARK: - 查询方法
    
    /// 情绪关键词 → ExpressionType
    func detectEmotion(from text: String) -> String? {
        let t = text.lowercased()
        for (emotion, keywords) in emotionKeywords {
            for kw in keywords {
                if t.contains(kw) { return emotion }
            }
        }
        return nil
    }
    
    /// 用户情绪 → 宠物回应情绪
    func empathy(for userMood: String) -> String? {
        return petEmpathy[userMood]
    }
    
    /// 情绪 → 动画序列名
    func sequenceName(for emotion: String) -> String? {
        return emotionToSequence[emotion]
    }
    
    /// 情绪 → 表情循环簇
    func cluster(for emotion: String) -> [String] {
        return emotionClusters[emotion] ?? ["speaking", "normal", "speaking"]
    }
    
    /// 指令检测
    func detectCommand(_ text: String) -> (expression: String, command: String)? {
        let t = text.lowercased()
        for (keyword, cmd) in commands {
            if t.contains(keyword) { return (cmd.e, cmd.c) }
        }
        return nil
    }
    
    /// 序列 → SeqStep 数组
    func sequenceSteps(for name: String) -> [ExpressionType.SeqStep]? {
        guard let steps = sequences[name] else { return nil }
        return steps.map { s in
            ExpressionType.SeqStep(
                expr: ExpressionType(rawValue: s.e) ?? .normal,
                lx: s.x ?? 0,
                ly: s.y ?? 0,
                blink: s.b ?? false
            )
        }
    }
    
    /// 情绪名数组 → ExpressionType 数组
    func expressionArray(from names: [String]) -> [ExpressionType] {
        return names.compactMap { ExpressionType(rawValue: $0) }
    }
}
