import AVFoundation

/// 音效播放服务 — 音频文件优先，无文件时自动生成 beep 兜底
class SoundService {
    static let shared = SoundService()
    
    private var players: [String: AVAudioPlayer] = [:]
    private let beepVolume: Float = 0.6
    
    private init() {
        configureSession()
    }
    
    private func configureSession() {
        // 不覆盖 AppDelegate 设置的 .playAndRecord 类别
        // AVAudioSession 已在 AppDelegate 中配置好
    }

    /// 播放指定名称的音效（优先音频文件，无文件用 beep 兜底）
    func play(_ name: String, filename: String? = nil) {
        // 确保音频会话激活（AppDelegate 已设好 category）
        try? AVAudioSession.sharedInstance().setActive(true)
        let file = filename ?? name
        
        // 1. 尝试从 Bundle 加载音频文件
        if let url = Bundle.main.url(forResource: file, withExtension: nil) ??
                     Bundle.main.url(forResource: file, withExtension: "wav") ??
                     Bundle.main.url(forResource: file, withExtension: "mp3") ??
                     Bundle.main.url(forResource: file, withExtension: "m4a") {
            playFile(url: url)
            return
        }
        
        // 2. 无文件 → 生成 beep 兜底
        playGeneratedBeep(name: name)
    }
    
    // MARK: - 文件播放
    
    private func playFile(url: URL) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = beepVolume
            player.prepareToPlay()
            player.play()
            // 保持引用防止被释放
            players[url.lastPathComponent] = player
        } catch {
            print("SoundService: 播放失败 \(url.lastPathComponent) - \(error)")
            // 播放失败也尝试 beep 兜底
            playGeneratedBeep(name: "error")
        }
    }
    
    // MARK: - 生成 beep 兜底
    
    private func playGeneratedBeep(name: String) {
        let duration = 0.12
        let sampleRate = 44100.0
        let frequency: Double = {
            switch name {
            case "error", "dizzy": return 400
            case "happy", "excited", "veryHappy", "love": return 1200
            case "sad", "sleepy": return 300
            case "surprised", "camera": return 800
            default: return 800
            }
        }()
        
        let samples = Int(duration * sampleRate)
        let bytes = samples * 2
        var wav = Data(capacity: 44 + bytes)
        
        // WAV header
        wav.append(contentsOf: "RIFF".utf8)
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(36 + bytes).littleEndian) { Array($0) })
        wav.append(contentsOf: "WAVE".utf8)
        wav.append(contentsOf: "fmt ".utf8)
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate * 2).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })
        wav.append(contentsOf: "data".utf8)
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(bytes).littleEndian) { Array($0) })
        
        // 生成正弦波
        for i in 0..<samples {
            let t = Double(i) / sampleRate
            let envelope = 1.0 - (t / duration)
            let sample = Int16(sin(2 * .pi * frequency * t) * 32767 * envelope * 0.5)
            wav.append(contentsOf: withUnsafeBytes(of: sample.littleEndian) { Array($0) })
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("sfx_\(name).wav")
        try? wav.write(to: tempURL)
        
        if let player = try? AVAudioPlayer(contentsOf: tempURL) {
            player.volume = beepVolume * 0.8
            player.play()
            // 保持引用
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) { [weak self] in
                self?.players.removeValue(forKey: tempURL.lastPathComponent)
            }
            players[tempURL.lastPathComponent] = player
        }
    }
}
