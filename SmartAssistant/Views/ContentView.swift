import SwiftUI
import Photos

// MARK: - 主视图 (表情 + 摄像头 + 照片预览)

struct ContentView: View {
    @StateObject private var chatVM = ChatViewModel()
    @StateObject private var sensorVM = SensorViewModel()
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var cameraService = CameraService()
    
    @State private var showSettings: Bool = false
    @State private var settingsOffset: CGFloat = -10000
    @State private var hasAutoStarted = false
    @State private var photoOffset: CGFloat = 10000
    @State private var photoOpacity: Double = 0
    @State private var screenWidth: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 全屏表情
                Color.black.ignoresSafeArea()
                
                ExpressionWebView(
                    mood: chatVM.currentExpression.rawValue,
                    lookX: chatVM.lookX,
                    lookY: chatVM.lookY,
                    isFullscreen: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture { handleTap() }
                
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
                
                // 设置抽屉
                settingsDrawer(width: geo.size.width)
                leftEdgeDragZone(width: geo.size.width)
            }
            .onAppear {
                screenWidth = geo.size.width
                settingsOffset = -screenWidth
            }
            .onChange(of: geo.size.width) { _, w in
                screenWidth = w
                if !showSettings { settingsOffset = -w }
            }
                
                // 照片预览卡片（右侧显示）
                if let photo = chatVM.capturedPhoto {
                    photoCard(photo: photo, width: geo.size.width, height: geo.size.height)
                }
                
                // 调试信息
                if chatVM.getConfig().debugMode {
                    debugOverlay(width: geo.size.width)
                }
            }
        }
        .onAppear {
            guard !hasAutoStarted else { return }
            hasAutoStarted = true
            sensorVM.startAllSensors()
            Task {
                await permissionManager.requestAllPermissions()
                try? await Task.sleep(for: .milliseconds(500))
                if permissionManager.microphoneStatus != .denied,
                   permissionManager.speechRecognitionStatus != .denied {
                    chatVM.startListening()
                }
            }
        }
        .onChange(of: chatVM.cameraActive) { active in
            if active { 
                cameraService.start()
                // 等摄像头启动后自动拍照
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    cameraService.capturePhoto()
                }
            }
        }
        .onChange(of: cameraService.capturedImage) { img in
            guard let img = img, chatVM.cameraActive else { return }
            chatVM.capturedPhoto = img
            chatVM.cameraActive = false
            chatVM.currentExpression = .excited
            cameraService.stop()
            showPhoto()
        }
    }
    
    // MARK: - 照片预览卡片
    
    private func photoCard(photo: UIImage, width: CGFloat, height: CGFloat) -> some View {
        let cardW: CGFloat = min(220, width * 0.55)
        let cardH: CGFloat = cardW * 1.3
        
        return HStack {
            Spacer()
            VStack {
                Spacer()
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardW, height: cardH)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 20)
                    .offset(x: photoOffset)
                    .opacity(photoOpacity)
                    .gesture(
                        DragGesture()
                            .onChanged { v in
                                photoOffset = v.translation.width
                            }
                            .onEnded { v in
                                if v.translation.width > 80 {
                                    // 右滑 → 保存
                                    savePhoto(photo)
                                    dismissPhoto()
                                } else if v.translation.width < -80 {
                                    // 左滑 → 取消
                                    dismissPhoto()
                                } else {
                                    // 回弹
                                    withAnimation(.spring()) { photoOffset = 0 }
                                }
                            }
                    )
                    .overlay(alignment: .top) {
                        HStack(spacing: 0) {
                            Text("← 取消")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                            Spacer()
                            Text("保存 →")
                                .font(.caption2)
                                .foregroundColor(.green.opacity(0.8))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                        }
                        .padding(8)
                    }
                Spacer()
            }
            .padding(.trailing, 12)
        }
    }
    
    private func showPhoto() {
        photoOffset = screenWidth
        photoOpacity = 0
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            photoOffset = 0
            photoOpacity = 1
        }
    }
    
    private func dismissPhoto() {
        withAnimation(.easeInOut(duration: 0.3)) {
            photoOffset = screenWidth
            photoOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            chatVM.capturedPhoto = nil
            chatVM.conversationState = .idle
            chatVM.currentExpression = .normal
            if chatVM.getConfig().autoListen { chatVM.startListening() }
        }
    }
    
    private func savePhoto(_ photo: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized || status == .limited {
                UIImageWriteToSavedPhotosAlbum(photo, nil, nil, nil)
                DispatchQueue.main.async {
                    chatVM.currentExpression = .love
                    chatVM.playSound("camera")
                }
            }
        }
        // 短暂显示爱心后消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismissPhoto()
        }
    }
    
    // MARK: - 调试信息
    
    private func debugOverlay(width: CGFloat) -> some View {
        HStack {
            Spacer()
            VStack(alignment: .leading, spacing: 1) {
                Text("🔊 \(chatVM.debugInfo.sttText)")
                Text("📤 \(chatVM.debugInfo.aiInput)")
                Text("📥 \(chatVM.debugInfo.aiOutput)")
                Text("😊 \(chatVM.debugInfo.expression)")
                Text("🔄 \(chatVM.debugInfo.workflow)")
                Text("🔢 \(chatVM.debugInfo.tokens) tokens")
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(.green.opacity(0.7))
            .padding(8)
            .background(.black.opacity(0.85))
            .cornerRadius(8)
            .padding(.trailing, 8)
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }
    
    // MARK: - 交互
    
    private func handleTap() {
        // 暂不响应屏幕点击
    }
    
    // MARK: - 设置抽屉
    
    private func settingsDrawer(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            SettingsView(chatVM: chatVM, sensorVM: sensorVM)
                .frame(width: width * 0.85)
                .background(Color(.systemGroupedBackground))
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
                .onChanged { v in if showSettings { settingsOffset = min(0, v.translation.width) } }
                .onEnded { v in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if v.translation.width < -50 { showSettings = false; settingsOffset = -width }
                        else { settingsOffset = 0 }
                    }
                }
        )
    }
    
    private func leftEdgeDragZone(width: CGFloat) -> some View {
        HStack {
            Color.white.opacity(0.001).frame(width: 30).contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { v in if !showSettings && v.startLocation.x < 30 { settingsOffset = min(0, -width + v.translation.width) } }
                        .onEnded { v in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                if v.translation.width > 60 { showSettings = true; settingsOffset = 0 }
                                else { showSettings = false; settingsOffset = -width }
                            }
                        }
                )
            Spacer()
        }
    }
}
