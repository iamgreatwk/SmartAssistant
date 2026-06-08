import SwiftUI
import UIKit

// MARK: - 设置视图

struct SettingsView: View {
    @ObservedObject var chatVM: ChatViewModel
    @ObservedObject var sensorVM: SensorViewModel
    @Environment(\.openURL) private var openURL
    
    @State private var config: AppConfig
    @State private var showAPIKey: Bool = false
    @State private var showResetAlert: Bool = false
    @State private var selectedVoiceIndex: Int = 0
    
    init(chatVM: ChatViewModel, sensorVM: SensorViewModel) {
        self.chatVM = chatVM
        self.sensorVM = sensorVM
        self._config = State(initialValue: chatVM.getConfig())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("设置")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("保存") {
                    saveConfig()
                }
                .fontWeight(.semibold)
            }
            .padding(.horizontal)
            .padding(.top, 50)
            .padding(.bottom, 12)
            
            Form {
                // MARK: - AI 配置
                Section {
                    HStack {
                        Text("API 端点")
                        Spacer()
                        TextField("https://api.openai.com/v1/...", text: $config.aiApiEndpoint)
                            .multilineTextAlignment(.trailing)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("API Key")
                        Spacer()
                        if showAPIKey {
                            TextField("sk-...", text: $config.aiApiKey)
                                .multilineTextAlignment(.trailing)
                                .font(.caption)
                        } else {
                            SecureField("••••••••", text: $config.aiApiKey)
                                .multilineTextAlignment(.trailing)
                                .font(.caption)
                        }
                        Button {
                            showAPIKey.toggle()
                        } label: {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("模型")
                        Spacer()
                        TextField("gpt-4o", text: $config.aiModel)
                            .multilineTextAlignment(.trailing)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("余额查询 API")
                        Spacer()
                        TextField("https://api.siliconflow.cn/v1/user/info", text: $config.balanceApiEndpoint)
                            .multilineTextAlignment(.trailing)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Label("AI 对话配置", systemImage: "brain.head.profile")
                } footer: {
                    Text("支持 OpenAI 兼容 API，也可使用其他模型服务")
                }
                
                // MARK: - 系统提示词
                Section {
                    TextEditor(text: $config.systemPrompt)
                        .font(.caption)
                        .frame(minHeight: 100)
                } header: {
                    Label("系统提示词", systemImage: "text.bubble")
                } footer: {
                    Text("定义助手的性格和行为方式")
                }
                
                // MARK: - 语音配置
                Section {
                    Toggle("自动语音监听", isOn: $config.autoListen)
                    
                    HStack {
                        Text("唤醒词")
                        Spacer()
                        TextField("小智", text: $config.wakeWord)
                            .multilineTextAlignment(.trailing)
                            .font(.caption)
                    }
                    
                    Picker("TTS 语音", selection: $chatVM.ttsConfig.voiceIdentifier) {
                        Text("Ting-Ting (推荐)").tag("com.apple.ttsbundle.TingTing-compact")
                        Text("Mei-Jia").tag("com.apple.ttsbundle.Mei-Jia-compact")
                        Text("Sin-Ji").tag("com.apple.ttsbundle.Sin-Ji-compact")
                        Text("系统默认").tag("zh-CN")
                    }
                } header: {
                    Label("语音交互", systemImage: "waveform")
                }
                
                // MARK: - 显示配置
                Section {
                    Toggle("表情动画", isOn: $config.enableExpression)
                    Toggle("传感器面板", isOn: $config.showSensorDashboard)
                    Toggle("调试模式", isOn: $config.debugMode)
                } header: {
                    Label("显示设置", systemImage: "rectangle.3.group")
                }
                
                // MARK: - 传感器控制
                Section {
                    Button {
                        // 传感器由 ChatViewModel 统一管理
                        chatVM.startServices()
                    } label: {
                        HStack {
                            Label("重新启动传感器", systemImage: "antenna.radiowaves.left.and.right")
                            Spacer()
                            Circle()
                                .fill(Color.green)
                                .frame(width: 10, height: 10)
                        }
                    }
                } header: {
                    Label("传感器控制", systemImage: "sensor.fill")
                }
                
                // MARK: - 数据管理
                Section {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("清除对话历史", systemImage: "trash")
                    }
                    
                    Button(role: .destructive) {
                        clearAllData()
                    } label: {
                        Label("重置所有数据", systemImage: "eraser")
                    }
                } header: {
                    Label("数据管理", systemImage: "externaldrive")
                }
                
                // MARK: - 关于
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("构建方式")
                        Spacer()
                        Text("GitHub Actions + AltStore")
                            .foregroundColor(.secondary)
                    }
                    
                    Button {
                        if let url = URL(string: "https://github.com") {
                            openURL(url)
                        }
                    } label: {
                        Label("GitHub 项目", systemImage: "link")
                    }
                } header: {
                    Label("关于", systemImage: "info.circle")
                }
            }
            .alert("确认清除", isPresented: $showResetAlert) {
                Button("取消", role: .cancel) { }
                Button("清除", role: .destructive) {
                    chatVM.clearConversation()
                }
            } message: {
                Text("此操作将清除所有对话历史，不可恢复。")
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private func saveConfig() {
        config.save()
        chatVM.updateConfig(config)
        
        // 触觉反馈
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func clearAllData() {
        UserDefaults.standard.removeObject(forKey: "appConfig")
        chatVM.clearConversation()
        config = AppConfig()
        saveConfig()
    }
}
