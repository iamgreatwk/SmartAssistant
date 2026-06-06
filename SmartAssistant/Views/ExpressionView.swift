import SwiftUI

// MARK: - StackChan 风格表情角色

struct ExpressionView: View {
    let expression: ExpressionType
    var size: CGFloat? = nil
    let speakingLevel: CGFloat
    
    @State private var blinkPhase: Double = 0
    @State private var floatOffset: CGFloat = 0
    @State private var breatheScale: CGFloat = 1.0
    @State private var headTilt: Double = 0
    @State private var eyeShine: Double = 0
    
    private let blinkTimer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()
    private let animTimer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()
    
    init(expression: ExpressionType, size: CGFloat? = nil, speakingLevel: CGFloat = 0) {
        self.expression = expression
        self.size = size
        self.speakingLevel = speakingLevel
    }
    
    var body: some View {
        GeometryReader { geo in
            let baseSize = size ?? min(geo.size.width, geo.size.height)
            let s = baseSize * 0.85
            
            ZStack {
                // 头部
                headView(size: s)
                
                // 腮红
                blushView(size: s)
                
                // 眼睛
                eyesView(size: s)
                
                // 嘴巴
                mouthView(size: s)
            }
            .frame(width: baseSize, height: baseSize)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .scaleEffect(breatheScale)
            .offset(y: floatOffset)
            .rotationEffect(.degrees(headTilt))
        }
        .onReceive(animTimer) { _ in
            updateIdleAnimation()
        }
        .onReceive(blinkTimer) { _ in
            triggerBlink()
        }
    }
    
    // MARK: - 头部
    
    private func headView(size: CGFloat) -> some View {
        let gradient = RadialGradient(
            colors: [
                Color(red: 1.0, green: 0.95, blue: 0.78),
                Color(red: 1.0, green: 0.85, blue: 0.55),
                Color(red: 0.95, green: 0.75, blue: 0.4)
            ],
            center: .init(x: 0.42, y: 0.38),
            startRadius: size * 0.05,
            endRadius: size * 0.65
        )
        
        return Circle()
            .fill(gradient)
            .frame(width: size, height: size)
            .shadow(color: Color.black.opacity(0.12), radius: size * 0.04, x: 0, y: size * 0.03)
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: size * 0.03
                    )
                    .blur(radius: size * 0.02)
            )
    }
    
    // MARK: - 腮红
    
    private func blushView(size: CGFloat) -> some View {
        let params = expression.params
        let intensity = params.cheekColor
        
        return HStack(spacing: size * 0.42) {
            Circle()
                .fill(Color.pink.opacity(intensity * 0.25))
                .frame(width: size * 0.14, height: size * 0.07)
                .blur(radius: size * 0.025)
                .offset(y: size * 0.06)
            
            Circle()
                .fill(Color.pink.opacity(intensity * 0.25))
                .frame(width: size * 0.14, height: size * 0.07)
                .blur(radius: size * 0.025)
                .offset(y: size * 0.06)
        }
    }
    
    // MARK: - 眼睛
    
    private func eyesView(size: CGFloat) -> some View {
        let params = expression.params
        let eyeW = size * 0.185 * params.eyeScale
        let eyeH = size * 0.21 * params.eyeScale
        let pupilR = eyeW * 0.38 * params.pupilScale
        
        return ZStack {
            HStack(spacing: size * 0.26) {
                // 左眼
                singleEye(
                    width: eyeW, height: eyeH,
                    pupilRadius: pupilR,
                    pupilOffsetX: params.pupilOffsetX,
                    offsetY: params.eyeOffsetY,
                    isWink: expression == .wink
                )
                
                // 右眼
                singleEye(
                    width: eyeW, height: eyeH,
                    pupilRadius: pupilR,
                    pupilOffsetX: params.pupilOffsetX,
                    offsetY: params.eyeOffsetY,
                    isWink: false
                )
            }
            .offset(y: size * -0.03)
            
            // 眼睛高光
            eyeHighlights(size: size, eyeSpacing: eyeW, eyeOffsetY: params.eyeOffsetY)
        }
    }
    
    private func singleEye(width: CGFloat, height: CGFloat, pupilRadius: CGFloat,
                           pupilOffsetX: CGFloat, offsetY: CGFloat, isWink: Bool) -> some View {
        let blinkHeight = blinkPhase > 0.1 ? max(height * 0.05, height * (1 - blinkPhase)) : height
        let actualHeight = isWink ? height * 0.08 : blinkHeight
        
        return ZStack {
            // 眼白
            Ellipse()
                .fill(Color.white)
                .frame(width: width, height: actualHeight)
                .overlay(
                    Ellipse()
                        .stroke(Color(red: 0.4, green: 0.3, blue: 0.2), lineWidth: width * 0.1)
                )
            
            // 瞳孔 (非眨眼显示)
            if blinkPhase < 0.15 && !isWink {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.2, green: 0.08, blue: 0.03),
                                     Color(red: 0.1, green: 0.05, blue: 0.02)],
                            center: .center,
                            startRadius: 0,
                            endRadius: pupilRadius
                        )
                    )
                    .frame(width: pupilRadius * 2, height: pupilRadius * 2)
                    .offset(x: pupilOffsetX)
                
                // 瞳孔高光
                Circle()
                    .fill(Color.white)
                    .frame(width: pupilRadius * 0.45, height: pupilRadius * 0.45)
                    .offset(x: pupilRadius * 0.3 + pupilOffsetX, y: -pupilRadius * 0.3)
            }
        }
        .offset(y: offsetY)
        .animation(.easeInOut(duration: 0.1), value: blinkPhase)
    }
    
    // MARK: - 眼睛高光
    
    private func eyeHighlights(size: CGFloat, eyeSpacing: CGFloat, eyeOffsetY: CGFloat) -> some View {
        let highlightSize = eyeSpacing * 0.18
        let spacing = size * 0.26
        
        return HStack(spacing: spacing) {
            Circle()
                .fill(Color.white.opacity(0.6 + eyeShine * 0.3))
                .frame(width: highlightSize, height: highlightSize)
                .offset(x: eyeSpacing * 0.25, y: -eyeSpacing * 0.5 + eyeOffsetY)
            
            Circle()
                .fill(Color.white.opacity(0.6 + eyeShine * 0.3))
                .frame(width: highlightSize, height: highlightSize)
                .offset(x: eyeSpacing * 0.25, y: -eyeSpacing * 0.5 + eyeOffsetY)
        }
    }
    
    // MARK: - 嘴巴
    
    private func mouthView(size: CGFloat) -> some View {
        let params = expression.params
        let mouthW = size * 0.13 * params.mouthScale
        let mouthH = size * 0.08 * params.mouthScale
        
        return ZStack {
            switch params.mouthType {
            case .normal:
                normalMouth(width: mouthW)
            case .smile:
                smileMouth(width: mouthW)
            case .bigSmile:
                bigSmileMouth(width: mouthW, height: mouthH)
            case .open:
                speakingMouth(width: mouthW, height: mouthH)
            case .sad:
                sadMouth(width: mouthW)
            case .surprised:
                surprisedMouth(width: mouthW)
            case .smirk:
                smirkMouth(width: mouthW)
            case .kiss:
                kissMouth(size: mouthW * 0.6)
            }
        }
        .offset(y: size * 0.12)
    }
    
    private func normalMouth(width: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: -width, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: width, y: 0),
                control: CGPoint(x: 0, y: width * 0.25)
            )
        }
        .stroke(Color(red: 0.5, green: 0.3, blue: 0.2), lineWidth: width * 0.25)
    }
    
    private func smileMouth(width: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: -width, y: 2))
            path.addQuadCurve(
                to: CGPoint(x: width, y: 2),
                control: CGPoint(x: 0, y: width * 0.6)
            )
        }
        .stroke(Color(red: 0.5, green: 0.3, blue: 0.2), lineWidth: width * 0.25)
    }
    
    private func bigSmileMouth(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // 张嘴内部
            Path { path in
                path.move(to: CGPoint(x: -width, y: -2))
                path.addQuadCurve(to: CGPoint(x: width, y: -2), control: CGPoint(x: 0, y: height * 0.7))
                path.addQuadCurve(to: CGPoint(x: -width, y: -2), control: CGPoint(x: 0, y: -height * 0.5))
            }
            .fill(Color(red: 0.9, green: 0.35, blue: 0.3).opacity(0.7))
            
            // 上弧线
            Path { path in
                path.move(to: CGPoint(x: -width * 0.9, y: -1))
                path.addQuadCurve(to: CGPoint(x: width * 0.9, y: -1), control: CGPoint(x: 0, y: height * 0.5))
            }
            .stroke(Color(red: 0.5, green: 0.3, blue: 0.2), lineWidth: width * 0.2)
        }
    }
    
    private func speakingMouth(width: CGFloat, height: CGFloat) -> some View {
        let level = max(0.15, speakingLevel)
        let h = height * 1.4 * level
        
        return Ellipse()
            .fill(Color(red: 0.85, green: 0.3, blue: 0.25).opacity(0.7))
            .frame(width: width * 1.2, height: max(height * 0.25, h))
            .animation(.spring(response: 0.08, dampingFraction: 0.4), value: speakingLevel)
    }
    
    private func sadMouth(width: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: -width, y: width * 0.4))
            path.addQuadCurve(
                to: CGPoint(x: width, y: width * 0.4),
                control: CGPoint(x: 0, y: 0)
            )
        }
        .stroke(Color(red: 0.5, green: 0.3, blue: 0.2), lineWidth: width * 0.25)
    }
    
    private func surprisedMouth(width: CGFloat) -> some View {
        Circle()
            .fill(Color(red: 0.2, green: 0.1, blue: 0.05))
            .frame(width: width * 0.9, height: width * 0.75)
    }
    
    private func smirkMouth(width: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: -width * 0.7, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: width * 0.9, y: -width * 0.2),
                control: CGPoint(x: width * 0.3, y: width * 0.4)
            )
        }
        .stroke(Color(red: 0.5, green: 0.3, blue: 0.2), lineWidth: width * 0.25)
    }
    
    private func kissMouth(size: CGFloat) -> some View {
        Circle()
            .fill(Color(red: 0.95, green: 0.5, blue: 0.5).opacity(0.5))
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color(red: 0.95, green: 0.5, blue: 0.5).opacity(0.7), lineWidth: size * 0.15)
            )
    }
    
    // MARK: - 动画
    
    private func triggerBlink() {
        withAnimation(.easeOut(duration: 0.06)) { blinkPhase = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeIn(duration: 0.12)) { blinkPhase = 0 }
        }
    }
    
    private func updateIdleAnimation() {
        let time = Date().timeIntervalSinceReferenceDate
        
        // 呼吸
        breatheScale = 1.0 + sin(time * 1.4) * 0.015
        
        // 微浮动
        floatOffset = sin(time * 2.0) * 2.5
        
        // 头微倾
        headTilt = sin(time * 1.1) * 1.2
        
        // 星光闪烁
        eyeShine = (sin(time * 3.2) + 1) / 2
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
