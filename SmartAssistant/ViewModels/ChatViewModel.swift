import Foundation
import Combine
import SwiftUI
import AudioToolbox

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
    
    // 摄像头/照片
    @Published var cameraActive = false
    @Published var capturedPhoto: UIImage?
    
    // 视线方向（-1~1，-1=左/上，0=中心，+1=右/下）
    @Published var lookX: CGFloat = 0
    @Published var lookY: CGFloat = 0
    
    // 对话状态
    @Published var conversationState: ConversationState = .idle
    
    // 情绪感知
    @Published var userMood: ExpressionType = .normal
    private var recentMoods: [ExpressionType] = []
    
    // 摇晃检测
    private var lastAccel: Double = 1.0
    private var isDizzy = false
    
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
    
    // 说话期间表情循环
    private var speakingCycleTimer: AnyCancellable?
    private var speakingCycle: [ExpressionType] = []
    private var speakingCycleIndex = 0
    
    // 情绪→表情循环簇（说话期间 3s 切换）
    static let emotionClusters: [ExpressionType: [ExpressionType]] = [
        .happy:     [.happy, .veryHappy, .happy, .love, .wink, .happy],
        .veryHappy: [.veryHappy, .happy, .love, .excited, .veryHappy],
        .excited:   [.excited, .surprised, .happy, .excited, .love, .happy],
        .surprised: [.surprised, .excited, .surprised, .scared, .surprised],
        .sad:       [.sad, .sleepy, .sad, .confused, .sad, .normal],
        .angry:     [.angry, .suspicious, .angry, .scared, .angry],
        .scared:    [.scared, .surprised, .sad, .scared, .normal],
        .confused:  [.confused, .thinking, .suspicious, .confused, .thinking],
        .love:      [.love, .shy, .love, .happy, .love, .wink],
        .sleepy:    [.sleepy, .sad, .normal, .sleepy],
        .focused:   [.focused, .thinking, .focused, .cool, .focused],
        .thinking:  [.thinking, .focused, .thinking, .confused, .thinking],
        .cool:      [.cool, .normal, .cool, .happy, .cool],
        .shy:       [.shy, .love, .shy, .happy, .shy],
        .suspicious:[.suspicious, .confused, .thinking, .suspicious],
        .bored:     [.bored, .sleepy, .normal, .bored],
        .wink:      [.wink, .happy, .normal, .wink],
        .speaking:  [.speaking, .normal, .listening, .thinking, .speaking],
        .normal:    [.normal, .listening, .thinking, .focused, .normal],
    ]
    
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
        
        // 摇晃检测：加速度突变 → 头晕
        motionService.$accelerometerData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                self?.detectShake(data)
            }
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
        guard !isPlayingSequence else { return }
        
        switch conversationState {
        case .listening:
            // 聆听：专注/思考/好奇 随机切换
            let exprs: [ExpressionType] = [.listening, .focused, .listening, .thinking, .listening]
            let looks: [(CGFloat, CGFloat)] = [(0, -0.2), (0, -0.3), (0.2, -0.15), (-0.2, -0.15)]
            if Int.random(in: 0...2) == 0 {
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentExpression = exprs.randomElement() ?? .listening
                    let l = looks.randomElement()!
                    lookX = l.0; lookY = l.1
                }
            }
        case .thinking:
            // 思考：思考/专注/困惑/怀疑 循环
            let exprs: [ExpressionType] = [.thinking, .focused, .confused, .thinking, .suspicious]
            let looks: [(CGFloat, CGFloat)] = [(0, -0.5), (0.4, -0.4), (-0.4, -0.3), (0, -0.6)]
            if Int.random(in: 0...2) == 0 {
                withAnimation(.easeInOut(duration: 0.6)) {
                    currentExpression = exprs.randomElement() ?? .thinking
                    let l = looks.randomElement()!
                    lookX = l.0; lookY = l.1
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
            // 空闲：10种表情随机 + 扫视
            if Int.random(in: 0...6) == 0 {
                let exprs: [ExpressionType] = [
                    .normal, .cool, .happy, .thinking, .wink,
                    .focused, .normal, .shy, .listening, .normal
                ]
                let looks: [(CGFloat, CGFloat)] = [
                    (0,0), (0.5,0), (-0.5,0), (0,0.3), (0,-0.3), (0.3,0.2), (-0.3,0.2), (0,0), (0,-0.1)
                ]
                withAnimation(.easeInOut(duration: 0.8)) {
                    currentExpression = exprs.randomElement() ?? .normal
                    let l = looks.randomElement()!
                    lookX = l.0; lookY = l.1
                }
            }
        case .error:
            withAnimation(.easeInOut(duration: 0.3)) {
                lookX = CGFloat.random(in: -0.4...0.4)
                lookY = CGFloat.random(in: 0.1...0.3)
            }
        }
    }
    
    // 指令检测关键词
    static let commands: [String: (ExpressionType, String)] = [
        "拍照": (.excited, "camera"),
        "相机": (.excited, "camera"),
        "拍张照": (.excited, "camera"),
        "咔嚓": (.excited, "camera"),
        "天气": (.focused, "weather"),
        "气温": (.focused, "weather"),
        "多少度": (.focused, "weather"),
        "搜索": (.focused, "search"),
        "查一下": (.focused, "search"),
        "帮我查": (.focused, "search"),
    ]

    private func detectCommand(_ text: String) -> (ExpressionType, String)? {
        let t = text.lowercased()
        for (keyword, (expr, cmd)) in Self.commands {
            if t.contains(keyword) { return (expr, cmd) }
        }
        return nil
    }
    
    // MARK: - 语音交互
    
    func startListening() {
        guard !isListening, !isSpeaking else { return }
        stopSequence()
        stopSpeakingCycle()
        do {
            try speechRecognition.startRecognition()
            isListening = true
            conversationState = .listening
            currentExpression = .listening
            lookX = 0; lookY = -0.2
        } catch {}
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
        
        // 感知用户情绪
        let detectedMood = detectEmotion(trimmed)
        userMood = detectedMood
        recentMoods.append(detectedMood)
        if recentMoods.count > 10 { recentMoods.removeFirst() }
        
        messages.append(ChatMessage(role: .user, content: trimmed))
        conversationState = .thinking
        currentExpression = .thinking
        lookX = 0; lookY = -0.3
        
        // 指令检测
        if let (expr, cmd) = detectCommand(trimmed) {
            isProcessing = false
            playSound(cmd)
            if cmd == "camera" {
                cameraActive = true
            } else {
                currentExpression = expr
                playSequence("excited")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    self?.conversationState = .idle
                    self?.currentExpression = .normal
                }
            }
            return
        }
        
        // 普通对话
        let sensorContext = collectSensorContext()
        do {
            let response = try await aiService.sendMessage(trimmed, sensorContext: sensorContext)
            isProcessing = false
            let aiEmotion = parseEmotion(response)
            messages.append(ChatMessage(role: .assistant, content: response, expression: aiEmotion))
            respondLikePet(userMood: detectedMood, aiEmotion: aiEmotion)
        } catch {
            isProcessing = false
            conversationState = .error(error.localizedDescription)
            currentExpression = .sad; lookX = 0; lookY = 0.2
            if !isPlayingSequence { playSequence("error") }
            playSound("error")
            messages.append(ChatMessage(role: .assistant, content: "error", expression: .sad))
        }
    }
    
    // MARK: - 文字输入
    
    func sendText(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        currentInput = ""
        
        let detectedMood = detectEmotion(trimmed)
        userMood = detectedMood
        recentMoods.append(detectedMood)
        if recentMoods.count > 10 { recentMoods.removeFirst() }
        
        messages.append(ChatMessage(role: .user, content: trimmed))
        isProcessing = true
        conversationState = .thinking
        currentExpression = .thinking; lookX = 0; lookY = -0.3
        
        if let (expr, cmd) = detectCommand(trimmed) {
            isProcessing = false
            playSound(cmd)
            if cmd == "camera" { cameraActive = true; return }
            currentExpression = expr
            playSequence("excited")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.conversationState = .idle; self?.currentExpression = .normal
            }
            return
        }
        
        let sensorContext = collectSensorContext()
        do {
            let response = try await aiService.sendMessage(trimmed, sensorContext: sensorContext)
            isProcessing = false
            let aiEmotion = parseEmotion(response)
            messages.append(ChatMessage(role: .assistant, content: response, expression: aiEmotion))
            respondLikePet(userMood: detectedMood, aiEmotion: aiEmotion)
        } catch {
            isProcessing = false
            conversationState = .error(error.localizedDescription)
            currentExpression = .sad; lookX = 0; lookY = 0.2
            if !isPlayingSequence { playSequence("error") }
            playSound("error")
            messages.append(ChatMessage(role: .assistant, content: "error", expression: .sad))
        }
    }
    
    // MARK: - 宠物回应（感知情绪 + AI 推理 → 表情）
    
    /// 情绪互补映射：用户难过 → 宠物安慰，用户开心 → 宠物更开心
    static let petEmpathy: [ExpressionType: ExpressionType] = [
        .sad: .sad,         // 你难过，我也难过
        .angry: .scared,    // 你生气，我害怕
        .scared: .scared,   // 你害怕，我陪你害怕
        .happy: .happy,     // 你开心，我也开心
        .excited: .excited, // 你兴奋，我更兴奋
        .love: .love,       // 你喜欢我，我也喜欢你
        .bored: .curious,   // 你无聊，我来逗你（用curious代替）
        .sleepy: .sleepy,   // 你困了，我也困
        .confused: .confused,
        .suspicious: .suspicious,
    ]
    
    private func respondLikePet(userMood: ExpressionType, aiEmotion: ExpressionType) {
        conversationState = .speaking
        stopSequence()
        
        // 根据用户情绪选回应方式
        let empathy = Self.petEmpathy[userMood]
        let finalExpr = empathy ?? aiEmotion
        playSound(finalExpr.rawValue)
        
        // 长时间情绪低落 → 主动安慰
        if isUserSad() {
            playSequence("curious")  // 好奇探索 → 试图逗你
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
                self?.currentExpression = .happy
                self?.startSpeakingCycle(.happy)
            }
        } else if let seqName = Self.emotionToSequence[finalExpr] {
            playSequence(seqName)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
                guard self?.conversationState == .speaking else { return }
                self?.currentExpression = finalExpr
                self?.lookX = 0; self?.lookY = 0
                self?.startSpeakingCycle(finalExpr)
            }
        } else {
            currentExpression = finalExpr
            lookX = 0; lookY = 0
            startSpeakingCycle(finalExpr)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard self?.conversationState == .speaking else { return }
            self?.stopSpeakingCycle()
            self?.conversationState = .idle
            self?.currentExpression = .normal
            self?.lookX = 0; self?.lookY = 0
            if self?.config.autoListen == true { self?.startListening() }
        }
    }
    
    /// 最近 5 条情绪中有超过一半是负面情绪
    private func isUserSad() -> Bool {
        let recent = recentMoods.suffix(5)
        let negative: Set<ExpressionType> = [.sad, .angry, .scared, .bored, .sleepy, .confused]
        let negCount = recent.filter { negative.contains($0) }.count
        return negCount >= 3
    }
    
    // MARK: - 摇晃感知
    
    private func detectShake(_ data: AccelerometerData?) {
        guard let data = data, conversationState != .error else { return }
        let mag = data.magnitude
        let delta = abs(mag - lastAccel)
        lastAccel = mag
        
        // 加速度突变 >2.5G → 触发眩晕
        if delta > 2.5 && !isDizzy {
            isDizzy = true
            currentExpression = .confused
            playSound("dizzy")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.isDizzy = false
                if self?.conversationState == .idle {
                    self?.currentExpression = .normal
                }
            }
        }
    }
    
    // MARK: - 声音效果
    
    func playSound(_ name: String) {
        switch name {
        case "camera":     AudioServicesPlaySystemSound(1108)  // 快门声
        case "weather":    AudioServicesPlaySystemSound(1002)  // 提示音
        case "search":     AudioServicesPlaySystemSound(1004)  // 搜索音
        case "error":      AudioServicesPlaySystemSound(1053)  // 错误音
        case "happy":      AudioServicesPlaySystemSound(1025)  // 欢快音
        case "excited":    AudioServicesPlaySystemSound(1024)  // 惊喜音
        case "surprised":  AudioServicesPlaySystemSound(1026)  // 惊讶音
        case "dizzy":      AudioServicesPlaySystemSound(1052)  // 眩晕滴滴声
        case "sad":        AudioServicesPlaySystemSound(1006)  // 低沉音
        case "angry":      AudioServicesPlaySystemSound(1054)  // 警报音
        case "love":       AudioServicesPlaySystemSound(1020)  // 温柔音
        case "veryHappy":  AudioServicesPlaySystemSound(1031)  // 大笑音
        default: break
        }
    }
    
    // MARK: - 说话期间表情循环
    
    private func startSpeakingCycle(_ baseEmotion: ExpressionType) {
        let cluster = Self.emotionClusters[baseEmotion] ?? [.speaking, .normal, .speaking]
        speakingCycle = cluster
        speakingCycleIndex = 0
        speakingCycleTimer?.cancel()
        speakingCycleTimer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.conversationState == .speaking, !self.speakingCycle.isEmpty else { return }
                self.speakingCycleIndex = (self.speakingCycleIndex + 1) % self.speakingCycle.count
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.currentExpression = self.speakingCycle[self.speakingCycleIndex]
                }
            }
    }
    
    private func stopSpeakingCycle() {
        speakingCycleTimer?.cancel()
        speakingCycleTimer = nil
        speakingCycle = []
        speakingCycleIndex = 0
    }
    
    func stopSpeaking() {
        stopSequence()
        stopSpeakingCycle()
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
