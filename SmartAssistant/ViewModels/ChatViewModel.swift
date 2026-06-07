import Foundation
import Combine
import SwiftUI

/// 聊天 ViewModel — 协调语音对话流程 + 表情动画序列
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
    
    // 视线方向（-1~1，-1=左/上，0=中心，+1=右/下）
    @Published var lookX: CGFloat = 0
    @Published var lookY: CGFloat = 0
    
    // 对话状态
    @Published var conversationState: ConversationState = .idle
    
    enum ConversationState: Equatable {
        case idle
        case listening
        case thinking
        case speaking
        case error(String)
    }
    
    // MARK: - 动画序列定义
    
    struct SeqStep {
        let expr: ExpressionType
        let lx: CGFloat
        let ly: CGFloat
        let isBlink: Bool
        
        init(_ e: ExpressionType, x: CGFloat = 0, y: CGFloat = 0, blink: Bool = false) {
            expr = e; lx = x; ly = y; isBlink = blink
        }
    }
    
    static let sequences: [String: [SeqStep]] = [
        "greeting": [
            SeqStep(.surprised), SeqStep(.surprised, x: 0, y: -0.4),
            SeqStep(.happy), SeqStep(.happy, x: 0.4, y: 0),
            SeqStep(.happy, x: -0.4, y: 0), SeqStep(.happy),
            SeqStep(.normal)
        ],
        "surprise": [
            SeqStep(.surprised, y: -0.5), SeqStep(.surprised),
            SeqStep(.scared, blink: true), SeqStep(.surprised, blink: true),
            SeqStep(.surprised), SeqStep(.normal)
        ],
        "thinking": [
            SeqStep(.focused, y: -0.5), SeqStep(.focused, x: -0.4),
            SeqStep(.focused, x: 0.4), SeqStep(.wink),
            SeqStep(.normal)
        ],
        "error": [
            SeqStep(.surprised), SeqStep(.scared),
            SeqStep(.angry), SeqStep(.sad, y: 0.4, blink: true),
            SeqStep(.sad), SeqStep(.normal)
        ],
        "sadness": [
            SeqStep(.normal, y: 0.3), SeqStep(.sad),
            SeqStep(.sleepy, blink: true), SeqStep(.sad),
            SeqStep(.normal)
        ],
        "curious": [
            SeqStep(.normal, x: -0.5, y: 0), SeqStep(.normal, x: 0.5),
            SeqStep(.normal, y: -0.4), SeqStep(.surprised, y: 0.3),
            SeqStep(.focused), SeqStep(.normal)
        ],
        "sleepySeq": [
            SeqStep(.normal), SeqStep(.sleepy),
            SeqStep(.sleepy, blink: true), SeqStep(.sleepy, blink: true),
            SeqStep(.sleepy)
        ],
        "excited": [
            SeqStep(.surprised, y: -0.5), SeqStep(.happy),
            SeqStep(.happy, x: -0.5), SeqStep(.happy, x: 0.5),
            SeqStep(.happy, y: -0.4), SeqStep(.happy, y: 0.3),
            SeqStep(.happy, blink: true), SeqStep(.love),
            SeqStep(.happy), SeqStep(.normal)
        ],
    ]
    
    // 情绪→序列映射
    static let emotionToSequence: [ExpressionType: String] = [
        .veryHappy: "excited", .excited: "excited",
        .surprised: "surprise", .scared: "surprise",
        .angry: "error", .sad: "sadness",
        .focused: "thinking", .thinking: "thinking",
        .love: "excited", .sleepy: "sleepySeq",
        .confused: "curious", .suspicious: "curious",
    ]
    
    private var sequenceTimer: AnyCancellable?
    private var sequenceSteps: [SeqStep] = []
    private var sequenceIndex = 0
    private var isPlayingSequence = false
    
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
        speechRecognition.onFinalResult = { [weak self] text in
            Task { @MainActor in await self?.handleRecognizedText(text) }
        }
        speechRecognition.onSilenceDetected = { [weak self] in
            Task { @MainActor in
                if self?.conversationState == .listening {
                    await self?.handleRecognizedText(self?.speechRecognition.partialText ?? "")
                }
            }
        }
        microphoneService.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in self?.speakingLevel = CGFloat(level) }
            .store(in: &cancellables)
        $ttsConfig
            .sink { [weak self] config in self?.speaker.updateConfig(config) }
            .store(in: &cancellables)
        Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.enrichExpression() }
            .store(in: &cancellables)
    }
    
    // MARK: - 序列播放器
    
    private func playSequence(_ name: String) {
        guard let steps = Self.sequences[name], !steps.isEmpty else { return }
        stopSequence()
        sequenceSteps = steps
        sequenceIndex = 0
        isPlayingSequence = true
        playNextStep()
    }
    
    private func playNextStep() {
        guard isPlayingSequence, sequenceIndex < sequenceSteps.count else {
            stopSequence()
            return
        }
        let step = sequenceSteps[sequenceIndex]
        sequenceIndex += 1
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentExpression = step.expr
            lookX = step.lx
            lookY = step.ly
        }
        
        // 每步持续 0.35 秒（与 HTML 的 delay 帧对应）
        sequenceTimer = Timer.publish(every: 0.35, on: .main, in: .common)
            .autoconnect()
            .first()
            .sink { [weak self] _ in
                self?.playNextStep()
            }
    }
    
    private func stopSequence() {
        isPlayingSequence = false
        sequenceTimer?.cancel()
        sequenceTimer = nil
        sequenceSteps = []
        sequenceIndex = 0
    }
    
    // MARK: - 表情丰富化
    
    private func enrichExpression() {
        guard !isPlayingSequence else { return }  // 序列播放时不干扰
        
        switch conversationState {
        case .listening:
            if Int.random(in: 0...2) == 0 {
                withAnimation(.easeInOut(duration: 0.5)) {
                    lookX = CGFloat.random(in: -0.3...0.3)
                    lookY = CGFloat.random(in: -0.15...0.15)
                }
            }
        case .thinking:
            let dirs: [(CGFloat, CGFloat)] = [(0, -0.4), (0.3, -0.3), (-0.3, -0.3)]
            if Int.random(in: 0...2) == 0 {
                let d = dirs.randomElement()!
                withAnimation(.easeInOut(duration: 0.6)) {
                    lookX = d.0; lookY = d.1
                }
            }
        case .speaking:
            if Int.random(in: 0...4) == 0 {
                withAnimation(.easeInOut(duration: 0.4)) {
                    lookX = CGFloat.random(in: -0.2...0.2)
                    lookY = CGFloat.random(in: -0.25...0.25)
                }
            }
        case .idle:
            if Int.random(in: 0...5) == 0 {
                let dirs: [(CGFloat, CGFloat)] = [
                    (0,0), (0.5,0), (-0.5,0), (0,0.3), (0,-0.3), (0.3,0.2), (-0.3,0.2)
                ]
                let d = dirs.randomElement()!
                withAnimation(.easeInOut(duration: 0.8)) {
                    lookX = d.0; lookY = d.1
                }
            }
        case .error:
            withAnimation(.easeInOut(duration: 0.3)) {
                lookX = CGFloat.random(in: -0.4...0.4)
                lookY = CGFloat.random(in: 0.1...0.3)
            }
        }
    }
    
    // MARK: - 语音交互
    
    func startListening() {
        guard !isListening, !isSpeaking else { return }
        stopSequence()
        do {
            try speechRecognition.startRecognition()
            isListening = true
            conversationState = .listening
            currentExpression = .listening
            lookX = 0; lookY = -0.2
        } catch {
            print("语音识别启动失败: \(error.localizedDescription)")
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
        
        speechRecognition.stopRecognition()
        isListening = false
        
        let userMessage = ChatMessage(role: .user, content: trimmed, expression: .normal)
        messages.append(userMessage)
        conversationState = .thinking
        currentExpression = .thinking
        lookX = 0; lookY = -0.3
        
        let sensorContext = collectSensorContext()
        
        do {
            let response = try await aiService.sendMessage(trimmed, sensorContext: sensorContext)
            isProcessing = false
            
            let emotion = detectEmotion(response)
            let aiMessage = ChatMessage(role: .assistant, content: response, expression: emotion)
            messages.append(aiMessage)
            
            speakResponse(response, emotion: emotion)
        } catch {
            isProcessing = false
            conversationState = .error(error.localizedDescription)
            currentExpression = .sad; lookX = 0; lookY = 0.2
            // 播放错误序列
            if !isPlayingSequence { playSequence("error") }
            
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
        currentExpression = .thinking; lookX = 0; lookY = -0.3
        
        let sensorContext = collectSensorContext()
        
        do {
            let response = try await aiService.sendMessage(trimmed, sensorContext: sensorContext)
            isProcessing = false
            let emotion = detectEmotion(response)
            let aiMessage = ChatMessage(role: .assistant, content: response, expression: emotion)
            messages.append(aiMessage)
            speakResponse(response, emotion: emotion)
        } catch {
            isProcessing = false
            conversationState = .error(error.localizedDescription)
            currentExpression = .sad; lookX = 0; lookY = 0.2
            if !isPlayingSequence { playSequence("error") }
            let errorMsg = ChatMessage(role: .assistant,
                                       content: "出了点问题: \(error.localizedDescription)",
                                       expression: .sad)
            messages.append(errorMsg)
        }
    }
    
    // MARK: - TTS 播报
    
    private func speakResponse(_ text: String, emotion: ExpressionType? = nil) {
        let emo = emotion ?? detectEmotion(text)
        conversationState = .speaking
        
        // 强情绪先播放动画序列，再进入说话状态
        if let seqName = Self.emotionToSequence[emo], !isPlayingSequence {
            playSequence(seqName)
            // 序列播完后切换到情绪表情
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
                guard self?.conversationState == .speaking else { return }
                self?.currentExpression = emo
                self?.lookX = 0; self?.lookY = 0
            }
        } else {
            currentExpression = emo
            lookX = 0; lookY = 0
        }
        
        let cleaned = text.filter { !$0.isEmoji }
        speaker.speak(cleaned.trimmingCharacters(in: .whitespaces)) { [weak self] in
            DispatchQueue.main.async {
                self?.stopSequence()
                self?.conversationState = .idle
                self?.currentExpression = .normal
                self?.lookX = 0; self?.lookY = 0
                self?.isSpeaking = false
                if self?.config.autoListen == true {
                    self?.startListening()
                }
            }
        }
        isSpeaking = true
    }
    
    func stopSpeaking() {
        speaker.stopSpeaking()
        stopSequence()
        isSpeaking = false
        conversationState = .idle
        currentExpression = .normal
        lookX = 0; lookY = 0
    }
    
    // MARK: - 情绪检测
    
    private func detectEmotion(_ text: String) -> ExpressionType {
        let t = text.lowercased()
        if t.contains("哈哈") || t.contains("笑死") || t.contains("🤣") || t.contains("hhh") || t.contains("太好笑") { return .veryHappy }
        if t.contains("开心") || t.contains("太棒") || t.contains("真好") || t.contains("😄") || t.contains("嘿嘿") || t.contains("耶") || t.contains("太好了") { return .happy }
        if t.contains("哇") || t.contains("🤩") || t.contains("厉害") || t.contains("牛") || t.contains("太酷") || t.contains("天啊") || t.contains("太强") || t.contains("绝了") { return .excited }
        if t.contains("什么") || t.contains("真的假的") || t.contains("😲") || t.contains("不会吧") || t.contains("居然") || t.contains("我的天") || t.contains("难以置信") { return .surprised }
        if t.contains("害怕") || t.contains("恐怖") || t.contains("😨") || t.contains("吓") || t.contains("可怕") || t.contains("好怕") { return .scared }
        if t.contains("生气") || t.contains("烦") || t.contains("😠") || t.contains("讨厌") || t.contains("滚") || t.contains("无语") || t.contains("愤怒") { return .angry }
        if t.contains("难过") || t.contains("伤心") || t.contains("😢") || t.contains("哭") || t.contains("可惜") || t.contains("遗憾") || t.contains("心痛") { return .sad }
        if t.contains("无聊") || t.contains("😑") || t.contains("没意思") || t.contains("好闲") || t.contains("闷") { return .bored }
        if t.contains("爱你") || t.contains("喜欢") || t.contains("🥰") || t.contains("亲亲") || t.contains("么么") || t.contains("爱你哟") { return .love }
        if t.contains("害羞") || t.contains("😳") || t.contains("不好意思") || t.contains("脸红") || t.contains("羞") { return .shy }
        if t.contains("🤔") || t.contains("不太确定") || t.contains("奇怪") || t.contains("搞不懂") || t.contains("？？") || t.contains("不明白") { return .confused }
        if t.contains("🤨") || t.contains("骗人") || t.contains("真的吗") || t.contains("不信") || t.contains("怀疑") { return .suspicious }
        if t.contains("专注") || t.contains("分析") || t.contains("计算") || t.contains("查一下") || t.contains("搜索") { return .focused }
        if t.contains("😉") || t.contains("悄悄") || t.contains("秘密") || t.contains("嘿") || t.contains("嘘") { return .wink }
        if t.contains("😎") || t.contains("帅") || t.contains("酷") { return .cool }
        if t.contains("😴") || t.contains("困") || t.contains("累了") || t.contains("好累") { return .sleepy }
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
        stopSequence()
        currentExpression = .normal; lookX = 0; lookY = 0
        conversationState = .idle
    }
    
    func updateConfig(_ newConfig: AppConfig) {
        self.config = newConfig
        aiService.updateConfig(newConfig)
        newConfig.save()
    }
    
    func getConfig() -> AppConfig { return config }
}

extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmojiPresentation
    }
}
