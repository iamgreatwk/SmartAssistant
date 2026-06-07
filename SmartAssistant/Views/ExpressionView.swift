import SwiftUI

// MARK: - 小智表情 (RoboEyes 算法)
// 基于 FluxGarage/RoboEyes：填充圆角矩形 + 三角形/矩形眼皮遮盖
// 动画用 Timer + @State 驱动，(current+next)/2 平滑插值

struct ExpressionView: View {
    let expression: ExpressionType
    var size: CGFloat? = nil
    let isFullscreen: Bool

    @State private var displayDate = Date()
    @State private var displayParams: ExpressionType.RoboEyesParams
    @State private var blinking = false
    @State private var blinkTimer = 0
    @State private var savedLeftH: CGFloat = 1
    @State private var savedRightH: CGFloat = 1

    private let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    init(expression: ExpressionType, size: CGFloat? = nil, speakingLevel: CGFloat = 0, isFullscreen: Bool = false) {
        self.expression = expression
        self.size = size
        self.isFullscreen = isFullscreen
        self._displayParams = State(initialValue: expression.roboParams)
    }

    var body: some View {
        GeometryReader { geo in
            let s = size ?? min(geo.size.width, geo.size.height)
            let scale = s / 100
            let t = displayDate.timeIntervalSinceReferenceDate
            let floatOffset = sin(t * 1.5) * 1.5 * scale
            let headTilt = sin(t * 0.8) * 0.8 * .pi / 180
            Canvas { context, size in
                var ctx = context

                ctx.translateBy(x: size.width / 2, y: size.height / 2)
                ctx.rotate(by: Angle(radians: headTilt))
                ctx.translateBy(x: -s / 2, y: -s / 2 + floatOffset)

                // 背景
                ctx.fill(Path(CGRect(x: 0, y: 0, width: s, height: s)), with: .color(.black))

                let ep = expression.roboParams
                let dp = displayParams

                // 平滑过渡后的参数
                let lerp = { (a: CGFloat, b: CGFloat) -> CGFloat in (a + b) / 2 }
                let currentW = lerp(dp.eyeW, ep.eyeW)
                let currentH = lerp(dp.eyeH, ep.eyeH)
                let currentBR = lerp(dp.borderRadius, ep.borderRadius)
                let currentSB = lerp(dp.spaceBetween, ep.spaceBetween)

                // 眼皮插值
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

                // 眼尺寸映射到视图坐标
                let eyeScale = scale * 0.25
                let ew = currentW * eyeScale
                let eh = currentH * eyeScale
                let br = currentBR * eyeScale
                let sb = currentSB * eyeScale

                // 左眼高度
                let leftH = blinking ? ew * 0.08 : eh * lhMul
                let rightH = blinking ? ew * 0.08 : eh * rhMul

                let leftY = 36 * scale - leftH / 2 + yOff * scale
                let rightY = 36 * scale - rightH / 2 + yOff * scale

                // 居中计算左眼 X
                let totalW = ew * 2 + sb
                let leftX = (50 * scale) - totalW / 2
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
            displayParams.leftHeightMul = lerp(displayParams.leftHeightMul, ep.leftHeightMul)
            displayParams.rightHeightMul = lerp(displayParams.rightHeightMul, ep.rightHeightMul)
            displayParams.yOffset = lerp(displayParams.yOffset, ep.yOffset)

            // 自动眨眼
            let blinkPhase = t.truncatingRemainder(dividingBy: 3.5)
            if blinkPhase < 0.15 {
                blinking = true
                displayParams.leftHeightMul = 0.08
                displayParams.rightHeightMul = 0.08
            } else if blinking && blinkPhase >= 0.15 {
                blinking = false
                displayParams.leftHeightMul = ep.leftHeightMul
                displayParams.rightHeightMul = ep.rightHeightMul
            }

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
