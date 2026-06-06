import SwiftUI

// MARK: - StackChan 风格表情 (黑底白线极简)
// 绘制逻辑完全匹配 HTML 预览：以 100×100 为基准，scale = size / 100
// 所有元素用 absolute position 定位，不再依赖 offset

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
            let scale = s / 100   // HTML 100×100 → Swift 像素

            ZStack {
                Color.black

                cheekLayer(scale: scale)
                    .position(x: s / 2, y: 48 * scale)

                eyesLayer(scale: scale)
                    .position(x: s / 2, y: 38 * scale)

                mouthLayer(scale: scale)
                    .position(x: s / 2, y: 60 * scale)
            }
            .frame(width: s, height: s)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .rotationEffect(.degrees(headTilt))
            .offset(y: floatOffset)
        }
        .onReceive(animTimer) { _ in animate() }
        .onReceive(blinkTimer) { _ in triggerBlink() }
    }

    // MARK: - 腮红

    private func cheekLayer(scale: CGFloat) -> some View {
        let p = expression.params
        guard p.cheek > 0 else { return AnyView(EmptyView()) }

        let bs = 5 * p.cheek * scale            // 腮红大小
        let color = Color(red: 1, green: 0.35, blue: 0.45).opacity(p.cheek * 0.4)

        return AnyView(
            HStack(spacing: 40 * scale) {
                RoundedRectangle(cornerRadius: bs * 0.2)
                    .fill(color)
                    .frame(width: bs, height: bs * 0.7)
                RoundedRectangle(cornerRadius: bs * 0.2)
                    .fill(color)
                    .frame(width: bs, height: bs * 0.7)
            }
        )
    }

    // MARK: - 眼睛

    private func eyesLayer(scale: CGFloat) -> some View {
        let spacing = 36 * scale              // HTML: eyeSpacing=18, 双眼间距=36

        return HStack(spacing: spacing) {
            eyeView(isRight: false, scale: scale)
            eyeView(isRight: true, scale: scale)
        }
    }

    private func eyeView(isRight: Bool, scale: CGFloat) -> some View {
        let p = expression.params
        let ew = 4.5 * p.eyeW * scale
        let eh = 4.5 * p.eyeH * scale

        // wink: 左眼正常，右眼变横线
        let isWink = (expression == .wink && isRight)

        // 困了：横线
        if p.eyeType == .lines {
            return AnyView(
                Capsule()
                    .fill(Color.white)
                    .frame(width: ew * 2.5, height: 1.5 * scale)
            )
        }

        // 生气：斜线
        if p.eyeType == .slant {
            return AnyView(
                Path { path in
                    path.move(to: CGPoint(x: -ew, y: -eh * 0.4))
                    path.addLine(to: CGPoint(x: ew, y: eh * 0.4))
                }
                .stroke(Color.white, lineWidth: 2 * scale)
                .frame(width: ew * 2, height: eh * 2)
            )
        }

        // 大笑：弧形（弯眼）
        if p.eyeType == .arches {
            return AnyView(
                Path { path in
                    path.move(to: CGPoint(x: -ew, y: eh))
                    path.addQuadCurve(
                        to: CGPoint(x: ew, y: eh),
                        control: CGPoint(x: 0, y: -eh)
                    )
                }
                .stroke(Color.white, lineWidth: 2 * scale)
                .frame(width: ew * 2, height: eh * 2)
            )
        }

        // 默认：圆眼 (dots / big)
        let displayH = isWink ? ew * 0.15 : (isBlinking ? ew * 0.15 : eh * 2)

        return AnyView(
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: ew * 2, height: displayH)

                // 瞳孔
                let pr = ew * 0.35 * p.pupil
                if pr > 0.5 * scale && !isBlinking && !isWink {
                    let pupilX: CGFloat = {
                        if p.pupilL && !isRight { return -2 * scale }
                        if p.pupilR && isRight { return 2 * scale }
                        return 0
                    }()
                    Circle()
                        .fill(Color.black)
                        .frame(width: pr * 2, height: pr * 2)
                        .offset(x: pupilX)
                }
            }
        )
    }

    // MARK: - 嘴巴

    private func mouthLayer(scale: CGFloat) -> some View {
        let p = expression.params
        let mw = 8 * p.mouthW * scale              // 嘴宽基础值

        return Group {
            switch p.mouthType {
            case .line:
                Capsule()
                    .fill(Color.white)
                    .frame(width: mw * 1.4, height: 1.5 * scale)

            case .smile:
                smileMouth(mw: mw, scale: scale)

            case .bigSmile:
                bigSmileMouth(mw: mw, scale: scale)

            case .open:
                let lvl = max(0.15, speakingLevel)
                Ellipse()
                    .fill(Color.white)
                    .frame(width: mw * 0.9, height: max(2 * scale, 6 * scale * lvl))

            case .sad:
                sadMouth(mw: mw, scale: scale)

            case .block:
                let bs = mw * 0.7
                RoundedRectangle(cornerRadius: 4 * scale)
                    .fill(Color.white)
                    .frame(width: bs, height: bs)

            case .smirk:
                smirkMouth(mw: mw, scale: scale)

            case .kiss:
                Circle()
                    .stroke(Color(red: 1, green: 0.45, blue: 0.55), lineWidth: 1.5 * scale)
                    .frame(width: mw * 0.7, height: mw * 0.7)
            }
        }
    }

    private func smileMouth(mw: CGFloat, scale: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: -mw, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: mw, y: 0),
                control: CGPoint(x: 0, y: mw * 0.4)
            )
        }
        .stroke(Color.white, lineWidth: 2 * scale)
    }

    private func sadMouth(mw: CGFloat, scale: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: -mw, y: mw * 0.3))
            path.addQuadCurve(
                to: CGPoint(x: mw, y: mw * 0.3),
                control: CGPoint(x: 0, y: -mw * 0.2)
            )
        }
        .stroke(Color.white, lineWidth: 2 * scale)
    }

    private func smirkMouth(mw: CGFloat, scale: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: -mw * 0.7, y: mw * 0.2))
            path.addQuadCurve(
                to: CGPoint(x: mw, y: -mw * 0.05),
                control: CGPoint(x: mw * 0.1, y: mw * 0.5)
            )
        }
        .stroke(Color.white, lineWidth: 2 * scale)
    }

    private func bigSmileMouth(mw: CGFloat, scale: CGFloat) -> some View {
        ZStack {
            // 填色的 D 形张嘴
            Path { path in
                path.move(to: CGPoint(x: -mw, y: 0))
                path.addQuadCurve(
                    to: CGPoint(x: mw, y: 0),
                    control: CGPoint(x: 0, y: mw * 0.6)
                )
                path.addQuadCurve(
                    to: CGPoint(x: -mw, y: 0),
                    control: CGPoint(x: 0, y: mw * 0.2)
                )
            }
            .fill(Color.white)
            // 舌头
            Ellipse()
                .fill(Color(red: 0.9, green: 0.35, blue: 0.3))
                .frame(width: mw * 0.4, height: mw * 0.3)
                .offset(y: mw * 0.1)
        }
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
