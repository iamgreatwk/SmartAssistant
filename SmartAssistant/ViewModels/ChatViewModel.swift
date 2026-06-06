import Foundation
import Combine
import SwiftUI

/// 聊天 ViewModel — 协调语音对话流程
@MainActor
class ChatViewModel: ObservableObject {
    
    // MARK: - 发布属性
    
    @Published var messages: [ChatMessage] = []
    @Published var currentInput: String = ""
    @Published var isListening: Bool = false
    @Published var isProcessing: Bool = false
    @Published var isSpeaking: Bool = false
    @Published var currentExpression: ExpressionType = .normal
    @Published var speakingLevel: CGFloat = 0
    @Published var errorMessage: String?
    @Published var showSettings: Bool = false
    @Published var ttsConfig = TTSConfig()
    
    // 对话状态
    @Published var conversationState: ConversationState = .idle
    
    enum ConversationState: Equatable {
        case idle           // 空闲
        case listening      // 听你说话
        case thinking       // AI 思考中
        case speaking       // AI 说话中
        case error(String)  // 出错
    }
    
    // MARK: - 服务
    
    private let aiService = AIChatService()
    private let speechRecognition = SpeechRecognitionService()
    private let speaker = SpeakerService()
    private let motionService = MotionService()
    private let locationService = LocationService()
    private let microphoneService = MicrophoneService()
    
    private var cancellables = Set<AnyCancellable>()
    private var config: AppConfig
    
    // MARK: - 初始化
    
    init() {
        self.config = .load()
        setupBindings()
    }
    
    private func setupBindings() {
        // 语音识别结果绑定
        speechRecognition.onFinalResult = { [weak self] text in
            Task { @MainActor in
                await self?.handleRecognizedText(text)
            }
        }
        
        speechRecognition.onSilenceDetected = { [weak self] in
            Task { @MainActor in
                if self?.conversationState == .listening {
                    await self?.handleRecognizedText(self?.speechRecognition.partialText ?? "")
                }
            }
        }
        
        // 麦克风音量绑定（用于表情动画）
        microphoneService.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.speakingLevel = CGFloat(level)
            }
            .store(in: &cancellables)
        
        // TTS 配置同步
        $ttsConfig
            .sink { [weak self] config in
                self?.speaker.updateConfig(config)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 语音交互
    
    func startListening() {
        guard !isListening else { return }
        
        do {
            try speechRecognition.startRecognition()
            isListening = true
            conversationState = .listening
            currentExpression = .listening
        } catch {
            errorMessage = "语音识别启动失败: \(error.localizedDescription)"
        }
    }
    
    func stopListening() {
        speechRecognition.stopRecognition()
        isListening = false
    }
    
    private func handleRecognizedText(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        // 添加用户消息
        let userMessage = ChatMessage(role: .user, content: trimmed, expression: .normal)
        messages.append(userMessage)
        
        // 进入思考状态
        isListening = false
        isProcessing = true
        conversationState = .thinking
        currentExpression = .thinking
        
        // 收集传感器上下文
        let sensorContext = collectSensorContext()
        
        do {
            // 调用 AI
            let response = try await aiService.sendMessage(trimmed, sensorContext: sensorContext)
            
            isProcessing = false
            
            // 添加 AI 回复
            let aiMessage = ChatMessage(role: .assistant, content: response, expression: .speaking)
            messages.append(aiMessage)
            
            // 开始语音播报
            speakResponse(response)
            
        } catch {
            isProcessing = false
            conversationState = .error(error.localizedDescription)
            currentExpression = .sad
            
            let errorMsg = ChatMessage(role: .assistant, 
                                       content: "抱歉，我暂时无法回应: \(error.localizedDescription)",
                                       expression: .sad)
            messages.append(errorMsg)
        }
    }
    
    // MARK: - 文字输入
    
    func sendText(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        currentInput = ""
        
        let userMessage = ChatMessage(role: .user, content: trimmed)
        messages.append(userMessage)
        
        isProcessing = true
        conversationState = .thinking
        currentExpression = .thinking
        
        let sensorContext = collectSensorContext()
        
        do {
            let response = try await aiService.sendMessage(trimmed, sensorContext: sensorContext)
            
            isProcessing = false
            
            let aiMessage = ChatMessage(role: .assistant, content: response, expression: .speaking)
            messages.append(aiMessage)
            
            speakResponse(response)
        } catch {
            isProcessing = false
            conversationState = .error(error.localizedDescription)
            currentExpression = .sad
            
            let errorMsg = ChatMessage(role: .assistant,
                                       content: "出了点问题: \(error.localizedDescription)",
                                       expression: .sad)
            messages.append(errorMsg)
        }
    }
    
    // MARK: - TTS 播报
    
    private func speakResponse(_ text: String) {
        conversationState = .speaking
        currentExpression = .speaking
        
        speaker.speak(text) { [weak self] in
            DispatchQueue.main.async {
                self?.conversationState = .idle
                self?.currentExpression = .normal
                self?.isSpeaking = false
                
                // 如果开启自动监听，继续监听
                if self?.config.autoListen == true {
                    self?.startListening()
                }
            }
        }
        
        isSpeaking = true
    }
    
    func stopSpeaking() {
        speaker.stopSpeaking()
        isSpeaking = false
        conversationState = .idle
        currentExpression = .normal
    }
    
    // MARK: - 传感器上下文
    
    private func collectSensorContext() -> String {
        var parts: [String] = []
        
        if let accel = motionService.accelerometerData {
            parts.append("加速度: x=\(String(format: "%.2f", accel.x)), y=\(String(format: "%.2f", accel.y)), z=\(String(format: "%.2f", accel.z)), 设备\(accel.isMoving ? "正在移动" : "静止")")
        }
        if let att = motionService.deviceAttitude {
            parts.append("姿态: \(att.orientation)")
        }
        if let loc = locationService.currentLocation {
            parts.append("位置: 纬度\(String(format: "%.4f", loc.latitude)), 经度\(String(format: "%.4f", loc.longitude)), 速度\(String(format: "%.1f", loc.speedKMH))km/h")
        }
        
        return parts.isEmpty ? "" : parts.joined(separator: "; ")
    }
    
    // MARK: - 管理
    
    func clearConversation() {
        messages.removeAll()
        aiService.clearHistory()
        currentExpression = .normal
        conversationState = .idle
    }
    
    func updateConfig(_ newConfig: AppConfig) {
        self.config = newConfig
        aiService.updateConfig(newConfig)
        newConfig.save()
    }
    
    func getConfig() -> AppConfig {
        return config
    }
}
