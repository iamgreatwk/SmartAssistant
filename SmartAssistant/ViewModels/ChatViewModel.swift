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
        guard !isSpeaking else { return }  // 说话中不启动
        
        do {
            try speechRecognition.startRecognition()
            isListening = true
            conversationState = .listening
            currentExpression = .listening
        } catch {
            print("语音识别启动失败: \(error.localizedDescription)")
            // 不设 errorMessage 避免 UI 错误提示
        }
    }
    
    func stopListening() {
        guard isListening else { return }
        speechRecognition.stopRecognition()
        isListening = false
    }
    
    private func handleRecognizedText(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        // 先完全停止语音识别，释放音频资源
        speechRecognition.stopRecognition()
        isListening = false
        
        // 添加用户消息
        let userMessage = ChatMessage(role: .user, content: trimmed, expression: .normal)
        messages.append(userMessage)
        conversationState = .thinking
        currentExpression = .thinking
        
        // 收集传感器上下文
        let sensorContext = collectSensorContext()
        
        do {
            // 调用 AI
            let response = try await aiService.sendMessage(trimmed, sensorContext: sensorContext)
            
            isProcessing = false
            
            let emotion = detectEmotion(response)
            let aiMessage = ChatMessage(role: .assistant, content: response, expression: emotion)
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
            
            let emotion = detectEmotion(response)
            let aiMessage = ChatMessage(role: .assistant, content: response, expression: emotion)
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
        let emotion = detectEmotion(text)
        conversationState = .speaking
        currentExpression = emotion
        
        // 过滤掉 emoji，不让 TTS 读出来
        let cleaned = text.filter { !$0.isEmoji }
        speaker.speak(cleaned.trimmingCharacters(in: .whitespaces)) { [weak self] in
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
    
    // MARK: - 情绪检测
    
    private func detectEmotion(_ text: String) -> ExpressionType {
        let t = text.lowercased()
        
        // 大笑/非常开心
        if t.contains("哈哈") || t.contains("笑死") || t.contains("🤣") || t.contains("hhh") || t.contains("太好笑") {
            return .veryHappy
        }
        // 开心
        if t.contains("开心") || t.contains("太棒") || t.contains("真好") ||
           t.contains("😄") || t.contains("嘿嘿") || t.contains("耶") || t.contains("太好了") {
            return .happy
        }
        // 兴奋
        if t.contains("哇") || t.contains("🤩") || t.contains("厉害") || t.contains("牛") ||
           t.contains("太酷") || t.contains("天啊") || t.contains("太强") || t.contains("绝了") {
            return .excited
        }
        // 惊讶
        if t.contains("什么") || t.contains("真的假的") || t.contains("😲") ||
           t.contains("不会吧") || t.contains("居然") || t.contains("我的天") ||
           t.contains("难以置信") {
            return .surprised
        }
        // 害怕
        if t.contains("害怕") || t.contains("恐怖") || t.contains("😨") ||
           t.contains("吓") || t.contains("可怕") || t.contains("好怕") {
            return .scared
        }
        // 生气
        if t.contains("生气") || t.contains("烦") || t.contains("😠") ||
           t.contains("讨厌") || t.contains("滚") || t.contains("无语") || t.contains("愤怒") {
            return .angry
        }
        // 难过
        if t.contains("难过") || t.contains("伤心") || t.contains("😢") ||
           t.contains("哭") || t.contains("可惜") || t.contains("遗憾") || t.contains("心痛") {
            return .sad
        }
        // 无聊
        if t.contains("无聊") || t.contains("😑") || t.contains("没意思") ||
           t.contains("好闲") || t.contains("闷") {
            return .bored
        }
        // 喜欢/爱
        if t.contains("爱你") || t.contains("喜欢") || t.contains("🥰") ||
           t.contains("亲亲") || t.contains("么么") || t.contains("爱你哟") {
            return .love
        }
        // 害羞
        if t.contains("害羞") || t.contains("😳") || t.contains("不好意思") ||
           t.contains("脸红") || t.contains("羞") {
            return .shy
        }
        // 困惑
        if t.contains("🤔") || t.contains("不太确定") || t.contains("奇怪") ||
           t.contains("搞不懂") || t.contains("？？") || t.contains("不明白") {
            return .confused
        }
        // 怀疑
        if t.contains("🤨") || t.contains("骗人") || t.contains("真的吗") ||
           t.contains("不信") || t.contains("怀疑") {
            return .suspicious
        }
        // 专注（思考类内容）
        if t.contains("专注") || t.contains("分析") || t.contains("计算") ||
           t.contains("查一下") || t.contains("搜索") {
            return .focused
        }
        // 眨眼/俏皮
        if t.contains("😉") || t.contains("悄悄") || t.contains("秘密") ||
           t.contains("嘿") || t.contains("嘘") {
            return .wink
        }
        // 酷
        if t.contains("😎") || t.contains("帅") || t.contains("酷") {
            return .cool
        }
        // 困
        if t.contains("😴") || t.contains("困") || t.contains("累了") || t.contains("好累") {
            return .sleepy
        }
        
        // 默认说话表情
        return .speaking
    }
    
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

// MARK: - Character Extension

extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmojiPresentation
    }
}
