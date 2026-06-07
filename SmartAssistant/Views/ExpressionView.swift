import SwiftUI

// MARK: - 小智表情 (RoboEyes 算法)
// 基于 FluxGarage/RoboEyes：填充圆角矩形 + 三角形/矩形眼皮遮盖
// 动画用 Timer + @State 驱动，(current+next)/2 平滑插值

struct ExpressionView: View {
    let expression: ExpressionType
    var size: CGFloat? = nil
    let isFullscreen: Bool

    var lookX: CGFloat = 0
    var lookY: CGFloat = 0

    @State private var displayDate = Date()
    @State private var displayParams: ExpressionType.RoboEyesParams
    @State private var smoothLookX: CGFloat = 0
    @State private var smoothLookY: CGFloat = 0

    private let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    init(expression: ExpressionType, size: CGFloat? = nil, speakingLevel: CGFloat = 0, isFullscreen: Bool = false, lookX: CGFloat = 0, lookY: CGFloat = 0) {
        self.expression = expression
        self.size = size
        self.isFullscreen = isFullscreen
        self.lookX = lookX
        self.lookY = lookY
        self._displayParams = State(initialValue: expression.roboParams)
    }

    var body: some View {
        GeometryReader { geo in
            let s = size ?? min(geo.size.width, geo.size.height)
            let scale = s / 100
            let t = displayDate.timeIntervalSinceReferenceDate
            let floatOffset = sin(t * 1.5) * 1.5 * scale
            Canvas { context, size in
                var ctx = context

                // 原点移到 (s/2, s/2)，s×s 区域居中绘制
                ctx.translateBy(x: (size.width - s) / 2 + s / 2,
                                y: (size.height - s) / 2 + s / 2 + floatOffset)

                // 背景
                ctx.fill(Path(CGRect(x: -s / 2, y: -s / 2, width: s, height: s)), with: .color(.black))

                let ep = expression.roboParams
                let dp = displayParams

                // 平滑过渡
                let lerp = { (a: CGFloat, b: CGFloat) -> CGFloat in (a + b) / 2 }
                let currentW = lerp(dp.eyeW, ep.eyeW)
                let currentH = lerp(dp.eyeH, ep.eyeH)
                let currentBR = lerp(dp.borderRadius, ep.borderRadius)
                let currentSB = lerp(dp.spaceBetween, ep.spaceBetween)
                let lTired = lerp(dp.leftTired, ep.leftTired)
                let rTired = lerp(dp.rightTired, ep.rightTired)
                let lAngry = lerp(dp.leftAngry, ep.leftAngry)
                let rAngry = lerp(dp.rightAngry, ep.rightAngry)
                let lHappy = lerp(dp.leftHappy, ep.leftHappy)
                let rHappy = lerp(dp.rightHappy, ep.rightHappy)
                let lFlat = lerp(dp.leftFlat, ep.leftFlat)
                let rFlat = lerp(dp.rightFlat, ep.rightFlat)
                let lhMul = lerp(dp.leftHeightMul, ep.leftHeightMul)
                let rhMul = lerp(dp.rightHeightMul, ep.rightHeightMul)
                let yOff = lerp(dp.yOffset, ep.yOffset)

                // 尺寸映射
                let eyeScale = scale * 0.25
                let ew = currentW * eyeScale
                let eh = currentH * eyeScale
                let br = currentBR * eyeScale
                let sb = currentSB * eyeScale

                // 眨眼：直接从时间计算
                let blinkPhase = t.truncatingRemainder(dividingBy: 3.5)
                let isBlinking = blinkPhase < 0.15

                let leftH = isBlinking ? ew * 0.08 : eh * lhMul
                let rightH = isBlinking ? ew * 0.08 : eh * rhMul

                let lookOffsetX = smoothLookX * 8 * scale
                let lookOffsetY = smoothLookY * 6 * scale

                // 位置：100单位中眼中心在 y=36（即 canvas 中 y = 36*scale - s/2）
                let eyeCY = 36 * scale - s / 2 + yOff * scale + lookOffsetY
                let leftY = eyeCY - leftH / 2
                let rightY = eyeCY - rightH / 2

                let totalW = ew * 2 + sb
                let leftX = -totalW / 2 + lookOffsetX
                let rightX = leftX + ew + sb

                let bgColor = GraphicsContext.Shading.color(.black)
                let mainColor = GraphicsContext.Shading.color(Color(red: 0.49, green: 0.99, blue: 0)) // #7cfc00 绿色

                // 绘制左眼
                drawRoboEye(ctx: ctx, x: leftX, y: leftY, w: ew, h: leftH, br: br,
                            tired: lTired, angry: lAngry, happy: lHappy, flat: lFlat,
                            isLeft: true, mainColor: mainColor, bgColor: bgColor)

                // 绘制右眼
                drawRoboEye(ctx: ctx, x: rightX, y: rightY, w: ew, h: rightH, br: br,
                            tired: rTired, angry: rAngry, happy: rHappy, flat: rFlat,
                            isLeft: false, mainColor: mainColor, bgColor: bgColor)

                // 不画嘴巴，与 HTML RoboEyes 完全一致
            }
        }
        .onReceive(timer) { _ in
            let t = Date().timeIntervalSinceReferenceDate

            // 平滑过渡 displayParams → expression.roboParams
            let ep = expression.roboParams
            let lerp = { (a: CGFloat, b: CGFloat) -> CGFloat in (a + b) / 2 }

            displayParams.eyeW = lerp(displayParams.eyeW, ep.eyeW)
            displayParams.eyeH = lerp(displayParams.eyeH, ep.eyeH)
            displayParams.borderRadius = lerp(displayParams.borderRadius, ep.borderRadius)
            displayParams.spaceBetween = lerp(displayParams.spaceBetween, ep.spaceBetween)
            displayParams.leftTired = lerp(displayParams.leftTired, ep.leftTired)
            displayParams.rightTired = lerp(displayParams.rightTired, ep.rightTired)
            displayParams.leftAngry = lerp(displayParams.leftAngry, ep.leftAngry)
            displayParams.rightAngry = lerp(displayParams.rightAngry, ep.rightAngry)
            displayParams.leftHappy = lerp(displayParams.leftHappy, ep.leftHappy)
            displayParams.rightHappy = lerp(displayParams.rightHappy, ep.rightHappy)
            displayParams.leftFlat = lerp(displayParams.leftFlat, ep.leftFlat)
            displayParams.rightFlat = lerp(displayParams.rightFlat, ep.rightFlat)
            displayParams.yOffset = lerp(displayParams.yOffset, ep.yOffset)
            displayParams.leftHeightMul = lerp(displayParams.leftHeightMul, ep.leftHeightMul)
            displayParams.rightHeightMul = lerp(displayParams.rightHeightMul, ep.rightHeightMul)

            // 视线平滑过渡
            let lerpF = { (a: CGFloat, b: CGFloat) -> CGFloat in a + (b - a) * 0.12 }
            smoothLookX = lerpF(smoothLookX, lookX)
            smoothLookY = lerpF(smoothLookY, lookY)

            displayDate = Date()
        }
    }

    // MARK: - RoboEyes 眼睛绘制

    private func drawRoboEye(ctx: GraphicsContext,
                             x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, br: CGFloat,
                             tired: CGFloat, angry: CGFloat, happy: CGFloat, flat: CGFloat,
                             isLeft: Bool,
                             mainColor: GraphicsContext.Shading, bgColor: GraphicsContext.Shading) {
        guard h > 0 else { return }

        // 1. 主眼（填充圆角矩形）
        let eyeRect = CGRect(x: x, y: y, width: w, height: h)
        ctx.fill(Path(roundedRect: eyeRect, cornerRadius: br), with: mainColor)

        // 2. 平顶遮盖（无聊）
        if flat > 0.05 {
            let fh = h * flat
            let flatRect = CGRect(x: x - 1, y: y - 1, width: w + 2, height: fh + 1)
            ctx.fill(Path(flatRect), with: bgColor)
        }

        // 3. 疲惫眼皮（外→内三角）
        if tired > 0.05 {
            let th = h * tired
            var triangle = Path()
            if isLeft {
                triangle.move(to: CGPoint(x: x, y: y - 0.5))
                triangle.addLine(to: CGPoint(x: x + w, y: y - 0.5))
                triangle.addLine(to: CGPoint(x: x, y: y + th))
            } else {
                triangle.move(to: CGPoint(x: x, y: y - 0.5))
                triangle.addLine(to: CGPoint(x: x + w, y: y - 0.5))
                triangle.addLine(to: CGPoint(x: x + w, y: y + th))
            }
            triangle.closeSubpath()
            ctx.fill(triangle, with: bgColor)
        }

        // 4. 生气眼皮（内→外三角）
        if angry > 0.05 {
            let ah = h * angry
            var triangle = Path()
            if isLeft {
                triangle.move(to: CGPoint(x: x, y: y - 0.5))
                triangle.addLine(to: CGPoint(x: x + w, y: y - 0.5))
                triangle.addLine(to: CGPoint(x: x + w, y: y + ah))
            } else {
                triangle.move(to: CGPoint(x: x, y: y - 0.5))
                triangle.addLine(to: CGPoint(x: x + w, y: y - 0.5))
                triangle.addLine(to: CGPoint(x: x, y: y + ah))
            }
            triangle.closeSubpath()
            ctx.fill(triangle, with: bgColor)
        }

        // 5. 开心下眼皮（底部上遮）
        if happy > 0.05 {
            let hh = h * happy
            let happyRect = CGRect(x: x - 1, y: y + h - hh + 1, width: w + 2, height: h)
            ctx.fill(Path(roundedRect: happyRect, cornerRadius: br), with: bgColor)
        }
    }
}
