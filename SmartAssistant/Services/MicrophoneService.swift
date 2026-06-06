import AVFoundation
import Combine

/// 麦克风服务 — 录音、音量检测、音频数据流
class MicrophoneService: NSObject, ObservableObject {
    
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0  // 当前音量 0.0-1.0
    @Published var peakLevel: Float = 0.0   // 峰值音量
    @Published var isSpeaking: Bool = false  // 是否检测到说话
    
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    
    private var levelTimer: Timer?
    private let speechThreshold: Float = 0.05  // 说话检测阈值
    private let updateInterval: TimeInterval = 0.1
    
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    
    override init() {
        inputNode = audioEngine.inputNode
        super.init()
    }
    
    // MARK: - 开始录音监听
    
    func startMonitoring() {
        guard !isRecording else { return }
        
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        do {
            try audioEngine.start()
            isRecording = true
            startLevelMonitoring()
        } catch {
            print("音频引擎启动失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 停止录音监听
    
    func stopMonitoring() {
        guard isRecording else { return }
        
        inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        stopLevelMonitoring()
        
        isRecording = false
        audioLevel = 0
        peakLevel = 0
        isSpeaking = false
    }
    
    // MARK: - 音量级别处理
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let channelDataArray = Array(UnsafeBufferPointer(start: channelDataValue, count: Int(buffer.frameLength)))
        
        // 计算 RMS (均方根)
        var sum: Float = 0
        for sample in channelDataArray {
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(buffer.frameLength))
        
        // 转换为 dB 然后映射到 0-1
        let db = 20 * log10(max(rms, 0.00001))
        let normalizedLevel = max(0, min(1, (db + 50) / 50))
        
        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = normalizedLevel
            self?.peakLevel = max(self?.peakLevel ?? 0, normalizedLevel)
            self?.isSpeaking = normalizedLevel > self?.speechThreshold ?? 0.05
        }
        
        onAudioBuffer?(buffer)
    }
    
    // MARK: - 音量峰值衰减
    
    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // 峰值缓慢衰减
                self.peakLevel = max(0, self.peakLevel - 0.02)
            }
        }
    }
    
    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    // MARK: - 录音（保存文件）
    
    func startRecording(to url: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        // 这里可以使用 AVAudioRecorder 进行文件录音
        // 如需完整实现，请配合 AudioSession 配置
    }
}
