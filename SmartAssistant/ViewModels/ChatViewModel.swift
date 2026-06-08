import Foundation
import Combine
import SwiftUI
import UIKit

/// 聊天 ViewModel — 表情动画引擎（从 expressions.json 读取配置）
@MainActor
class ChatViewModel: ObservableObject {
    
    // MARK: - 配置
    
    private let exprConfig = ExpressionConfig.shared
    
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
    @Published var cameraMode: String = "photo"  // photo/face/object/gesture
    
    // 视线方向（-1~1，-1=左/上，0=中心，+1=右/下）
    @Published var lookX: CGFloat = 0
    @Published var lookY: CGFloat = 0
    
    // 对话状态
    @Published var conversationState: ConversationState = .idle
    
    // 调试信息
    @Published var debugInfo = DebugInfo()
    
    struct DebugInfo {
        var sttText: String = ""
        var aiInput: String = ""
        var aiOutput: String = ""
        var expression: String = ""
        var workflow: String = "空闲"
        var tokens: Int = 0
        var totalTokens: Int = 0
        var balance: String = ""
        var sensor: String = ""
    }
    
    // 情绪感知
    @Published var userMood: ExpressionType = .normal
    private var recentMoods: [ExpressionType] = []
    
    // 摇晃检测
    private var lastAccel: Double = 1.0
    private var isDizzy = false
    private var spikeCount = 0      // 连续尖峰计数
    private var lastSpikeTime: Date = .distantPast
    
    // MARK: - 调试日志
    
    private func logDebug(_ keypath: WritableKeyPath<DebugInfo, String>, _ value: String) {
        debugInfo[keyPath: keypath] = value
    }
    
    enum ConversationState: Equatable {
        case idle
        case listening
        case thinking
        case speaking
        case error(String)
    }
    
    private var sequenceTimer: AnyCancellable?
    private var sequenceSteps: [ExpressionType.SeqStep] = []
    private var sequenceIndex = 0
    private var isPlayingSequence = false
    
    // 说话期间表情循环
    private var speakingCycleTimer: AnyCancellable?
    private var speakingCycle: [ExpressionType] = []
    private var speakingCycleIndex = 0
    
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
        motionService.startAccelerometer()
        motionService.startGyroscope()
        motionService.startDeviceMotion()
        motionService.startPedometer()
        locationService.startUpdatingLocation()
        // 距离传感器
        UIDevice.current.isProximityMonitoringEnabled = true
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
        
        // 加速度：摇晃 + 传感器触发
        motionService.$accelerometerData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                self?.detectShake(data)
                self?.detectSensorTriggers(accel: data,
                    gyro: self?.motionService.gyroscopeData,
                    attitude: self?.motionService.deviceAttitude,
                    speedKmh: self?.locationService.currentLocation?.speedKMH,
                    altitude: self?.locationService.currentLocation?.altitude,
                    stepCount: self?.motionService.stepCount,
                    proximity: UIDevice.current.proximityState,
                    lux: UIScreen.main.brightness * 1000)
                // 更新调试信息 — 所有传感器值始终显示
                if let d = data {
                    let mag = d.magnitude - 1.0
                    let gyro = self?.motionService.gyroscopeData
                    let gyroRate = gyro.map { sqrt($0.x*$0.x + $0.y*$0.y + $0.z*$0.z) } ?? 0
                    let att = self?.motionService.deviceAttitude
                    let rollDeg = att.map { $0.roll * 180 / .pi } ?? 0
                    let pitchDeg = att.map { $0.pitch * 180 / .pi } ?? 0
                    let yawDeg = att.map { $0.yaw * 180 / .pi } ?? 0
                    let magData = self?.motionService.magnetometerData
                    let heading = magData.map { atan2($0.y, $0.x) * 180 / .pi } ?? 0
                    let speedKmh = self?.locationService.currentLocation?.speedKMH ?? 0
                    let alt = self?.locationService.currentLocation?.altitude ?? 0
                    let stepsNow = self?.motionService.stepCount ?? 0
                    let prox = UIDevice.current.proximityState
                    let lux = Int(UIScreen.main.brightness * 1000)
                    let shake = abs(mag) > 0.8
                    
                    let s1 = String(format:"a:%.1f%@ g:%.0f", mag, shake ? "⚡":"")
                    let s2 = String(format:"R:%.0f P:%.0f Y:%.0f", rollDeg, pitchDeg, yawDeg)
                    let s3 = String(format:"🧭%.0f° 🏃%.0f 👣%d", heading, speedKmh, stepsNow)
                    let s4 = String(format:"H:%.0fm 💡%d%@", alt, lux, prox ? " 近":"")
                    self?.debugInfo.sensor = "\(s1) \(s2)\n\(s3) \(s4)"
                }
            }
            .store(in: &cancellables)
        $ttsConfig
            .sink { [weak self] config in self?.speaker.updateConfig(config) }
            .store(in: &cancellables)
    }
    
    // MARK: - 序列播放器
    
    private func playSequence(_ name: String) {
        guard let steps = exprConfig.sequenceSteps(for: name), !steps.isEmpty else { return }
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
        
        let delay: Double = step.delayMs / 1000.0
        sequenceTimer = Timer.publish(every: delay, on: .main, in: .common)
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
            // 聆听：专注 + 偶尔好奇扫视
            if Int.random(in: 0...2) == 0 {
                let exprs = exprConfig.expressionArray(from: exprConfig.listeningExpressions)
                let looks: [(CGFloat, CGFloat)] = [(0, -0.2), (0, -0.3), (0.2, -0.15), (-0.2, -0.15)]
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentExpression = exprs.randomElement() ?? .listening
                    let l = looks.randomElement()!
                    lookX = l.0; lookY = l.1
                }
            }
        case .thinking:
            // 思考：思考/专注/困惑/怀疑 循环
            if Int.random(in: 0...2) == 0 {
                let exprs = exprConfig.expressionArray(from: exprConfig.thinkingExpressions)
                let looks: [(CGFloat, CGFloat)] = [(0, -0.5), (0.4, -0.4), (-0.4, -0.3), (0, -0.6)]
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
                let exprs = exprConfig.expressionArray(from: exprConfig.idleExpressions)
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
        if let cmd = exprConfig.detectCommand(text),
           let expr = ExpressionType(rawValue: cmd.expression) {
            return (expr, cmd.command)
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
            let l = exprConfig.look(for: "listening")
            lookX = l.0; lookY = l.1
            logDebug(\.workflow, "聆听中")
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
        
        logDebug(\.workflow, "思考中...")
        logDebug(\.sttText, trimmed)
        logDebug(\.aiInput, trimmed)
        logDebug(\.aiOutput, "等待AI...")
        
        messages.append(ChatMessage(role: .user, content: trimmed))
        conversationState = .thinking
        currentExpression = .thinking
        let tl = exprConfig.look(for: "thinking")
        lookX = tl.0; lookY = tl.1
        
        // 指令检测
        if let (expr, cmd) = detectCommand(trimmed) {
            isProcessing = false
            playSound(cmd)
            if cmd == "camera" {
                cameraActive = true
            } else {
                currentExpression = expr
                playSequence("excited")
                DispatchQueue.main.asyncAfter(deadline: .now() + exprConfig.commandDurationSec) { [weak self] in
                    self?.conversationState = .idle
                    self?.currentExpression = .normal
                }
            }
            return
        }
        
        // 普通对话
        do {
            let (response, tokens) = try await aiService.sendMessage(trimmed)
            isProcessing = false
            debugInfo.tokens = tokens
            debugInfo.totalTokens += tokens
            let aiEmotion = parseEmotion(response)
            logDebug(\.aiOutput, response)
            logDebug(\.expression, aiEmotion.displayName)
            logDebug(\.workflow, "表情: \(aiEmotion.displayName)")
            messages.append(ChatMessage(role: .assistant, content: response, expression: aiEmotion))
            respondLikePet(userMood: detectedMood, aiEmotion: aiEmotion)
            refreshBalance()
        } catch {
            isProcessing = false
            conversationState = .error(error.localizedDescription)
            logDebug(\.aiOutput, "错误: \(error.localizedDescription)")
            logDebug(\.workflow, "请求失败")
            if let errCfg = exprConfig.errorResponse,
               let errExpr = ExpressionType(rawValue: errCfg.expression) {
                currentExpression = errExpr
                if !isPlayingSequence { playSequence(errCfg.sequence) }
                playSound(errCfg.sound)
                messages.append(ChatMessage(role: .assistant, content: "error", expression: errExpr))
            } else {
                currentExpression = .sad
                if !isPlayingSequence { playSequence("error") }
                playSound("error")
                messages.append(ChatMessage(role: .assistant, content: "error", expression: .sad))
            }
            // 错误后自动恢复
            DispatchQueue.main.asyncAfter(deadline: .now() + exprConfig.errorRecoverSec) { [weak self] in
                self?.conversationState = .idle
                self?.currentExpression = .normal
                self?.lookX = 0; self?.lookY = 0
                if self?.config.autoListen == true { self?.startListening() }
            }
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
        currentExpression = .thinking
        let tl = exprConfig.look(for: "thinking")
        lookX = tl.0; lookY = tl.1
        
        if let (expr, cmd) = detectCommand(trimmed) {
            isProcessing = false
            playSound(cmd)
            if cmd == "camera" { cameraActive = true; return }
            currentExpression = expr
            playSequence(exprConfig.commandSequence)
            DispatchQueue.main.asyncAfter(deadline: .now() + exprConfig.commandDurationSec) { [weak self] in
                self?.conversationState = .idle; self?.currentExpression = .normal
            }
            return
        }
        
        do {
            let (response, tokens) = try await aiService.sendMessage(trimmed)
            isProcessing = false
            debugInfo.tokens = tokens
            debugInfo.totalTokens += tokens
            let aiEmotion = parseEmotion(response)
            logDebug(\.aiOutput, response)
            logDebug(\.expression, aiEmotion.displayName)
            logDebug(\.workflow, "表情: \(aiEmotion.displayName)")
            messages.append(ChatMessage(role: .assistant, content: response, expression: aiEmotion))
            respondLikePet(userMood: detectedMood, aiEmotion: aiEmotion)
            refreshBalance()
        } catch {
            isProcessing = false
            conversationState = .error(error.localizedDescription)
            logDebug(\.aiOutput, "错误: \(error.localizedDescription)")
            logDebug(\.workflow, "请求失败")
            if let errCfg = exprConfig.errorResponse,
               let errExpr = ExpressionType(rawValue: errCfg.expression) {
                currentExpression = errExpr
                if !isPlayingSequence { playSequence(errCfg.sequence) }
                playSound(errCfg.sound)
                messages.append(ChatMessage(role: .assistant, content: "error", expression: errExpr))
            } else {
                currentExpression = .sad
                if !isPlayingSequence { playSequence("error") }
                playSound("error")
                messages.append(ChatMessage(role: .assistant, content: "error", expression: .sad))
            }
            // 错误后自动恢复
            DispatchQueue.main.asyncAfter(deadline: .now() + exprConfig.errorRecoverSec) { [weak self] in
                self?.conversationState = .idle
                self?.currentExpression = .normal
                self?.lookX = 0; self?.lookY = 0
                if self?.config.autoListen == true { self?.startListening() }
            }
        }
    }
    
    /// AI 只输出一个情绪词，直接解析
    private func parseEmotion(_ text: String) -> ExpressionType {
        let word = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
            .lowercased()
        return ExpressionType(rawValue: word) ?? detectEmotion(text)
    }
    
    // MARK: - 宠物回应（感知情绪 + AI 推理 → 表情）
    
    private func respondLikePet(userMood: ExpressionType, aiEmotion: ExpressionType) {
        conversationState = .speaking
        stopSequence()
        
        // 根据用户情绪选回应方式
        let empathyName = exprConfig.empathy(for: userMood.rawValue)
        let empathyExpr = empathyName.flatMap { ExpressionType(rawValue: $0) }
        let finalExpr = empathyExpr ?? aiEmotion
        playSound(finalExpr.rawValue)
        
        // 长时间情绪低落 → 主动安慰
        if isUserSad(), let comfort = exprConfig.comfort {
            playSequence(comfort.sequence)
            let comfortExpr = ExpressionType(rawValue: comfort.expression) ?? .happy
            DispatchQueue.main.asyncAfter(deadline: .now() + exprConfig.responseDelaySec) { [weak self] in
                self?.currentExpression = comfortExpr
                self?.startSpeakingCycle(comfortExpr)
            }
        } else if let seqName = exprConfig.sequenceName(for: finalExpr.rawValue) {
            playSequence(seqName)
            DispatchQueue.main.asyncAfter(deadline: .now() + exprConfig.responseDelaySec) { [weak self] in
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + exprConfig.speakingDurationSec) { [weak self] in
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
        let negative = Set(exprConfig.negativeEmotions.compactMap { ExpressionType(rawValue: $0) })
        let negCount = recent.filter { negative.contains($0) }.count
        return negCount >= 3
    }
    
    // MARK: - 摇晃感知
    
    private func detectShake(_ data: AccelerometerData?) {
        guard let data = data else { return }
        if case .error = conversationState { return }
        let mag = data.magnitude
        let delta = abs(mag - lastAccel)
        let now = Date()
        lastAccel = mag
        
        // 敲击检测（单次脉冲，阈值较低）
        if delta > exprConfig.knock.threshold, delta < exprConfig.shake.threshold {
            if now.timeIntervalSince(lastSpikeTime) > exprConfig.knock.recoverSeconds {
                let kc = exprConfig.knock
                if let expr = ExpressionType(rawValue: kc.e) {
                    currentExpression = expr
                    debugInfo.expression = expr.displayName
                    debugInfo.workflow = "敲击"
                }
                lookX = kc.lx ?? 0; lookY = kc.ly ?? -0.4
                playSound(kc.s)
                lastSpikeTime = now
                DispatchQueue.main.asyncAfter(deadline: .now() + exprConfig.knock.recoverSeconds) { [weak self] in
                    if self?.currentExpression == expr { self?.currentExpression = .normal }
                }
            }
            return
        }
        
        // 摇晃检测（连续尖峰，阈值较高）
        if delta > exprConfig.shake.threshold {
            if now.timeIntervalSince(lastSpikeTime) > exprConfig.knock.recoverSeconds { spikeCount = 0 }
            spikeCount += 1
            lastSpikeTime = now
            
            if spikeCount >= exprConfig.shake.spikeCount {
                if !isDizzy {
                    isDizzy = true
                    if let expr = ExpressionType(rawValue: exprConfig.shake.e) {
                        currentExpression = expr
                        debugInfo.expression = expr.displayName
                        debugInfo.workflow = "摇晃"
                    }
                    playSound(exprConfig.shake.s)
                    spikeCount = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + exprConfig.shake.dizzySeconds) { [weak self] in
                        self?.isDizzy = false
                        self?.currentExpression = .normal
                    }
                }
            }
        }
    }
    
    // MARK: - 传感器触发系统
    
    private var lastTriggerTime: [String: Date] = [:]
    private var lastAnyTriggerTime: Date?
    private var lastTriggerDuration: Double?
    private var stillSince: Date?
    private var lastAltitude: Double?
    private var lastStepCount: Int = 0
    private var lastStepTime: Date?
    private func rad2deg(_ rad: Double) -> Double { rad * 180 / .pi }
    
    /// 统一传感器检测入口，每个触发由 JSON 配置驱动
    func detectSensorTriggers(accel: AccelerometerData? = nil,
                               gyro: GyroscopeData? = nil,
                               attitude: DeviceAttitude? = nil,
                               speedKmh: Double? = nil,
                               altitude: Double? = nil,
                               stepCount: Int? = nil,
                               proximity: Bool? = nil,
                               lux: Double? = nil) {
        guard !isPlayingSequence, !isDizzy else { return }
        let now = Date()
        
        // 全局冷却：上一个传感器表情结束前不触发新的
        if let lastAny = lastAnyTriggerTime, let lastDuration = lastTriggerDuration,
           now.timeIntervalSince(lastAny) < lastDuration { return }
        
        // 读取 JSON 配置列表中每一项来检测
        let triggers = exprConfig.sensorTriggers
        for (triggerName, cfg) in triggers {
            // 防重复：上次触发后时间 < 配置的恢复时间
            if let last = lastTriggerTime[triggerName],
               now.timeIntervalSince(last) < cfg.t * 2 { continue }
            
            let triggered: Bool = {
                // 通用多传感器检测：JSON 里有值的条件全部需满足（AND）
                let c = cfg
                var ok = true
                
                if let v = c.pitch { ok = ok && rad2deg(attitude?.pitch ?? 0) < v }
                if let v = c.roll { ok = ok && abs(rad2deg(attitude?.roll ?? 0)) > v }
                if let v = c.gyroRate { ok = ok && (gyro != nil ? sqrt(gyro!.x*gyro!.x + gyro!.y*gyro!.y + gyro!.z*gyro!.z) : 0) > v }
                if let v = c.speedKmh { ok = ok && (speedKmh ?? 0) > v }
                if let v = c.accelBelow { ok = ok && (accel?.magnitude ?? 1.0) < v }
                if let v = c.stillSeconds {
                    let moving = accel?.isMoving ?? false
                    if !moving {
                        if stillSince == nil { stillSince = now }
                        ok = ok && now.timeIntervalSince(stillSince!) > v
                    } else { stillSince = nil; ok = false }
                }
                if let v = c.luxBelow { ok = ok && (lux ?? 999) < v }
                if let v = c.altChange {
                    if let alt = altitude, let last = lastAltitude {
                        let change = alt - last
                        lastAltitude = alt
                        ok = ok && (v > 0 ? change > v : change < v)
                    } else { lastAltitude = altitude; ok = false }
                }
                if let v = c.stepsPerMin {
                    if let steps = stepCount, steps > lastStepCount {
                        let now2 = Date()
                        if let lt = lastStepTime {
                            let mins = now2.timeIntervalSince(lt) / 60.0
                            let sd = steps - lastStepCount
                            ok = ok && Int(Double(sd) / max(mins, 0.01)) >= v
                        }
                        lastStepCount = steps; lastStepTime = now2
                    }
                }
                if let v = c.proximity { ok = ok && proximity == v }
                
                return ok && !cfg.e.isEmpty  // 至少指定了表情才算条件生效
            }()
            
            if triggered {
                lastTriggerTime[triggerName] = now
                lastAnyTriggerTime = now
                lastTriggerDuration = cfg.t
                if let expr = ExpressionType(rawValue: cfg.e) {
                    currentExpression = expr
                    debugInfo.expression = expr.displayName
                    debugInfo.workflow = "传感器: \(triggerName)"
                }
                if let sound = cfg.s {
                    playSound(sound)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + cfg.t) { [weak self] in
                    if self?.isPlayingSequence == false, self?.isDizzy == false {
                        self?.currentExpression = .normal
                    }
                }
                break  // 一次只触发一个，避免表达式轮番跳跃
            }
        }
    }
    
    func playSound(_ name: String) {
        let filename = exprConfig.soundMap[name]
        SoundService.shared.play(name, filename: filename)
    }
    
    // MARK: - 说话期间表情循环
    
    private func startSpeakingCycle(_ baseEmotion: ExpressionType) {
        let names = exprConfig.cluster(for: baseEmotion.rawValue)
        speakingCycle = names.compactMap { ExpressionType(rawValue: $0) }
        speakingCycleIndex = 0
        speakingCycleTimer?.cancel()
        speakingCycleTimer = Timer.publish(every: exprConfig.speakingCycleIntervalSec, on: .main, in: .common)
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
        if let name = exprConfig.detectEmotion(from: text),
           let expr = ExpressionType(rawValue: name) {
            return expr
        }
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
    
    func refreshBalance() {
        guard config.debugMode else { return }
        Task {
            if let info = try? await aiService.fetchBalance() {
                debugInfo.balance = "\(info.totalBalance)"
            }
        }
    }
}

extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmojiPresentation
    }
}
