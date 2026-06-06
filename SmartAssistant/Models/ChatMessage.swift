import Foundation

// MARK: - 聊天消息模型

enum ChatRole: String, Codable {
    case user
    case assistant
    case system
}

enum MessageType: String, Codable {
    case text
    case voice
    case image
    case sensor
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: ChatRole
    let type: MessageType
    var content: String
    let timestamp: Date
    var expression: ExpressionType?
    
    init(
        id: UUID = UUID(),
        role: ChatRole,
        type: MessageType = .text,
        content: String,
        timestamp: Date = Date(),
        expression: ExpressionType? = nil
    ) {
        self.id = id
        self.role = role
        self.type = type
        self.content = content
        self.timestamp = timestamp
        self.expression = expression
    }
}

// MARK: - AI 对话请求/响应

struct ChatRequest: Codable {
    let messages: [ChatRequestMessage]
    let sensorContext: String?
    let model: String
    
    struct ChatRequestMessage: Codable {
        let role: String
        let content: String
    }
}

struct ChatResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct Message: Codable {
        let role: String
        let content: String
    }
}

// MARK: - TTS 配置

struct TTSConfig {
    var rate: Float = 0.5        // 语速 0.0-1.0
    var pitch: Float = 1.0       // 音高 0.5-2.0
    var volume: Float = 1.0      // 音量 0.0-1.0
    var voiceIdentifier: String = "com.apple.ttsbundle.TingTing-compact"  // 语音标识
    var preUtteranceDelay: TimeInterval = 0.0
    var postUtteranceDelay: TimeInterval = 0.0
}

// MARK: - 应用配置

struct AppConfig: Codable {
    var aiApiEndpoint: String = "http://192.168.1.10:1235/v1/chat/completions"
    var aiApiKey: String = "lm-studio"
    var aiModel: String = "gemma-4-e4b-it-qat"
    var systemPrompt: String = """
    你是桌面机器人"小智"，通过表情和语音与人互动。
    
    回复铁律：
    - 每次回复不超过 30 字，通常 1 句话就够了
    - 口语化，多用语气词：嗯！哇！哈哈！诶？好吧...
    - 禁止列举、禁止长篇解释、禁止说"首先/其次/最后"
    - 禁止使用任何 emoji 表情符号，情绪通过你的表情画面体现
    - 把情绪放在表情里而不是文字里
    
    性格：活泼好奇、偶尔犯傻的小机器人。
    """
    var wakeWord: String = "小智"
    var autoListen: Bool = true
    var showSensorDashboard: Bool = true
    var enableExpression: Bool = true
    
    static func load() -> AppConfig {
        guard let data = UserDefaults.standard.data(forKey: "appConfig"),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return AppConfig()
        }
        return config
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "appConfig")
        }
    }
}
