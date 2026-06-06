import SwiftUI

// MARK: - StackChan 风格表情 (黑底白线极简)

struct ExpressionView: View {
    let expression: ExpressionType
    var size: CGFloat? = nil
    let speakingLevel: CGFloat
    
    @State private var isBlinking: Bool = false
    @State private var floatOffset: CGFloat = 0
    @State private var headTilt: Double = 0
    
    private let blinkTimer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()
    private let animTimer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()
    
    init(expression: ExpressionType, size: CGFloat? = nil, speakingLevel: CGFloat = 0) {
        self.expression = expression
        self.size = size
        self.speakingLevel = speakingLevel
    }
    
    var body: some View {
        GeometryReader { geo in
            let s = size ?? min(geo.size.width, geo.size.height)
            let areaH = s * 0.55  // 表情区域高度
            let areaW = s * 0.5   // 表情区域宽度
            
            ZStack {
                Color.black
                
                // 核心表情区域 - VStack 保证眼睛在上嘴巴在下
                VStack(spacing: s * 0.04) {
                    // 眼睛行
                    eyeRow(size: s)
                        .frame(height: s * 0.08)
                    
                    // 嘴巴行
                    mouthRow(size: s)
                        .frame(height: s * 0.07)
                }
                .frame(width: areaW)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                
                // 腮红（叠加在眼睛下方外侧）
                blushOverlay(size: s)
            }
            .frame(width: s, height: s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .rotationEffect(.degrees(headTilt))
            .offset(y: floatOffset)
        }
        .onReceive(animTimer) { _ in
            animate()
        }
        .onReceive(blinkTimer) { _ in
            triggerBlink()
        }
    }
    
    // MARK: - 眼睛行
    
    private func eyeRow(size: CGFloat) -> some View {
        let params = expression.params
        let eyeR = size * 0.025 * params.eyeScale  // 眼睛半径
        let spacing = size * 0.1
        
        // 困了：横线眼睛
        if expression == .sleepy {
            return AnyView(
                HStack(spacing: spacing) {
                    Capsule()
                        .fill(Color.white)
                        .frame(width: eyeR * 2.5, height: size * 0.006)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: eyeR * 2.5, height: size * 0.006)
                }
            )
        }
        
        // 生气：斜向眼睛
        if expression == .angry {
            return AnyView(
                HStack(spacing: spacing) {
                    angryEye(radius: eyeR, size: size)
                    angryEye(radius: eyeR, size: size)
                }
            )
        }
        
        // 默认：圆点/椭圆眼睛
        return AnyView(
            HStack(spacing: spacing) {
                singleEye(radius: eyeR, size: size, params: params, isWink: false)
                singleEye(radius: eyeR, size: size, params: params, isWink: expression == .wink)
            }
        )
    }
    
    private func singleEye(radius: CGFloat, size: CGFloat, params: ExpressionType.ExpressionParams, isWink: Bool) -> some View {
        let h = isWink ? size * 0.004 : (isBlinking ? size * 0.004 : radius * 2)
        
        return ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: radius * 2, height: h)
                .animation(.easeOut(duration: 0.08), value: isBlinking)
                .offset(y: params.eyeOffsetY)
            
            // 瞳孔（仅在非惊讶时显示，惊讶时眼睛大瞳孔小是另一种效果）
            if params.pupilScale > 0.3 && !isBlinking && !isWink {
                Circle()
                    .fill(Color.black)
                    .frame(width: radius * 1.2 * params.pupilScale, height: radius * 1.2 * params.pupilScale)
                    .offset(x: params.pupilOffsetX, y: params.eyeOffsetY)
            }
        }
    }
    
    private func angryEye(radius: CGFloat, size: CGFloat) -> some View {
        Path { path in
            let w = radius * 2
            path.move(to: CGPoint(x: -w * 0.4, y: -w * 0.3))
            path.addLine(to: CGPoint(x: w * 0.4, y: w * 0.3))
        }
        .stroke(Color.white, lineWidth: size * 0.012)
        .frame(width: radius * 2, height: radius * 2)
    }
    
    // MARK: - 嘴巴行
    
    private func mouthRow(size: CGFloat) -> some View {
        let params = expression.params
        let w = size * 0.07 * params.mouthScale
        
        return Group {
            switch params.mouthType {
            case .normal:
                Capsule()
                    .fill(Color.white)
                    .frame(width: w * 1.3, height: size * 0.007)
            case .smile:
                smileArc(width: w, size: size)
            case .bigSmile:
                bigSmile(width: w, size: size)
            case .open:
                speakingMouth(width: w, size: size)
            case .sad:
                sadArc(width: w, size: size)
            case .surprised:
                RoundedRectangle(cornerRadius: size * 0.008)
                    .fill(Color.white)
                    .frame(width: w * 0.6, height: w * 0.65)
            case .smirk:
                smirkLine(width: w, size: size)
            case .kiss:
                Circle()
                    .stroke(Color(red: 1, green: 0.45, blue: 0.55), lineWidth: size * 0.008)
                    .frame(width: w * 0.6, height: w * 0.6)
            }
        }
    }
    
    private func smileArc(width: CGFloat, size: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: -width, y: width * 0.15))
            p.addQuadCurve(to: CGPoint(x: width, y: width * 0.15),
                           control: CGPoint(x: 0, y: width * 0.55))
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: size * 0.011, lineCap: .round))
    }
    
    private func bigSmile(width: CGFloat, size: CGFloat) -> some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: -width, y: 0))
                p.addQuadCurve(to: CGPoint(x: width, y: 0), control: CGPoint(x: 0, y: width * 0.7))
                p.addQuadCurve(to: CGPoint(x: -width, y: 0), control: CGPoint(x: 0, y: width * 0.35))
            }
            .fill(Color.white)
            
            Circle()
                .fill(Color(red: 0.9, green: 0.35, blue: 0.3))
                .frame(width: width * 0.4, height: width * 0.3)
                .offset(y: width * 0.08)
        }
    }
    
    private func speakingMouth(width: CGFloat, size: CGFloat) -> some View {
        let lvl = max(0.15, speakingLevel)
        Capsule()
            .fill(Color.white)
            .frame(width: width * 0.7, height: max(size * 0.012, size * 0.02 * lvl))
            .animation(.easeOut(duration: 0.06), value: speakingLevel)
    }
    
    private func sadArc(width: CGFloat, size: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: -width, y: 0))
            p.addQuadCurve(to: CGPoint(x: width, y: 0),
                           control: CGPoint(x: 0, y: -width * 0.5))
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: size * 0.011, lineCap: .round))
    }
    
    private func smirkLine(width: CGFloat, size: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: -width * 0.7, y: width * 0.15))
            p.addQuadCurve(to: CGPoint(x: width, y: -width * 0.05),
                           control: CGPoint(x: width * 0.2, y: width * 0.4))
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: size * 0.011, lineCap: .round))
    }
    
    // MARK: - 腮红
    
    private func blushOverlay(size: CGFloat) -> some View {
        let params = expression.params
        guard params.cheekColor > 0 else { return AnyView(EmptyView()) }
        
        let blushC = Color(red: 1, green: 0.35, blue: 0.45).opacity(params.cheekColor)
        let blushS = size * 0.03
        let eyeSpacing = size * 0.1
        
        return AnyView(
            HStack(spacing: eyeSpacing + size * 0.04) {
                RoundedRectangle(cornerRadius: blushS * 0.3)
                    .fill(blushC)
                    .frame(width: blushS, height: blushS)
                
                RoundedRectangle(cornerRadius: blushS * 0.3)
                    .fill(blushC)
                    .frame(width: blushS, height: blushS)
            }
            .offset(y: size * 0.04)
        )
    }
    
    // MARK: - 动画
    
    private func triggerBlink() {
        withAnimation(.easeOut(duration: 0.06)) { isBlinking = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.1)) { isBlinking = false }
        }
    }
    
    private func animate() {
        let t = Date().timeIntervalSinceReferenceDate
        floatOffset = sin(t * 1.5) * 1.5
        headTilt = sin(t * 0.8) * 0.8
    }
}
