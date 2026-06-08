import Foundation
import Combine

/// AI 对话服务 — 对接 OpenAI 兼容 API
class AIChatService: ObservableObject {
    
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    private var config: AppConfig
    private var conversationHistory: [ChatRequest.ChatRequestMessage] = []
    private let maxHistoryCount = 20
    
    private let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()
    
    init(config: AppConfig = .load()) {
        self.config = config
        self.conversationHistory = [
            ChatRequest.ChatRequestMessage(role: "system", content: config.systemPrompt)
        ]
    }
    
    // MARK: - 发送消息
    
    func sendMessage(_ text: String, sensorContext: String? = nil) async throws -> (text: String, tokens: Int) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            return ("", 0)
        }
        
        guard !config.aiApiKey.isEmpty else {
            throw ChatError.noAPIKey
        }
        
        await MainActor.run { isProcessing = true }
        defer { Task { @MainActor in isProcessing = false } }
        
        // 添加用户消息到历史
        let userMessage = ChatRequest.ChatRequestMessage(role: "user", content: text)
        conversationHistory.append(userMessage)
        
        // 裁剪历史（保留 system prompt + 最近 N 条）
        if conversationHistory.count > maxHistoryCount + 1 {
            let systemPrompt = conversationHistory.first!
            let recent = conversationHistory.suffix(maxHistoryCount)
            conversationHistory = [systemPrompt] + recent
        }
        
        // 构建请求消息：历史 + 传感器上下文（一次性，不入历史）
        var requestMessages = conversationHistory
        if let context = sensorContext, !context.isEmpty {
            requestMessages.append(ChatRequest.ChatRequestMessage(
                role: "system",
                content: "[传感器数据] \(context)"
            ))
        }
        
        let request = ChatRequest(
            messages: requestMessages,
            sensorContext: sensorContext,
            model: config.aiModel
        )
        
        let (text, tokens) = try await performRequest(request)
        
        // 添加助手回复到历史
        let assistantMessage = ChatRequest.ChatRequestMessage(role: "assistant", content: text)
        conversationHistory.append(assistantMessage)
        
        return (text, tokens)
    }
    
    // MARK: - 执行 HTTP 请求
    
    private func performRequest(_ chatRequest: ChatRequest) async throws -> (text: String, tokens: Int) {
        guard let url = URL(string: config.aiApiEndpoint) else {
            throw ChatError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("Bearer \(config.aiApiKey)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(chatRequest)
        
        let (data, response) = try await urlSession.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            // 尝试解析错误消息
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw ChatError.apiError(message)
            }
            throw ChatError.httpError(httpResponse.statusCode)
        }
        
        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ChatError.emptyResponse
        }
        
        return (content, chatResponse.usage?.totalTokens ?? 0)
    }
    
    // MARK: - 流式对话
    
    func sendMessageStream(_ text: String, sensorContext: String? = nil, 
                           onChunk: @escaping (String) -> Void) async throws -> (text: String, tokens: Int) {
        let response = try await sendMessage(text, sensorContext: sensorContext)
        onChunk(response.text)
        return response
    }
    
    // MARK: - 清除对话历史
    
    func clearHistory() {
        conversationHistory = [
            ChatRequest.ChatRequestMessage(role: "system", content: config.systemPrompt)
        ]
    }
    
    // MARK: - 更新配置
    
    func updateConfig(_ newConfig: AppConfig) {
        self.config = newConfig
        // 更新 system prompt
        if let systemIndex = conversationHistory.firstIndex(where: { $0.role == "system" }) {
            conversationHistory[systemIndex] = ChatRequest.ChatRequestMessage(
                role: "system", content: newConfig.systemPrompt
            )
        }
    }
    
    // MARK: - 查询余额
    
    func fetchBalance() async throws -> BalanceInfo {
        guard let url = URL(string: config.balanceApiEndpoint) else {
            throw ChatError.invalidURL
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.addValue("Bearer \(config.aiApiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ChatError.invalidResponse
        }
        
        struct UserInfoResponse: Codable {
            let data: BalanceInfo
        }
        let info = try JSONDecoder().decode(UserInfoResponse.self, from: data)
        return info.data
    }
    
    // MARK: - 获取对话历史
    
    var historyCount: Int {
        conversationHistory.filter { $0.role != "system" }.count
    }
    
    var lastMessages: [ChatMessage] {
        conversationHistory
            .filter { $0.role != "system" }
            .suffix(10)
            .map { msg in
                ChatMessage(
                    role: msg.role == "user" ? .user : .assistant,
                    content: msg.content
                )
            }
    }
}

// MARK: - 错误类型

enum ChatError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case emptyResponse
    case httpError(Int)
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "请先在设置中配置 API Key"
        case .invalidURL:
            return "API 地址无效"
        case .invalidResponse:
            return "服务器响应无效"
        case .emptyResponse:
            return "AI 返回了空响应"
        case .httpError(let code):
            return "HTTP 错误: \(code)"
        case .apiError(let message):
            return "API 错误: \(message)"
        }
    }
}
