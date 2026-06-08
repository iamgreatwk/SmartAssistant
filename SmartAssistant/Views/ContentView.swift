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
                Color.black.ignoresSafeArea()
                
                ExpressionWebView(
                    mood: chatVM.currentExpression.rawValue,
                    lookX: chatVM.lookX,
                    lookY: chatVM.lookY,
                    isFullscreen: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture { handleTap() }
                
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
                
                settingsDrawer(width: geo.size.width)
                leftEdgeDragZone(width: geo.size.width)
                
                if let photo = chatVM.capturedPhoto {
                    photoCard(photo: photo, width: geo.size.width, height: geo.size.height)
                }
                
                if chatVM.getConfig().debugMode {
                    debugOverlay(width: geo.size.width)
                }
            }
            .onAppear {
                screenWidth = geo.size.width
                settingsOffset = -screenWidth
            }
            .onChange(of: geo.size.width) { _, w in
                screenWidth = w
                if !showSettings { settingsOffset = -w }
            }
        }
        .onAppear {
            guard !hasAutoStarted else { return }
            hasAutoStarted = true
            sensorVM.startAllSensors()
            chatVM.refreshBalance()
            Task {
                await permissionManager.requestAllPermissions()
                try? await Task.sleep(for: .milliseconds(500))
                if permissionManager.microphoneStatus != .denied,
                   permissionManager.speechRecognitionStatus != .denied {
                    chatVM.startListening()
                }
            }
        }
        .onChange(of: chatVM.cameraActive) { _, active in
            if active { 
                cameraService.start()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    cameraService.capturePhoto()
                }
            }
        }
        .onChange(of: cameraService.capturedImage) { _, img in
            guard let img = img, chatVM.cameraActive else { return }
            chatVM.capturedPhoto = img
            chatVM.cameraActive = false
            chatVM.currentExpression = .excited
            cameraService.stop()
            showPhoto()
        }
    }
    
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
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.3), lineWidth: 1))
                    .shadow(color: .black.opacity(0.5), radius: 20)
                    .offset(x: photoOffset)
                    .opacity(photoOpacity)
                    .gesture(
                        DragGesture()
                            .onChanged { v in photoOffset = v.translation.width }
                            .onEnded { v in
                                if v.translation.width > 80 { savePhoto(photo); dismissPhoto() }
                                else if v.translation.width < -80 { dismissPhoto() }
                                else { withAnimation(.spring()) { photoOffset = 0 } }
                            }
                    )
                Spacer()
            }
            .padding(.trailing, 12)
        }
    }
    
    private func showPhoto() { photoOffset = screenWidth; photoOpacity = 0; withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { photoOffset = 0; photoOpacity = 1 } }
    private func dismissPhoto() {
        withAnimation(.easeInOut(duration: 0.3)) { photoOffset = screenWidth; photoOpacity = 0 }
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
                DispatchQueue.main.async { chatVM.currentExpression = .love; chatVM.playSound("camera") }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismissPhoto() }
    }
    
    private func debugOverlay(width: CGFloat) -> some View {
        HStack {
            Spacer()
            VStack(alignment: .leading, spacing: 1) {
                Text("识别: \(chatVM.debugInfo.sttText)")
                Text("输入: \(chatVM.debugInfo.aiInput)")
                Text("输出: \(chatVM.debugInfo.aiOutput)")
                Text("表情: \(chatVM.debugInfo.expression)")
                Text("状态: \(chatVM.debugInfo.workflow)")
                Text("本次: \(chatVM.debugInfo.tokens)t  总计: \(chatVM.debugInfo.totalTokens)t")
                if !chatVM.debugInfo.balance.isEmpty {
                    Text("余额: ¥\(chatVM.debugInfo.balance)")
                }
                if !chatVM.debugInfo.sensor.isEmpty {
                    Text("传感器: \(chatVM.debugInfo.sensor)")
                }
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(.green.opacity(0.7))
            .padding(6)
            .frame(width: min(width * 0.28, 240), alignment: .leading)
            .background(.black.opacity(0.85))
            .cornerRadius(8)
            .padding(.trailing, 4)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private func handleTap() {}
    
    private func settingsDrawer(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            SettingsView(chatVM: chatVM, sensorVM: sensorVM).frame(width: width * 0.85).background(Color(.systemGroupedBackground))
            Color.black.opacity(0.01).onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showSettings = false; settingsOffset = -width }
            }
        }
        .offset(x: settingsOffset)
        .gesture(DragGesture()
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
                .gesture(DragGesture(minimumDistance: 10)
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
