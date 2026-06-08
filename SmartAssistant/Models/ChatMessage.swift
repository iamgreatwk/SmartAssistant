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
    let usage: Usage?
    
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
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

// MARK: - TTS 配置

struct TTSConfig {
    var rate: Float = 0.6          // 语速 0.0-1.0（机器人偏快）
    var pitch: Float = 1.9         // 音高 0.5-2.0（2.0=最高，机器人感最强）
    var volume: Float = 1.0
    var voiceIdentifier: String = "com.apple.voice.enhanced.zh-CN.TingTing"  // 增强版音色
    var preUtteranceDelay: TimeInterval = 0.0
    var postUtteranceDelay: TimeInterval = 0.03
}

// MARK: - 余额信息

struct BalanceInfo: Codable {
    let totalBalance: String
    let chargeBalance: String
    let balance: String
}

// MARK: - 应用配置

struct AppConfig: Codable {
    var aiApiEndpoint: String = "https://api.siliconflow.cn/v1/chat/completions"
    var aiApiKey: String = ""
    var aiModel: String = "deepseek-ai/DeepSeek-V4-Flash"
    var balanceApiEndpoint: String = "https://api.siliconflow.cn/v1/user/info"
    var systemPrompt: String = """
    你是桌面宠物机器人"小智"。只回复一个情绪词表示你此刻的心情。
    
    可用情绪词：normal, happy, veryHappy, excited, surprised, sad, angry, scared, bored, sleepy, love, shy, confused, suspicious, focused, cool, wink
    
    规则：
    - 只回复一个词，如"happy"
    - 不要解释、不要句子、不要标点
    - 根据用户的语气和内容选最贴切的情绪
    
    示例：
    用户"今天好开心" → happy
    用户"好累啊" → sleepy
    用户"气死了" → angry
    用户"哇！" → surprised
    用户"爱你" → love
    """
    var wakeWord: String = "小智"
    var autoListen: Bool = true
    var showSensorDashboard: Bool = true
    var enableExpression: Bool = true
    var debugMode: Bool = false
    
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
