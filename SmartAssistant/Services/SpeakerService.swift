import AVFoundation
import Combine

/// 扬声器/TTS 服务 — 文字转语音、音频播放
class SpeakerService: NSObject, ObservableObject {
    
    @Published var isSpeaking = false
    @Published var ttsProgress: Double = 0.0
    
    private let synthesizer = AVSpeechSynthesizer()
    private var config = TTSConfig()
    private var speakCompletion: (() -> Void)?
    
    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }
    
    // MARK: - 配置音频会话
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [
                .defaultToSpeaker,    // 默认使用扬声器
                .allowBluetooth,       // 允许蓝牙
                .allowAirPlay          // 允许 AirPlay
            ])
            try session.setActive(true)
        } catch {
            print("音频会话配置失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 文字转语音
    
    func speak(_ text: String, config: TTSConfig? = nil, completion: (() -> Void)? = nil) {
        let ttsConfig = config ?? self.config
        self.speakCompletion = completion
        
        // 如果正在说话，先停止
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = ttsConfig.rate * AVSpeechUtteranceMaximumSpeechRate
        utterance.pitchMultiplier = ttsConfig.pitch
        utterance.volume = ttsConfig.volume
        utterance.preUtteranceDelay = ttsConfig.preUtteranceDelay
        utterance.postUtteranceDelay = ttsConfig.postUtteranceDelay
        
        // 设置语音
        if let voice = AVSpeechSynthesisVoice(identifier: ttsConfig.voiceIdentifier) {
            utterance.voice = voice
        } else if let voice = AVSpeechSynthesisVoice(language: "zh-CN") {
            utterance.voice = voice  // 降级到默认中文
        }
        
        DispatchQueue.main.async { self.isSpeaking = true }
        synthesizer.speak(utterance)
    }
    
    // MARK: - 停止说话
    
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        DispatchQueue.main.async { self.isSpeaking = false }
    }
    
    // MARK: - 暂停/继续
    
    func pauseSpeaking() {
        synthesizer.pauseSpeaking(at: .immediate)
    }
    
    func continueSpeaking() {
        synthesizer.continueSpeaking()
    }
    
    // MARK: - 播放提示音
    
    func playBeep() {
        AudioServicesPlaySystemSound(1057) // 系统提示音
    }
    
    func playStartListeningSound() {
        AudioServicesPlaySystemSound(1113) // 开始录音提示
    }
    
    func playStopListeningSound() {
        AudioServicesPlaySystemSound(1114) // 停止录音提示
    }
    
    // MARK: - 语音配置
    
    func updateConfig(_ newConfig: TTSConfig) {
        self.config = newConfig
    }
    
    /// 获取可用语音列表
    func availableVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices()
    }
    
    /// 获取中文语音列表
    func chineseVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.starts(with: "zh")
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeakerService: AVSpeechSynthesizerDelegate {
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = true
            self?.ttsProgress = 0
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            self?.ttsProgress = 1.0
            self?.speakCompletion?()
            self?.speakCompletion = nil
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            self?.ttsProgress = 0
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let progress = Double(characterRange.location + characterRange.length) / Double(utterance.speechString.count)
        DispatchQueue.main.async { [weak self] in
            self?.ttsProgress = progress
        }
    }
}
