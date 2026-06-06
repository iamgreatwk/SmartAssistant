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
        NavigationView {
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
                } header: {
                    Label("语音交互", systemImage: "waveform")
                }
                
                // MARK: - 显示配置
                Section {
                    Toggle("表情动画", isOn: $config.enableExpression)
                    Toggle("传感器面板", isOn: $config.showSensorDashboard)
                } header: {
                    Label("显示设置", systemImage: "rectangle.3.group")
                }
                
                // MARK: - 传感器控制
                Section {
                    Button {
                        sensorVM.startAllSensors()
                    } label: {
                        Label("启动所有传感器", systemImage: "play.fill")
                    }
                    
                    Button {
                        sensorVM.stopAllSensors()
                    } label: {
                        Label("停止所有传感器", systemImage: "stop.fill")
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
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveConfig()
                    }
                    .fontWeight(.semibold)
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
