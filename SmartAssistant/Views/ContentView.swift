import SwiftUI

// MARK: - 主视图 (纯表情 + 右滑设置)

struct ContentView: View {
    @StateObject private var chatVM = ChatViewModel()
    @StateObject private var sensorVM = SensorViewModel()
    @StateObject private var permissionManager = PermissionManager()
    
    @State private var deviceRotation: Double = 0
    @State private var showSettings: Bool = false
    @State private var settingsOffset: CGFloat = -UIScreen.main.bounds.width
    @State private var hasAutoStarted = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 全屏表情 (始终显示)
                Color.black.ignoresSafeArea()
                
                ExpressionView(
                    expression: chatVM.currentExpression,
                    speakingLevel: chatVM.speakingLevel,
                    isFullscreen: true,
                    lookX: chatVM.lookX,
                    lookY: chatVM.lookY
                )
                .rotationEffect(.degrees(deviceRotation))
                .animation(.easeInOut(duration: 0.3), value: deviceRotation)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture {
                    handleTap()
                }
                
                // 右上角设置按钮
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showSettings.toggle()
                                settingsOffset = showSettings ? 0 : -geo.size.width
                            }
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundColor(Color.white.opacity(0.35))
                                .padding(12)
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 50)
                    }
                    Spacer()
                }
                
                // 设置抽屉 (右滑)
                settingsDrawer(width: geo.size.width)
                
                // 左边缘拖拽手势
                leftEdgeDragZone(width: geo.size.width)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let orient = UIDevice.current.orientation
            withAnimation(.easeInOut(duration: 0.3)) {
                switch orient {
                case .landscapeLeft:  deviceRotation = -90
                case .landscapeRight: deviceRotation = 90
                case .portraitUpsideDown: deviceRotation = 180
                default: deviceRotation = 0
                }
            }
        }
        .onAppear {
            guard !hasAutoStarted else { return }
            hasAutoStarted = true
            
            // 后台启动传感器
            sensorVM.startAllSensors()
            
            // 等权限完成后再自动开始对话
            Task {
                await permissionManager.requestAllPermissions()
                // 给系统一点时间稳定
                try? await Task.sleep(for: .milliseconds(500))
                // 确认关键权限已授权再开始
                if permissionManager.microphoneStatus != .denied,
                   permissionManager.speechRecognitionStatus != .denied {
                    chatVM.startListening()
                }
            }
        }
    }
    
    // MARK: - 交互
    
    private func handleTap() {
        if chatVM.isListening {
            chatVM.stopListening()
        } else if chatVM.isSpeaking {
            chatVM.stopSpeaking()
        } else {
            chatVM.startListening()
        }
    }
    
    // MARK: - 设置抽屉
    
    private func settingsDrawer(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            SettingsView(chatVM: chatVM, sensorVM: sensorVM)
                .frame(width: width * 0.85)
                .background(Color(.systemGroupedBackground))
            
            // 右侧空白区 (点击关闭)
            Color.black.opacity(0.01)
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showSettings = false
                        settingsOffset = -width
                    }
                }
        }
        .offset(x: settingsOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if showSettings {
                        settingsOffset = min(0, value.translation.width)
                    }
                }
                .onEnded { value in
                    if value.translation.width < -50 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showSettings = false
                            settingsOffset = -width
                        }
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            settingsOffset = 0
                        }
                    }
                }
        )
    }
    
    // MARK: - 左边缘拖拽
    
    private func leftEdgeDragZone(width: CGFloat) -> some View {
        HStack {
            Color.white.opacity(0.001)
                .frame(width: 30)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            if !showSettings && value.startLocation.x < 30 {
                                settingsOffset = min(0, -width + value.translation.width)
                            }
                        }
                        .onEnded { value in
                            if value.translation.width > 60 {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showSettings = true
                                    settingsOffset = 0
                                }
                            } else {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showSettings = false
                                    settingsOffset = -width
                                }
                            }
                        }
                )
            Spacer()
        }
    }
}
