import SwiftUI

// MARK: - 主视图

struct ContentView: View {
    @StateObject private var chatVM = ChatViewModel()
    @StateObject private var sensorVM = SensorViewModel()
    @StateObject private var permissionManager = PermissionManager()
    
    @State private var selectedTab: Tab = .chat
    @State private var showPermissionAlert = false
    
    enum Tab: String, CaseIterable {
        case chat = "对话"
        case settings = "设置"
        
        var icon: String {
            switch self {
            case .chat: return "message.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ChatView(chatVM: chatVM)
                    .tabItem {
                        Label(Tab.chat.rawValue, systemImage: Tab.chat.icon)
                    }
                    .tag(Tab.chat)
                
                SettingsView(chatVM: chatVM, sensorVM: sensorVM)
                    .tabItem {
                        Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                    }
                    .tag(Tab.settings)
            }
            .accentColor(.blue)
        }
        .onAppear {
            startServices()
        }
        .alert("需要权限", isPresented: $showPermissionAlert) {
            Button("去设置") { permissionManager.openSettings() }
            Button("取消", role: .cancel) { }
        } message: {
            Text("小智助手需要访问麦克风和语音识别权限才能正常工作。请在设置中开启。")
        }
    }
    
    private func startServices() {
        // 后台启动传感器（不显示UI但数据可用）
        sensorVM.startAllSensors()
        
        Task {
            await permissionManager.requestAllPermissions()
            if permissionManager.microphoneStatus == .denied ||
               permissionManager.speechRecognitionStatus == .denied {
                showPermissionAlert = true
            }
        }
    }
}

// MARK: - 对话视图

struct ChatView: View {
    @ObservedObject var chatVM: ChatViewModel
    @State private var textInput: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var isExpressionFullscreen: Bool = false
    
    var body: some View {
        ZStack {
            // 正常模式
            if !isExpressionFullscreen {
                normalChatView
            } else {
                // 全屏表情模式
                fullscreenExpressionView
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            // 横屏自动进入全屏表情，竖屏退出
            let isLandscape = UIDevice.current.orientation.isLandscape
            if isLandscape != isExpressionFullscreen {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    isExpressionFullscreen = isLandscape
                }
            }
        }
    }
    
    // MARK: - 正常对话模式
    
    private var normalChatView: some View {
        VStack(spacing: 0) {
            // 顶部状态栏
            statusBar
            
            // StackChan 表情角色
            characterView
            
            // 对话状态指示
            stateIndicator
            
            // 消息列表
            messageList
            
            // 输入区域
            inputBar
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - 全屏表情模式
    
    private var fullscreenExpressionView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ExpressionView(
                expression: chatVM.currentExpression,
                speakingLevel: chatVM.speakingLevel
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 退出按钮
            VStack {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            isExpressionFullscreen = false
                        }
                    } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 50)
                }
                Spacer()
            }
        }
    }
    
    // MARK: - 状态栏
    
    private var statusBar: some View {
        HStack {
            Text("小智助手")
                .font(.headline)
                .fontWeight(.bold)
            
            Spacer()
            
            // 全屏表情按钮
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    isExpressionFullscreen.toggle()
                }
            } label: {
                Image(systemName: isExpressionFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            ConversationStatusBadge(state: chatVM.conversationState)
            
            Button {
                chatVM.clearConversation()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - 角色视图
    
    private var characterView: some View {
        ExpressionView(
            expression: chatVM.currentExpression,
            speakingLevel: chatVM.speakingLevel
        )
        .frame(height: 180)
        .padding(.vertical, 4)
        .onTapGesture {
            if chatVM.conversationState == ChatViewModel.ConversationState.idle {
                chatVM.startListening()
            } else if chatVM.conversationState == .speaking {
                chatVM.stopSpeaking()
            }
        }
    }
    
    // MARK: - 状态指示器
    
    private var stateIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)
            
            Text(stateText)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if chatVM.isProcessing {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var stateColor: Color {
        switch chatVM.conversationState {
        case .idle: return .gray
        case .listening: return .green
        case .thinking: return .orange
        case .speaking: return .blue
        case .error: return .red
        }
    }
    
    private var stateText: String {
        switch chatVM.conversationState {
        case .idle: return "点击角色或按住输入说话"
        case .listening: return "正在听..."
        case .thinking: return "思考中..."
        case .speaking: return "说话中..."
        case .error(let msg): return "错误: \(msg)"
        }
    }
    
    // MARK: - 消息列表
    
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if chatVM.messages.isEmpty {
                        emptyStateView
                    }
                    
                    ForEach(chatVM.messages) { message in
                        ChatBubble(message: message, expression: $chatVM.currentExpression)
                            .id(message.id)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .onChange(of: chatVM.messages.count) {
                if let last = chatVM.messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text("👋 你好！我是小智")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("按住输入框开始说话，或者打字发消息")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - 输入区域
    
    private var inputBar: some View {
        HStack(spacing: 10) {
            // 语音按钮
            Button {
                if chatVM.isListening {
                    chatVM.stopListening()
                } else {
                    chatVM.startListening()
                }
            } label: {
                Image(systemName: chatVM.isListening ? "mic.fill" : "mic")
                    .font(.title3)
                    .foregroundColor(chatVM.isListening ? .red : .blue)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(chatVM.isListening ? Color.red.opacity(0.15) : Color.blue.opacity(0.1))
                    )
                    .scaleEffect(chatVM.isListening ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: chatVM.isListening)
            }
            
            // 文本输入
            HStack {
                TextField("输入消息...", text: $textInput)
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        sendText()
                    }
                
                if !textInput.isEmpty {
                    Button {
                        sendText()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
    
    private func sendText() {
        guard !textInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let text = textInput
        textInput = ""
        isInputFocused = false
        
        Task {
            await chatVM.sendText(text)
        }
    }
}

// MARK: - 对话状态徽章

struct ConversationStatusBadge: View {
    let state: ChatViewModel.ConversationState
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var color: Color {
        switch state {
        case .idle: return .gray
        case .listening: return .green
        case .thinking: return .orange
        case .speaking: return .blue
        case .error: return .red
        }
    }
    
    private var label: String {
        switch state {
        case .idle: return "就绪"
        case .listening: return "收听"
        case .thinking: return "思考"
        case .speaking: return "播报"
        case .error: return "出错"
        }
    }
}

// MARK: - 聊天气泡

struct ChatBubble: View {
    let message: ChatMessage
    @Binding var expression: ExpressionType
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                Text("🤖")
                    .font(.title3)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                    )
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.role == .user ?
                        Color.blue.opacity(0.85) :
                        Color(.systemGray5)
                    )
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(18)
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                        } label: {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                    }
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if message.role == .user {
                Text("👤")
                    .font(.title3)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.green.opacity(0.1))
                    )
            }
            
            if message.role == .assistant {
                Spacer(minLength: 50)
            }
        }
        .padding(message.role == .user ? .leading : .trailing, 50)
        .onAppear {
            if let expr = message.expression {
                withAnimation(.easeInOut(duration: 0.3)) {
                    expression = expr
                }
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
