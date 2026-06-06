import SwiftUI

/// StackChan 风格表情视图 — 核心动画角色
struct ExpressionView: View {
    let expression: ExpressionType
    let size: CGFloat
    let speakingLevel: CGFloat  // 0.0-1.0 说话音量级别
    
    @State private var blinkState: Bool = false
    @State private var floatOffset: CGFloat = 0
    @State private var rotation: Double = 0
    
    private let timer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()
    private let floatTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    init(expression: ExpressionType, size: CGFloat = 200, speakingLevel: CGFloat = 0) {
        self.expression = expression
        self.size = size
        self.speakingLevel = speakingLevel
    }
    
    var body: some View {
        ZStack {
            // 身体/头部
            headShape
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFE4B5"), Color(hex: "FFD700")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.15), radius: size * 0.05, x: 0, y: size * 0.02)
            
            // 脸部特征
            faceFeatures
        }
        .frame(width: size, height: size)
        .offset(y: floatOffset)
        .rotationEffect(.degrees(rotation))
        .onReceive(timer) { _ in
            blink()
        }
        .onReceive(floatTimer) { _ in
            updateFloat()
        }
        .onAppear {
            // 初始浮动
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                floatOffset = size * 0.02
            }
        }
    }
    
    // MARK: - 头部形状
    
    private var headShape: some View {
        RoundedRectangle(cornerRadius: size * 0.25)
    }
    
    // MARK: - 脸部特征
    
    private var faceFeatures: some View {
        let params = expression.params
        
        return ZStack {
            // 腮红
            if params.cheekColor > 0 {
                cheekBlush(intensity: params.cheekColor)
            }
            
            // 眉毛
            eyebrows(angle: params.eyebrowAngle, expression: expression)
            
            // 眼睛
            eyes(params: params)
            
            // 眼泪
            if params.tearVisible {
                tears()
            }
            
            // 星星眼
            if params.sparkleVisible {
                sparkles()
            }
            
            // 嘴巴
            mouth(type: params.mouthType, scale: params.mouthScale, speakingLevel: speakingLevel)
        }
    }
    
    // MARK: - 腮红
    
    private func cheekBlush(intensity: CGFloat) -> some View {
        HStack(spacing: size * 0.45) {
            Circle()
                .fill(Color.pink.opacity(intensity * 0.3))
                .frame(width: size * 0.15, height: size * 0.08)
                .blur(radius: size * 0.02)
            Circle()
                .fill(Color.pink.opacity(intensity * 0.3))
                .frame(width: size * 0.15, height: size * 0.08)
                .blur(radius: size * 0.02)
        }
        .offset(y: size * 0.08)
    }
    
    // MARK: - 眉毛
    
    private func eyebrows(angle: CGFloat, expression: ExpressionType) -> some View {
        let isWink = expression == .wink
        
        return HStack(spacing: size * 0.32) {
            // 左眉毛
            eyebrowPath(isWink: isWink ? false : false)
                .stroke(Color.brown, lineWidth: size * 0.015)
                .frame(width: size * 0.15, height: size * 0.04)
                .rotationEffect(.degrees(angle))
                .offset(y: -size * 0.12)
            
            // 右眉毛（wink 时右边不同）
            eyebrowPath(isWink: isWink)
                .stroke(Color.brown, lineWidth: size * 0.015)
                .frame(width: size * 0.15, height: size * 0.04)
                .rotationEffect(.degrees(isWink ? -angle : angle))
                .offset(y: -size * 0.12)
        }
    }
    
    private func eyebrowPath(isWink: Bool) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 10))
            path.addQuadCurve(to: CGPoint(x: 30, y: isWink ? 5 : 10), control: CGPoint(x: 15, y: 0))
        }
    }
    
    // MARK: - 眼睛
    
    private func eyes(params: ExpressionType.ExpressionParams) -> some View {
        let isWink = expression == .wink
        let isSleepy = expression == .sleepy
        
        return ZStack {
            if isSleepy {
                // 困了：两条横线
                sleepyEyes()
            } else {
                HStack(spacing: size * 0.28) {
                    // 左眼
                    eyeView(
                        scale: params.eyeScale,
                        pupilScale: params.pupilScale,
                        pupilOffsetX: params.pupilOffsetX,
                        offsetY: params.eyeOffsetY,
                        isWink: false,
                        isBlinking: blinkState
                    )
                    
                    // 右眼
                    eyeView(
                        scale: params.eyeScale,
                        pupilScale: params.pupilScale,
                        pupilOffsetX: params.pupilOffsetX,
                        offsetY: params.eyeOffsetY,
                        isWink: isWink,
                        isBlinking: blinkState
                    )
                }
                .offset(y: size * -0.02)
            }
        }
    }
    
    private func eyeView(scale: CGFloat, pupilScale: CGFloat, pupilOffsetX: CGFloat, 
                         offsetY: CGFloat, isWink: Bool, isBlinking: Bool) -> some View {
        let eyeSize = size * 0.12 * scale
        let pupilSize = eyeSize * 0.4 * pupilScale
        
        return ZStack {
            // 眼白
            Circle()
                .fill(Color.white)
                .frame(width: eyeSize, height: isWink ? eyeSize * 0.15 : (isBlinking ? eyeSize * 0.1 : eyeSize))
                .overlay(
                    Circle()
                        .stroke(Color(hex: "8B7355"), lineWidth: size * 0.008)
                )
            
            // 瞳孔（非眨眼且非wink时显示）
            if !isBlinking && !isWink {
                Circle()
                    .fill(Color(hex: "2F1B0E"))
                    .frame(width: pupilSize, height: pupilSize)
                    .offset(x: pupilOffsetX)
                
                // 高光
                Circle()
                    .fill(Color.white)
                    .frame(width: pupilSize * 0.35, height: pupilSize * 0.35)
                    .offset(x: pupilSize * 0.2, y: -pupilSize * 0.2)
            }
        }
        .offset(y: offsetY)
        .animation(.easeInOut(duration: 0.15), value: isBlinking)
    }
    
    private func sleepyEyes() -> some View {
        HStack(spacing: size * 0.32) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 5))
                path.addLine(to: CGPoint(x: size * 0.1, y: 5))
            }
            .stroke(Color(hex: "2F1B0E"), lineWidth: size * 0.015)
            
            Path { path in
                path.move(to: CGPoint(x: 0, y: 5))
                path.addLine(to: CGPoint(x: size * 0.1, y: 5))
            }
            .stroke(Color(hex: "2F1B0E"), lineWidth: size * 0.015)
        }
        .offset(y: -size * 0.02)
    }
    
    // MARK: - 眼泪
    
    private func tears() -> some View {
        HStack(spacing: size * 0.35) {
            // 左眼泪
            tear()
                .offset(x: -size * 0.02, y: size * 0.05)
            
            // 右眼泪
            tear()
                .offset(x: size * 0.02, y: size * 0.05)
        }
    }
    
    private func tear() -> some View {
        Image(systemName: "drop.fill")
            .font(.system(size: size * 0.05))
            .foregroundColor(.blue.opacity(0.6))
            .offset(y: blinkState ? size * 0.02 : 0)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: blinkState)
    }
    
    // MARK: - 星星眼
    
    private func sparkles() -> some View {
        HStack(spacing: size * 0.35) {
            sparkle()
            sparkle()
        }
        .offset(y: -size * 0.05)
    }
    
    private func sparkle() -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size * 0.06))
            .foregroundColor(.yellow)
            .scaleEffect(blinkState ? 1.3 : 0.8)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: blinkState)
    }
    
    // MARK: - 嘴巴
    
    private func mouth(type: ExpressionType.MouthType, scale: CGFloat, speakingLevel: CGFloat) -> some View {
        Group {
            switch type {
            case .normal:
                normalMouth(scale: scale)
            case .smile:
                smileMouth(scale: scale)
            case .bigSmile:
                bigSmileMouth(scale: scale)
            case .open:
                speakingMouth(scale: scale, level: speakingLevel)
            case .sad:
                sadMouth(scale: scale)
            case .surprised:
                surprisedMouth(scale: scale)
            case .smirk:
                smirkMouth(scale: scale)
            case .kiss:
                kissMouth(scale: scale)
            }
        }
        .offset(y: size * 0.1)
    }
    
    private func normalMouth(scale: CGFloat) -> some View {
        Path { path in
            let width = size * 0.12 * scale
            path.move(to: CGPoint(x: -width, y: 0))
            path.addLine(to: CGPoint(x: width, y: 0))
        }
        .stroke(Color(hex: "8B7355"), lineWidth: size * 0.012)
    }
    
    private func smileMouth(scale: CGFloat) -> some View {
        Path { path in
            let width = size * 0.14 * scale
            path.move(to: CGPoint(x: -width, y: 0))
            path.addQuadCurve(to: CGPoint(x: width, y: 0), control: CGPoint(x: 0, y: size * 0.05 * scale))
        }
        .stroke(Color(hex: "8B7355"), lineWidth: size * 0.012)
    }
    
    private func bigSmileMouth(scale: CGFloat) -> some View {
        ZStack {
            // 张嘴
            Path { path in
                let width = size * 0.14 * scale
                let height = size * 0.06 * scale
                path.move(to: CGPoint(x: -width, y: -2))
                path.addQuadCurve(to: CGPoint(x: width, y: -2), control: CGPoint(x: 0, y: height))
                path.addQuadCurve(to: CGPoint(x: -width, y: -2), control: CGPoint(x: 0, y: -height))
            }
            .fill(Color(hex: "FF6B6B").opacity(0.6))
            
            // 微笑线
            Path { path in
                let width = size * 0.12 * scale
                path.move(to: CGPoint(x: -width, y: 0))
                path.addQuadCurve(to: CGPoint(x: width, y: 0), control: CGPoint(x: 0, y: size * 0.04 * scale))
            }
            .stroke(Color(hex: "8B7355"), lineWidth: size * 0.012)
        }
    }
    
    private func speakingMouth(scale: CGFloat, level: CGFloat) -> some View {
        let mouthHeight = size * 0.03 + size * 0.05 * level
        
        return Ellipse()
            .fill(Color(hex: "FF6B6B").opacity(0.5))
            .frame(width: size * 0.1 * scale, height: max(size * 0.02, mouthHeight))
            .animation(.easeInOut(duration: 0.1), value: level)
    }
    
    private func sadMouth(scale: CGFloat) -> some View {
        Path { path in
            let width = size * 0.1 * scale
            path.move(to: CGPoint(x: -width, y: size * 0.04 * scale))
            path.addQuadCurve(to: CGPoint(x: width, y: size * 0.04 * scale), control: CGPoint(x: 0, y: 0))
        }
        .stroke(Color(hex: "8B7355"), lineWidth: size * 0.012)
    }
    
    private func surprisedMouth(scale: CGFloat) -> some View {
        Circle()
            .fill(Color(hex: "4A3728"))
            .frame(width: size * 0.1 * scale, height: size * 0.08 * scale)
    }
    
    private func smirkMouth(scale: CGFloat) -> some View {
        Path { path in
            let width = size * 0.12 * scale
            path.move(to: CGPoint(x: -width * 0.8, y: 0))
            path.addQuadCurve(to: CGPoint(x: width, y: -size * 0.02), control: CGPoint(x: width * 0.2, y: size * 0.04 * scale))
        }
        .stroke(Color(hex: "8B7355"), lineWidth: size * 0.012)
    }
    
    private func kissMouth(scale: CGFloat) -> some View {
        Circle()
            .fill(Color.pink.opacity(0.4))
            .frame(width: size * 0.06 * scale, height: size * 0.06 * scale)
            .overlay(
                Circle()
                    .stroke(Color.pink.opacity(0.6), lineWidth: size * 0.008)
            )
    }
    
    // MARK: - 动画
    
    private func blink() {
        withAnimation(.easeInOut(duration: 0.1)) {
            blinkState = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.1)) {
                blinkState = false
            }
        }
    }
    
    private func updateFloat() {
        // 自然的微小浮动
        let time = Date().timeIntervalSinceReferenceDate
        floatOffset = sin(time * 2.0) * size * 0.015
        rotation = sin(time * 1.3) * 1.5
    }
}

// MARK: - 交互式表情视图

struct InteractiveExpressionView: View {
    @State private var currentExpression: ExpressionType = .normal
    @State private var speakingLevel: CGFloat = 0
    @State private var isPressed: Bool = false
    @State private var showExpressionPicker: Bool = false
    
    let size: CGFloat
    
    init(size: CGFloat = 200) {
        self.size = size
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 角色
            ExpressionView(
                expression: currentExpression,
                size: size,
                speakingLevel: speakingLevel
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .onTapGesture {
                // 点击切换表情
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation { isPressed = false }
                }
                cycleExpression()
            }
            .onLongPressGesture {
                showExpressionPicker.toggle()
            }
            
            // 表情名称
            Text(currentExpression.emoji + " " + currentExpression.displayName)
                .font(.headline)
                .foregroundColor(.primary)
            
            // 模拟说话控制
            if currentExpression == .speaking {
                HStack {
                    Button("低") { speakingLevel = 0.2 }
                        .buttonStyle(.bordered)
                    Button("中") { speakingLevel = 0.5 }
                        .buttonStyle(.bordered)
                    Button("高") { speakingLevel = 0.9 }
                        .buttonStyle(.bordered)
                }
                .font(.caption)
            }
            
            // 表情选择器
            if showExpressionPicker {
                expressionPicker
            }
        }
    }
    
    private func cycleExpression() {
        let all = ExpressionType.allCases
        let currentIndex = all.firstIndex(of: currentExpression) ?? 0
        let nextIndex = (currentIndex + 1) % all.count
        withAnimation(.easeInOut(duration: 0.3)) {
            currentExpression = all[nextIndex]
        }
    }
    
    private var expressionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ExpressionType.allCases, id: \.self) { expression in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentExpression = expression
                        }
                        showExpressionPicker = false
                    } label: {
                        VStack(spacing: 4) {
                            Text(expression.emoji)
                                .font(.title)
                            Text(expression.displayName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(currentExpression == expression ? Color.blue.opacity(0.15) : Color.gray.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 80)
    }
}

// MARK: - Color Extensions

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - 预览

#Preview("表情展示") {
    ScrollView {
        VStack(spacing: 30) {
            ForEach(ExpressionType.allCases, id: \.self) { expression in
                VStack {
                    ExpressionView(expression: expression, size: 120, speakingLevel: 0)
                    Text(expression.displayName)
                        .font(.caption)
                }
            }
        }
        .padding()
    }
}

#Preview("交互式") {
    InteractiveExpressionView(size: 200)
}
