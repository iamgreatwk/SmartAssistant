import SwiftUI

// MARK: - StackChan 风格表情 (黑底白线极简)

struct ExpressionView: View {
    let expression: ExpressionType
    var size: CGFloat? = nil
    let speakingLevel: CGFloat
    let isFullscreen: Bool
    
    @State private var isBlinking: Bool = false
    @State private var floatOffset: CGFloat = 0
    @State private var headTilt: Double = 0
    
    private let blinkTimer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()
    private let animTimer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()
    
    init(expression: ExpressionType, size: CGFloat? = nil, speakingLevel: CGFloat = 0, isFullscreen: Bool = false) {
        self.expression = expression
        self.size = size
        self.speakingLevel = speakingLevel
        self.isFullscreen = isFullscreen
    }
    
    var body: some View {
        GeometryReader { geo in
            let s = size ?? min(geo.size.width, geo.size.height)
            let scale: CGFloat = isFullscreen ? 1.8 : 1.0
            let lw: CGFloat = isFullscreen ? 2.0 : 1.0
            
            ZStack {
                Color.black
                
                // 表情元素垂直居中
                VStack(spacing: s * 0.06 * scale) {
                    // 眼睛
                    eyeRow(size: s, scale: scale, lineWidth: lw)
                    
                    // 嘴巴
                    mouthRow(size: s, scale: scale, lineWidth: lw)
                }
                
                // 腮红覆盖层
                blushLayer(size: s, scale: scale)
            }
            .frame(width: s, height: s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .rotationEffect(.degrees(headTilt))
            .offset(y: floatOffset * scale)
        }
        .onReceive(animTimer) { _ in animate() }
        .onReceive(blinkTimer) { _ in triggerBlink() }
    }
    
    // MARK: - 眼睛行
    
    private func eyeRow(size: CGFloat, scale: CGFloat, lineWidth: CGFloat) -> some View {
        let p = expression.params
        let r = size * 0.028 * p.eyeScale * scale
        let gap = size * 0.12 * scale
        
        if expression == .sleepy {
            return AnyView(
                HStack(spacing: gap) {
                    Capsule().fill(Color.white).frame(width: r * 3, height: size * 0.008 * scale)
                    Capsule().fill(Color.white).frame(width: r * 3, height: size * 0.008 * scale)
                }
            )
        }
        
        if expression == .angry {
            return AnyView(
                HStack(spacing: gap) {
                    Path { p in
                        p.move(to: CGPoint(x: -r, y: -r * 0.4))
                        p.addLine(to: CGPoint(x: r, y: r * 0.4))
                    }
                    .stroke(Color.white, lineWidth: size * 0.014 * lineWidth)
                    .frame(width: r * 2, height: r * 2)
                    
                    Path { p in
                        p.move(to: CGPoint(x: -r, y: -r * 0.4))
                        p.addLine(to: CGPoint(x: r, y: r * 0.4))
                    }
                    .stroke(Color.white, lineWidth: size * 0.014 * lineWidth)
                    .frame(width: r * 2, height: r * 2)
                }
            )
        }
        
        return AnyView(
            HStack(spacing: gap) {
                eye(r: r, params: p, scale: scale, isWink: false)
                eye(r: r, params: p, scale: scale, isWink: expression == .wink)
            }
        )
    }
    
    private func eye(r: CGFloat, params: ExpressionType.ExpressionParams, scale: CGFloat, isWink: Bool) -> some View {
        let h = isWink ? r * 0.15 : (isBlinking ? r * 0.15 : r * 2)
        return ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: r * 2, height: h)
                .offset(y: params.eyeOffsetY * scale)
            
            if params.pupilScale > 0.35 && !isBlinking && !isWink {
                Circle()
                    .fill(Color.black)
                    .frame(width: r * 1.3 * params.pupilScale, height: r * 1.3 * params.pupilScale)
                    .offset(x: params.pupilOffsetX * scale, y: params.eyeOffsetY * scale)
            }
        }
    }
    
    // MARK: - 嘴巴行
    
    private func mouthRow(size: CGFloat, scale: CGFloat, lineWidth: CGFloat) -> some View {
        let p = expression.params
        let w = size * 0.08 * p.mouthScale * scale
        
        return Group {
            switch p.mouthType {
            case .normal:
                Capsule().fill(Color.white).frame(width: w * 1.2, height: size * 0.008 * scale)
            case .smile:
                smileArc(w: w, size: size, lw: lineWidth)
            case .bigSmile:
                bigSmile(w: w, s: size, scale: scale)
            case .open:
                let lvl = max(0.15, speakingLevel)
                Capsule()
                    .fill(Color.white)
                    .frame(width: w * 0.8, height: max(size * 0.014 * scale, size * 0.022 * lvl * scale))
            case .sad:
                sadArc(w: w, size: size, lw: lineWidth)
            case .surprised:
                RoundedRectangle(cornerRadius: size * 0.01 * scale)
                    .fill(Color.white)
                    .frame(width: w * 0.65, height: w * 0.7)
            case .smirk:
                smirk(w: w, size: size, lw: lineWidth)
            case .kiss:
                Circle()
                    .stroke(Color(red: 1, green: 0.45, blue: 0.55), lineWidth: size * 0.009 * lineWidth)
                    .frame(width: w * 0.65, height: w * 0.65)
            }
        }
    }
    
    private func smileArc(w: CGFloat, size: CGFloat, lw: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: -w, y: w * 0.15))
            p.addQuadCurve(to: CGPoint(x: w, y: w * 0.15), control: CGPoint(x: 0, y: w * 0.6))
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: size * 0.012 * lw, lineCap: .round))
    }
    
    private func sadArc(w: CGFloat, size: CGFloat, lw: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: -w, y: 0))
            p.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: 0, y: -w * 0.5))
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: size * 0.012 * lw, lineCap: .round))
    }
    
    private func smirk(w: CGFloat, size: CGFloat, lw: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: -w * 0.7, y: w * 0.2))
            p.addQuadCurve(to: CGPoint(x: w, y: -w * 0.05), control: CGPoint(x: w * 0.2, y: w * 0.45))
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: size * 0.012 * lw, lineCap: .round))
    }
    
    private func bigSmile(w: CGFloat, s: CGFloat, scale: CGFloat) -> some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: -w, y: 0))
                p.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: 0, y: w * 0.7))
                p.addQuadCurve(to: CGPoint(x: -w, y: 0), control: CGPoint(x: 0, y: w * 0.35))
            }
            .fill(Color.white)
            Circle()
                .fill(Color(red: 0.9, green: 0.35, blue: 0.3))
                .frame(width: w * 0.4, height: w * 0.3)
                .offset(y: w * 0.1)
        }
    }
    
    // MARK: - 腮红
    
    private func blushLayer(size: CGFloat, scale: CGFloat) -> some View {
        let p = expression.params
        guard p.cheekColor > 0 else { return AnyView(EmptyView()) }
        let c = Color(red: 1, green: 0.35, blue: 0.45).opacity(p.cheekColor)
        let b = size * 0.032 * scale
        let gap = size * 0.12 * scale + b * 2
        
        return AnyView(
            HStack(spacing: gap) {
                RoundedRectangle(cornerRadius: b * 0.3).fill(c).frame(width: b, height: b)
                RoundedRectangle(cornerRadius: b * 0.3).fill(c).frame(width: b, height: b)
            }
            .offset(y: size * 0.008 * scale)
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
