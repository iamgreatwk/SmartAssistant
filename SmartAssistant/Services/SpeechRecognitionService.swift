import Speech
import AVFoundation
import Combine

/// 语音识别服务 — 实时语音转文字
class SpeechRecognitionService: NSObject, ObservableObject {
    
    @Published var isRecognizing = false
    @Published var recognizedText: String = ""
    @Published var partialText: String = ""  // 实时识别结果
    @Published var isAvailable = false
    @Published var errorMessage: String?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var silenceTimer: Timer?
    private var lastSpeechTime: Date?
    private let silenceThreshold: TimeInterval = 1.5  // 静音检测阈值
    
    var onFinalResult: ((String) -> Void)?
    var onPartialResult: ((String) -> Void)?
    var onSilenceDetected: (() -> Void)?
    
    override init() {
        super.init()
        checkAvailability()
    }
    
    // MARK: - 检查可用性
    
    private func checkAvailability() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.isAvailable = status == .authorized
            }
        }
    }
    
    // MARK: - 开始识别
    
    func startRecognition() throws {
        // 停止之前的识别
        stopRecognition()
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "SpeechRecognition", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建识别请求"])
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        
        // 配置音频
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // 启动识别任务
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                
                DispatchQueue.main.async {
                    self.partialText = text
                    self.lastSpeechTime = Date()
                }
                
                self.onPartialResult?(text)
                
                // 最终结果
                if result.isFinal {
                    DispatchQueue.main.async {
                        self.recognizedText = text
                    }
                    self.handleFinalResult(text)
                }
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
                print("语音识别错误: \(error.localizedDescription)")
            }
        }
        
        DispatchQueue.main.async {
            self.isRecognizing = true
            self.recognizedText = ""
            self.partialText = ""
        }
        
        // 启动静音检测
        startSilenceDetection()
    }
    
    // MARK: - 停止识别
    
    func stopRecognition() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        
        stopSilenceDetection()
        
        DispatchQueue.main.async {
            self.isRecognizing = false
        }
    }
    
    // MARK: - 处理最终结果
    
    private func handleFinalResult(_ text: String) {
        onFinalResult?(text)
    }
    
    // MARK: - 静音检测
    
    private func startSilenceDetection() {
        lastSpeechTime = Date()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, let lastTime = self.lastSpeechTime else { return }
            
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed > self.silenceThreshold && !self.partialText.isEmpty {
                self.onSilenceDetected?()
                self.stopRecognition()
            }
        }
    }
    
    private func stopSilenceDetection() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        lastSpeechTime = nil
    }
}
