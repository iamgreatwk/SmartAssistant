import SwiftUI

// MARK: - 小智表情 (1:1 翻译 HTML RoboEyes)
// 纯时间驱动，不依赖 @State 同步

struct ExpressionView: View {
    let expression: ExpressionType
    var size: CGFloat? = nil
    let isFullscreen: Bool
    var lookX: CGFloat = 0
    var lookY: CGFloat = 0

    @State private var tick = Date()

    private let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect() // ~60fps

    init(expression: ExpressionType, size: CGFloat? = nil, speakingLevel: CGFloat = 0, isFullscreen: Bool = false, lookX: CGFloat = 0, lookY: CGFloat = 0) {
        self.expression = expression
        self.size = size
        self.isFullscreen = isFullscreen
        self.lookX = lookX
        self.lookY = lookY
    }

    var body: some View {
        GeometryReader { geo in
            let s = size ?? min(geo.size.width, geo.size.height)
            let scale = s / 100

            Canvas { context, size in
                var ctx = context

                // 时间
                let t = tick.timeIntervalSinceReferenceDate

                // ==== 参数: 直接读取，不做逐帧 lerp ====
                let ep = expression.roboParams

                // 眨眼：直接从时间算
                let blinkPhase = t.truncatingRemainder(dividingBy: 3.5)
                let blinking = blinkPhase < 0.15

                // ==== 坐标 ====
                let ox = (size.width - s) / 2  // s×s 区域的左上角
                let oy = (size.height - s) / 2
                let floatY = sin(t * 1.5) * 1.5 * scale

                // 背景
                ctx.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: size.height)), with: .color(.black))

                // ==== 眼睛尺寸 ====
                let es = scale * 0.25
                let ew = ep.eyeW * es
                let eh = ep.eyeH * es
                let br = ep.borderRadius * es
                let sb = ep.spaceBetween * es

                // 高度
                let lhMul = ep.leftHeightMul
                let rhMul = ep.rightHeightMul
                let lh = blinking ? ew * 0.08 : eh * lhMul
                let rh = blinking ? ew * 0.08 : eh * rhMul

                // 视线偏移
                let lox = lookX * 8 * scale
                let loy = lookY * 6 * scale

                // 眼睛 Y（100单位中 y=36）
                let eyeY = oy + 36 * scale + floatY + ep.yOffset * scale + loy

                // 水平居中
                let totalW = ew * 2 + sb
                let leftX = ox + s / 2 - totalW / 2 + lox
                let rightX = leftX + ew + sb

                let bgC = GraphicsContext.Shading.color(.black)
                let fgC = GraphicsContext.Shading.color(Color(red: 0.49, green: 0.99, blue: 0))

                // 左眼
                drawEye(ctx: &ctx, x: leftX, y: eyeY - lh / 2, w: ew, h: lh, br: br,
                        tired: ep.leftTired, angry: ep.leftAngry, happy: ep.leftHappy, flat: ep.leftFlat,
                        isLeft: true, fg: fgC, bg: bgC)

                // 右眼
                drawEye(ctx: &ctx, x: rightX, y: eyeY - rh / 2, w: ew, h: rh, br: br,
                        tired: ep.rightTired, angry: ep.rightAngry, happy: ep.rightHappy, flat: ep.rightFlat,
                        isLeft: false, fg: fgC, bg: bgC)
            }
        }
        .onReceive(timer) { _ in tick = Date() }
    }

    // MARK: - 单眼绘制

    private func drawEye(ctx: inout GraphicsContext,
                         x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, br: CGFloat,
                         tired: CGFloat, angry: CGFloat, happy: CGFloat, flat: CGFloat,
                         isLeft: Bool,
                         fg: GraphicsContext.Shading, bg: GraphicsContext.Shading) {
        guard h > 0 else { return }

        // 1. 主眼
        let rect = CGRect(x: x, y: y, width: w, height: h)
        ctx.fill(Path(roundedRect: rect, cornerRadius: br), with: fg)

        // 2. 平顶（无聊）
        if flat > 0.05 {
            let fh = h * flat
            ctx.fill(Path(CGRect(x: x - 1, y: y - 1, width: w + 2, height: fh + 1)), with: bg)
        }

        // 3. 疲惫眼皮（外→内）
        if tired > 0.05 {
            let th = h * tired
            var tri = Path()
            if isLeft {
                tri.move(to: CGPoint(x: x, y: y - 0.5))
                tri.addLine(to: CGPoint(x: x + w, y: y - 0.5))
                tri.addLine(to: CGPoint(x: x, y: y + th))
            } else {
                tri.move(to: CGPoint(x: x, y: y - 0.5))
                tri.addLine(to: CGPoint(x: x + w, y: y - 0.5))
                tri.addLine(to: CGPoint(x: x + w, y: y + th))
            }
            tri.closeSubpath()
            ctx.fill(tri, with: bg)
        }

        // 4. 生气眼皮（内→外）
        if angry > 0.05 {
            let ah = h * angry
            var tri = Path()
            if isLeft {
                tri.move(to: CGPoint(x: x, y: y - 0.5))
                tri.addLine(to: CGPoint(x: x + w, y: y - 0.5))
                tri.addLine(to: CGPoint(x: x + w, y: y + ah))
            } else {
                tri.move(to: CGPoint(x: x, y: y - 0.5))
                tri.addLine(to: CGPoint(x: x + w, y: y - 0.5))
                tri.addLine(to: CGPoint(x: x, y: y + ah))
            }
            tri.closeSubpath()
            ctx.fill(tri, with: bg)
        }

        // 5. 开心下眼皮（底部上遮）
        if happy > 0.05 {
            let hh = h * happy
            let hr = CGRect(x: x - 1, y: y + h - hh + 1, width: w + 2, height: h)
            ctx.fill(Path(roundedRect: hr, cornerRadius: br), with: bg)
        }
    }
}
