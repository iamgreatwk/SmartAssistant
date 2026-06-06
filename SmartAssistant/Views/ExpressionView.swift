import SwiftUI

// MARK: - StackChan 表情 (Canvas + Core Graphics)
// 直接用 Canvas 绘制，100×100 虚拟坐标映射，和 HTML 预览完全一致

struct ExpressionView: View {
    let expression: ExpressionType
    var size: CGFloat? = nil
    let speakingLevel: CGFloat
    let isFullscreen: Bool

    init(expression: ExpressionType, size: CGFloat? = nil, speakingLevel: CGFloat = 0, isFullscreen: Bool = false) {
        self.expression = expression
        self.size = size
        self.speakingLevel = speakingLevel
        self.isFullscreen = isFullscreen
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in

                let s = size ?? min(geo.size.width, geo.size.height)
                let scale = s / 100

                let t = timeline.date.timeIntervalSinceReferenceDate
                let floatOffset = sin(t * 1.5) * 1.5
                let headTilt = sin(t * 0.8) * 0.8 * .pi / 180
                let blinkPhase = t.truncatingRemainder(dividingBy: 3.5)
                let isBlinking = blinkPhase < 0.15

                Canvas { context, size in
                    var ctx = context

                    // 把画布原点移到中间，应用旋转和浮动
                    ctx.translateBy(x: size.width / 2, y: size.height / 2)
                    ctx.rotate(by: headTilt)
                    ctx.translateBy(x: -s / 2, y: -s / 2 + floatOffset)

                    // 黑色背景
                    ctx.fill(Path(CGRect(x: 0, y: 0, width: s, height: s)), with: .color(.black))

                    // 腮红
                    drawCheeks(ctx: ctx, scale: scale, isBlinking: isBlinking)

                    // 眼睛
                    drawEyes(ctx: ctx, scale: scale, isBlinking: isBlinking)

                    // 嘴巴
                    drawMouth(ctx: ctx, scale: scale, isBlinking: isBlinking)
                }
            }
        }
    }

    // MARK: - 腮红

    private func drawCheeks(ctx: GraphicsContext, scale: CGFloat, isBlinking: Bool) {
        let p = expression.params
        guard p.cheek > 0 else { return }

        let bs = 5 * p.cheek * scale
        let bx = 20 * scale
        let by = 48 * scale

        let color = GraphicsContext.Shading.color(Color(red: 1, green: 0.35, blue: 0.45).opacity(p.cheek * 0.4))

        let leftRect = CGRect(x: 50 * scale - bx - bs / 2, y: by - bs * 0.35, width: bs, height: bs * 0.7)
        let rightRect = CGRect(x: 50 * scale + bx - bs / 2, y: by - bs * 0.35, width: bs, height: bs * 0.7)

        let leftPath = Path(roundedRect: leftRect, cornerRadius: bs * 0.2)
        let rightPath = Path(roundedRect: rightRect, cornerRadius: bs * 0.2)

        ctx.fill(leftPath, with: color)
        ctx.fill(rightPath, with: color)
    }

    // MARK: - 眼睛

    private func drawEyes(ctx: GraphicsContext, scale: CGFloat, isBlinking: Bool) {
        drawEye(ctx: ctx, scale: scale, isRight: false, isBlinking: isBlinking)
        drawEye(ctx: ctx, scale: scale, isRight: true, isBlinking: isBlinking)
    }

    private func drawEye(ctx: GraphicsContext, scale: CGFloat, isRight: Bool, isBlinking: Bool) {
        let p = expression.params
        let cx = 50 * scale + (isRight ? 18 * scale : -18 * scale)
        let cy = 38 * scale
        let ew = 4.5 * p.eyeW * scale
        let eh = 4.5 * p.eyeH * scale

        let isWink = (expression == .wink && isRight)

        // 困了：横线
        if p.eyeType == .lines {
            var capsule = Path()
            capsule.addEllipse(in: CGRect(x: cx - ew * 1.25, y: cy - 0.75 * scale, width: ew * 2.5, height: 1.5 * scale))
            ctx.fill(capsule, with: .color(.white))
            return
        }

        // 生气：斜线
        if p.eyeType == .slant {
            var line = Path()
            line.move(to: CGPoint(x: cx - ew, y: cy - eh * 0.4))
            line.addLine(to: CGPoint(x: cx + ew, y: cy + eh * 0.4))
            ctx.stroke(line, with: .color(.white), lineWidth: 2 * scale)
            return
        }

        // 大笑：弧形眯眼
        if p.eyeType == .arches {
            var arc = Path()
            arc.move(to: CGPoint(x: cx - ew, y: cy + eh))
            arc.addQuadCurve(to: CGPoint(x: cx + ew, y: cy + eh), control: CGPoint(x: cx, y: cy - eh))
            ctx.stroke(arc, with: .color(.white), lineWidth: 2 * scale)
            return
        }

        // 默认：圆眼
        let displayH = isWink ? ew * 0.15 : (isBlinking ? ew * 0.15 : eh * 2)

        // 眼白
        var eyeCircle = Path()
        eyeCircle.addEllipse(in: CGRect(x: cx - ew, y: cy - displayH / 2, width: ew * 2, height: displayH))
        ctx.fill(eyeCircle, with: .color(.white))

        // 瞳孔
        let pr = ew * 0.35 * p.pupil
        if pr > 0.5 * scale && !isBlinking && !isWink {
            let pupilX: CGFloat = {
                if p.pupilL && !isRight { return cx - 2 * scale }
                if p.pupilR && isRight { return cx + 2 * scale }
                return cx
            }()
            var pupil = Path()
            pupil.addEllipse(in: CGRect(x: pupilX - pr, y: cy - pr, width: pr * 2, height: pr * 2))
            ctx.fill(pupil, with: .color(.black))
        }
    }

    // MARK: - 嘴巴

    private func drawMouth(ctx: GraphicsContext, scale: CGFloat, isBlinking: Bool) {
        let p = expression.params
        let mw = 8 * p.mouthW * scale
        let cx: CGFloat = 50 * scale
        let cy: CGFloat = 60 * scale

        switch p.mouthType {
        case .line:
            var capsule = Path()
            capsule.addEllipse(in: CGRect(x: cx - mw * 0.7, y: cy - 0.75 * scale, width: mw * 1.4, height: 1.5 * scale))
            ctx.fill(capsule, with: .color(.white))

        case .smile:
            var arc = Path()
            arc.move(to: CGPoint(x: cx - mw, y: cy))
            arc.addQuadCurve(to: CGPoint(x: cx + mw, y: cy), control: CGPoint(x: cx, y: cy + mw * 0.4))
            ctx.stroke(arc, with: .color(.white), lineWidth: 2 * scale)

        case .bigSmile:
            // 填色 D 形张嘴
            var shape = Path()
            shape.move(to: CGPoint(x: cx - mw, y: cy))
            shape.addQuadCurve(to: CGPoint(x: cx + mw, y: cy), control: CGPoint(x: cx, y: cy + mw * 0.6))
            shape.addQuadCurve(to: CGPoint(x: cx - mw, y: cy), control: CGPoint(x: cx, y: cy + mw * 0.2))
            shape.closeSubpath()
            ctx.fill(shape, with: .color(.white))

            // 舌头
            var tongue = Path()
            tongue.addEllipse(in: CGRect(x: cx - mw * 0.2, y: cy + mw * 0.05, width: mw * 0.4, height: mw * 0.3))
            ctx.fill(tongue, with: .color(Color(red: 0.9, green: 0.35, blue: 0.3)))

        case .open:
            let lvl = max(0.15, speakingLevel)
            var ellipse = Path()
            let mouthH = max(2 * scale, 6 * scale * lvl)
            ellipse.addEllipse(in: CGRect(x: cx - mw * 0.45, y: cy - mouthH / 2, width: mw * 0.9, height: mouthH))
            ctx.fill(ellipse, with: .color(.white))

        case .sad:
            var arc = Path()
            arc.move(to: CGPoint(x: cx - mw, y: cy + mw * 0.3))
            arc.addQuadCurve(to: CGPoint(x: cx + mw, y: cy + mw * 0.3), control: CGPoint(x: cx, y: cy - mw * 0.2))
            ctx.stroke(arc, with: .color(.white), lineWidth: 2 * scale)

        case .block:
            let bs = mw * 0.7
            var rect = Path()
            rect.addRoundedRect(in: CGRect(x: cx - bs / 2, y: cy - bs / 2, width: bs, height: bs), cornerSize: CGSize(width: 4 * scale, height: 4 * scale))
            ctx.fill(rect, with: .color(.white))

        case .smirk:
            var arc = Path()
            arc.move(to: CGPoint(x: cx - mw * 0.7, y: cy + mw * 0.2))
            arc.addQuadCurve(to: CGPoint(x: cx + mw, y: cy - mw * 0.05), control: CGPoint(x: cx + mw * 0.1, y: cy + mw * 0.5))
            ctx.stroke(arc, with: .color(.white), lineWidth: 2 * scale)

        case .kiss:
            var circle = Path()
            let r = mw * 0.35
            circle.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            ctx.stroke(circle, with: .color(Color(red: 1, green: 0.45, blue: 0.55)), lineWidth: 1.5 * scale)
        }
    }
}
