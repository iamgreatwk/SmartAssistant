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
    var lookShiftRange: LookShiftRange?
    
    struct LookShiftRange: Codable {
        var horizontal: Double = 0.3
        var vertical: Double = 0.3
    }
    var maxHistoryCount: Int = 20
    var requestTimeoutSec: Double = 30
    var resourceTimeoutSec: Double = 60
    let defaultLooks: [String: LookConfig]?
    let lookRanges: LookRanges?
    
    struct LookConfig: Codable {
        let x: Double
        let y: Double
    }
    
    struct LookRanges: Codable {
        let idleX: [Double]
        let idleY: [Double]
        let speakingX: [Double]
        let speakingY: [Double]
    }
    
    struct ComfortConfig: Codable {
        let sequence: String
        let expression: String
    }
    
    struct ErrorResponseConfig: Codable {
        let expression: String
        let sequence: String
        let sound: String
    }
    
    let sensorTriggers: [String: SensorTriggerConfig]
    var commandSequence: String = "excited"
    var responseDelaySec: Double = 3.5
    let comfort: ComfortConfig?
    let errorResponse: ErrorResponseConfig?
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
        let t: Double?      // frame time in ms (default: 350)
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
        if let url = Bundle.main.url(forResource: "expressions", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let config = try? JSONDecoder().decode(ExpressionConfig.self, from: data) {
            return config
        }
        
        // 3. 最终兜底：内置默认配置（不依赖 JSON 文件）
        print("⚠️ 无法加载 expressions.json，使用内置默认配置")
        return ExpressionConfig.defaultConfig
    }()
    
    // MARK: - 内置默认配置（JSON 缺失时的兜底）
    
    private static let defaultConfig = ExpressionConfig(
        moods: ["normal": MoodConfig(eyeW: 70, eyeH: 58, br: 24, sb: 20, lT: 0, rT: 0, lA: 0, rA: 0, lH: 0, rH: 0, lF: 0, rF: 0, lM: 1, rM: 1, yo: 0)],
        emotionKeywords: ["happy": ["开心"]],
        emotionClusters: ["speaking": ["normal", "speaking"]],
        emotionToSequence: [:],
        sequences: [:],
        petEmpathy: [:],
        commands: [:],
        soundMap: [:],
        idleExpressions: ["normal"],
        listeningExpressions: ["normal"],
        thinkingExpressions: ["normal"],
        negativeEmotions: ["sad"],
        shake: ShakeConfig(e: "confused", s: "dizzy"),
        knock: KnockConfig(e: "surprised", s: "happy", lx: 0, ly: -0.4),
        sensorTriggers: [:],
        camera: CameraConfig(enabled: true, autoCapture: true, captureDelaySec: 0.8, modes: ["photo"], defaultMode: "photo", commands: [:], faceTriggers: [:])
    )
    
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
                blink: s.b ?? false,
                delayMs: s.t ?? 350
            )
        }
    }
    
    /// 情绪名数组 → ExpressionType 数组
    func expressionArray(from names: [String]) -> [ExpressionType] {
        return names.compactMap { ExpressionType(rawValue: $0) }
    }
    
    /// 状态 → 默认视线
    func look(for state: String) -> (CGFloat, CGFloat) {
        guard let l = defaultLooks?[state] else { return (0, 0) }
        return (CGFloat(l.x), CGFloat(l.y))
    }
    
    /// 随机视线范围
    func randomLook(idle: Bool) -> (CGFloat, CGFloat) {
        guard let ranges = lookRanges else {
            return idle ? (CGFloat.random(in: -0.4...0.4), CGFloat.random(in: 0.1...0.3))
                       : (CGFloat.random(in: -0.2...0.2), CGFloat.random(in: -0.25...0.25))
        }
        if idle {
            return (CGFloat.random(in: CGFloat(ranges.idleX[0])...CGFloat(ranges.idleX[1])),
                    CGFloat.random(in: CGFloat(ranges.idleY[0])...CGFloat(ranges.idleY[1])))
        } else {
            return (CGFloat.random(in: CGFloat(ranges.speakingX[0])...CGFloat(ranges.speakingX[1])),
                    CGFloat.random(in: CGFloat(ranges.speakingY[0])...CGFloat(ranges.speakingY[1])))
        }
    }
}
