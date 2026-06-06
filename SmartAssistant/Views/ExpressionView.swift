import SwiftUI

// MARK: - StackChan 风格表情 (黑底白线极简风)

struct ExpressionView: View {
    let expression: ExpressionType
    var size: CGFloat? = nil
    let speakingLevel: CGFloat
    
    @State private var blinkOffset: CGFloat = 0
    @State private var isBlinking: Bool = false
    @State private var floatOffset: CGFloat = 0
    @State private var headTilt: Double = 0
    
    private let blinkTimer = Timer.publish(every: 4.0, on: .main, in: .common).autoconnect()
    private let animTimer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()
    
    init(expression: ExpressionType, size: CGFloat? = nil, speakingLevel: CGFloat = 0) {
        self.expression = expression
        self.size = size
        self.speakingLevel = speakingLevel
    }
    
    var body: some View {
        GeometryReader { geo in
            let baseSize = size ?? min(geo.size.width, geo.size.height)
            let s = baseSize
            
            ZStack {
                // 黑色背景 (StackChan 屏幕)
                Color.black
                    .ignoresSafeArea()
                
                // 表情内容
                ZStack {
                    // 腮红
                    blushView(size: s)
                    
                    // 眼睛
                    eyesView(size: s)
                    
                    // 嘴巴
                    mouthView(size: s)
                }
                .frame(width: s * 0.6, height: s * 0.4)
            }
            .frame(width: baseSize, height: baseSize)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .rotationEffect(.degrees(headTilt))
            .offset(y: floatOffset)
        }
        .onReceive(animTimer) { _ in
            updateIdleAnimation()
        }
        .onReceive(blinkTimer) { _ in
            triggerBlink()
        }
    }
    
    // MARK: - 腮红 (粉色小方块/星星)
    
    private func blushView(size: CGFloat) -> some View {
        let params = expression.params
        guard params.cheekColor > 0 else { return AnyView(EmptyView()) }
        
        let blushColor = Color(red: 1.0, green: 0.4, blue: 0.5).opacity(params.cheekColor)
        let blushSize = size * 0.035
        let offsetY = size * 0.02
        
        return AnyView(
            HStack(spacing: size * 0.35) {
                // 左腮红 - 小方块带圆角
                RoundedRectangle(cornerRadius: blushSize * 0.3)
                    .fill(blushColor)
                    .frame(width: blushSize, height: blushSize)
                    .offset(y: offsetY)
                
                // 右腮红
                RoundedRectangle(cornerRadius: blushSize * 0.3)
                    .fill(blushColor)
                    .frame(width: blushSize, height: blushSize)
                    .offset(y: offsetY)
            }
        )
    }
    
    // MARK: - 眼睛 (白色小圆点)
    
    private func eyesView(size: CGFloat) -> some View {
        let params = expression.params
        let eyeSize = size * 0.025 * params.eyeScale
        let spacing = size * 0.12
        
        let leftEyeY = params.eyeOffsetY + (isBlinking ? eyeSize * 0.4 : 0)
        let rightEyeY = params.eyeOffsetY + (isBlinking ? eyeSize * 0.4 : 0)
        
        return ZStack {
            HStack(spacing: spacing) {
                // 左眼
                Circle()
                    .fill(Color.white)
                    .frame(width: eyeSize, height: isBlinking ? eyeSize * 0.15 : eyeSize)
                    .offset(y: leftEyeY)
                    .animation(.easeOut(duration: 0.08), value: isBlinking)
                
                // 右眼
                Circle()
                    .fill(Color.white)
                    .frame(width: eyeSize, height: isBlinking ? eyeSize * 0.15 : eyeSize)
                    .offset(y: rightEyeY)
                    .animation(.easeOut(duration: 0.08), value: isBlinking)
            }
            .offset(y: -size * 0.05)
        }
    }
    
    // MARK: - 嘴巴 (白色简单线条)
    
    private func mouthView(size: CGFloat) -> some View {
        let params = expression.params
        let mouthW = size * 0.08 * params.mouthScale
        
        return ZStack {
            switch params.mouthType {
            case .normal:
                normalMouth(width: mouthW, size: size)
            case .smile:
                smileMouth(width: mouthW, size: size)
            case .bigSmile:
                bigSmileMouth(width: mouthW, size: size)
            case .open:
                speakingMouth(width: mouthW, size: size)
            case .sad:
                sadMouth(width: mouthW, size: size)
            case .surprised:
                surprisedMouth(width: mouthW, size: size)
            case .smirk:
                smirkMouth(width: mouthW, size: size)
            case .kiss:
                kissMouth(size: mouthW, sizeBase: size)
            }
        }
        .offset(y: size * 0.04)
    }
    
    // 正常 - 短横线
    private func normalMouth(width: CGFloat, size: CGFloat) -> some View {
        Capsule()
            .fill(Color.white)
            .frame(width: width * 1.5, height: size * 0.008)
    }
    
    // 微笑 - 微微上扬的弧线
    private func smileMouth(width: CGFloat, size: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: -width, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: width, y: 0),
                control: CGPoint(x: 0, y: width * 0.3)
            )
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: size * 0.012, lineCap: .round))
    }
    
    // 大笑 - 开口笑
    private func bigSmileMouth(width: CGFloat, size: CGFloat) -> some View {
        ZStack {
            // 嘴型轮廓
            Path { path in
                path.move(to: CGPoint(x: -width, y: -width * 0.1))
                path.addQuadCurve(to: CGPoint(x: width, y: -width * 0.1), control: CGPoint(x: 0, y: width * 0.6))
                path.addQuadCurve(to: CGPoint(x: -width, y: -width * 0.1), control: CGPoint(x: 0, y: -width * 0.4))
            }
            .fill(Color.white)
            
            // 底部小舌头
            Circle()
                .fill(Color(red: 0.9, green: 0.35, blue: 0.35))
                .frame(width: width * 0.5, height: width * 0.35)
                .offset(y: width * 0.15)
        }
    }
    
    // 说话 - 小椭圆会动
    private func speakingMouth(width: CGFloat, size: CGFloat) -> some View {
        let level = max(0.2, speakingLevel)
        let h = size * 0.025 * level
        
        return Capsule()
            .fill(Color.white)
            .frame(width: width * 0.8, height: max(size * 0.015, h * 2))
            .animation(.easeOut(duration: 0.08), value: speakingLevel)
    }
    
    // 难过 - 向下弯
    private func sadMouth(width: CGFloat, size: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: -width, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: width, y: 0),
                control: CGPoint(x: 0, y: -width * 0.4)
            )
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: size * 0.012, lineCap: .round))
    }
    
    // 惊讶 - 小方块
    private func surprisedMouth(width: CGFloat, size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.008)
            .fill(Color.white)
            .frame(width: width * 0.6, height: width * 0.7)
    }
    
    // 歪嘴 - 一边高一边低
    private func smirkMouth(width: CGFloat, size: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: -width * 0.8, y: width * 0.2))
            path.addQuadCurve(
                to: CGPoint(x: width, y: -width * 0.1),
                control: CGPoint(x: width * 0.2, y: width * 0.4)
            )
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: size * 0.012, lineCap: .round))
    }
    
    // 亲亲 - 小圆圈
    private func kissMouth(size: CGFloat, sizeBase: CGFloat) -> some View {
        Circle()
            .stroke(Color(red: 0.95, green: 0.5, blue: 0.5), lineWidth: sizeBase * 0.008)
            .frame(width: size, height: size)
    }
    
    // MARK: - 动画
    
    private func triggerBlink() {
        withAnimation(.easeOut(duration: 0.08)) {
            isBlinking = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeIn(duration: 0.1)) {
                isBlinking = false
            }
        }
    }
    
    private func updateIdleAnimation() {
        let time = Date().timeIntervalSinceReferenceDate
        
        // 微浮动
        floatOffset = sin(time * 1.5) * 1.5
        
        // 头微倾
        headTilt = sin(time * 0.8) * 0.8
    }
}

// MARK: - Color Extension

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
