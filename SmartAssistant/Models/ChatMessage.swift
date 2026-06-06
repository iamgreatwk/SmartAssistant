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
    var voiceIdentifier: String = "zh-CN"  // 语音标识
    var preUtteranceDelay: TimeInterval = 0.0
    var postUtteranceDelay: TimeInterval = 0.0
}

// MARK: - 应用配置

struct AppConfig: Codable {
    var aiApiEndpoint: String = "https://api.openai.com/v1/chat/completions"
    var aiApiKey: String = ""
    var aiModel: String = "gpt-4o"
    var systemPrompt: String = """
    你是一个智能助手，名叫"小智"。你可以通过用户的 iPhone 传感器感知环境。
    你的回复应该简洁、友好、有帮助。用中文回复。
    当用户提到传感器数据时，你可以根据上下文进行分析。
    你的性格设定：活泼、好奇、有点幽默感。
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
