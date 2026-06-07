import Foundation

/// 小智表情类型 — 基于 RoboEyes 算法
/// 眼睛：填充圆角矩形 + 三角形/矩形眼皮遮盖
/// 嘴巴：8 种嘴型（保持不变）
enum ExpressionType: String, CaseIterable, Codable {
    case normal     // 正常
    case happy      // 开心
    case veryHappy  // 非常开心
    case sad        // 难过
    case angry      // 生气
    case surprised  // 惊讶
    case thinking   // 思考中
    case listening  // 倾听中
    case speaking   // 说话中
    case sleepy     // 困了
    case wink       // 眨眼(挑逗)
    case love       // 喜欢
    case confused   // 困惑
    case cool       // 酷
    case shy        // 害羞
    case excited    // 兴奋(星星眼)
    // --- 新增 RoboEyes 情绪 ---
    case scared     // 害怕
    case bored      // 无聊
    case focused    // 专注
    case suspicious // 怀疑

    var displayName: String {
        switch self {
        case .normal: return "正常"
        case .happy: return "开心"
        case .veryHappy: return "非常开心"
        case .sad: return "难过"
        case .angry: return "生气"
        case .surprised: return "惊讶"
        case .thinking: return "思考中"
        case .listening: return "倾听中"
        case .speaking: return "说话中"
        case .sleepy: return "困了"
        case .wink: return "眨眼"
        case .love: return "喜欢"
        case .confused: return "困惑"
        case .cool: return "酷"
        case .shy: return "害羞"
        case .excited: return "兴奋"
        case .scared: return "害怕"
        case .bored: return "无聊"
        case .focused: return "专注"
        case .suspicious: return "怀疑"
        }
    }

    var emoji: String {
        switch self {
        case .normal: return "😊"
        case .happy: return "😄"
        case .veryHappy: return "🤣"
        case .sad: return "😢"
        case .angry: return "😠"
        case .surprised: return "😲"
        case .thinking: return "🤔"
        case .listening: return "👂"
        case .speaking: return "🗣️"
        case .sleepy: return "😴"
        case .wink: return "😉"
        case .love: return "🥰"
        case .confused: return "😵"
        case .cool: return "😎"
        case .shy: return "😳"
        case .excited: return "🤩"
        case .scared: return "😨"
        case .bored: return "😑"
        case .focused: return "🧐"
        case .suspicious: return "🤨"
        }
    }

    // MARK: - RoboEyes 参数

    struct RoboEyesParams {
        /// 眼睛尺寸
        var eyeW: CGFloat = 70
        var eyeH: CGFloat = 58
        var borderRadius: CGFloat = 24
        var spaceBetween: CGFloat = 20

        /// 左眼眼皮（0～1，越大遮盖越多）
        var leftTired: CGFloat = 0     // 外→内三角（疲惫）
        var leftAngry: CGFloat = 0     // 内→外三角（生气）
        var leftHappy: CGFloat = 0     // 底部上遮（开心下眼睑）
        var leftFlat: CGFloat = 0      // 平顶遮盖（无聊）

        /// 右眼眼皮（通常与左眼一致，可不对称）
        var rightTired: CGFloat = 0
        var rightAngry: CGFloat = 0
        var rightHappy: CGFloat = 0
        var rightFlat: CGFloat = 0

        /// 单眼高度倍率（1.0=正常，0.08=几乎闭合，1.2=放大）
        var leftHeightMul: CGFloat = 1.0
        var rightHeightMul: CGFloat = 1.0

        /// 垂直偏移（正值=下移，负值=上移）
        var yOffset: CGFloat = 0

        /// 嘴型参数（保持不变）
        var mouthType: MouthType = .line
        var mouthW: CGFloat = 1.0
    }

    /// 嘴型
    enum MouthType {
        case line       // 一字嘴 —
        case smile      // 微笑弧线 )
        case bigSmile   // 大笑 D（填色+舌头）
        case open       // 张嘴 ○ (说话)
        case sad        // 难过弧 (
        case block      // 小方块 ■ (惊讶)
        case smirk      // 歪嘴
        case kiss       // 亲亲 ◎
    }

    /// 当前表情的 RoboEyes 参数
    var roboParams: RoboEyesParams {
        switch self {
        case .normal:
            return RoboEyesParams()

        case .happy:
            return RoboEyesParams(
                eyeW: 64, eyeH: 50, borderRadius: 22, spaceBetween: 22,
                leftHappy: 0.48, rightHappy: 0.48,
                mouthType: .smile, mouthW: 1.0
            )

        case .veryHappy:
            return RoboEyesParams(
                eyeW: 56, eyeH: 46, borderRadius: 26, spaceBetween: 24,
                leftHappy: 0.60, rightHappy: 0.60,
                mouthType: .bigSmile, mouthW: 1.3
            )

        case .sad:
            return RoboEyesParams(
                eyeW: 64, eyeH: 50, borderRadius: 22, spaceBetween: 26,
                leftTired: 0.25, rightTired: 0.25,
                yOffset: 4,
                mouthType: .sad, mouthW: 0.9
            )

        case .angry:
            return RoboEyesParams(
                eyeW: 68, eyeH: 56, borderRadius: 18, spaceBetween: 18,
                leftAngry: 0.5, rightAngry: 0.5,
                mouthType: .line, mouthW: 0.8
            )

        case .surprised:
            return RoboEyesParams(
                eyeW: 78, eyeH: 72, borderRadius: 32, spaceBetween: 16,
                mouthType: .block, mouthW: 1.1
            )

        case .thinking:
            return RoboEyesParams(
                eyeW: 62, eyeH: 48, borderRadius: 16, spaceBetween: 14,
                leftAngry: 0.15, rightAngry: 0.15,
                mouthType: .smirk, mouthW: 0.7
            )

        case .listening:
            return RoboEyesParams(
                eyeW: 74, eyeH: 62, borderRadius: 26, spaceBetween: 18,
                mouthType: .smile, mouthW: 0.5
            )

        case .speaking:
            return RoboEyesParams(
                mouthType: .open, mouthW: 1.0
            )

        case .sleepy:
            return RoboEyesParams(
                eyeW: 68, eyeH: 28, borderRadius: 12, spaceBetween: 24,
                leftTired: 0.65, rightTired: 0.65,
                yOffset: 6,
                mouthType: .open, mouthW: 0.4
            )

        case .wink:
            return RoboEyesParams(
                leftHappy: 0.3, rightHappy: 0,
                leftHeightMul: 1.0, rightHeightMul: 0.08,
                mouthType: .smile, mouthW: 1.0
            )

        case .love:
            return RoboEyesParams(
                eyeW: 56, eyeH: 56, borderRadius: 28, spaceBetween: 24,
                leftHappy: 0.55, rightHappy: 0.55,
                mouthType: .kiss, mouthW: 0.9
            )

        case .confused:
            return RoboEyesParams(
                leftHeightMul: 1.0, rightHeightMul: 0.65,
                yOffset: -8,
                mouthType: .sad, mouthW: 0.6
            )

        case .cool:
            return RoboEyesParams(
                eyeW: 66, eyeH: 52, borderRadius: 22, spaceBetween: 22,
                leftHappy: 0.2, rightHappy: 0.2,
                yOffset: -6,
                mouthType: .smirk, mouthW: 1.0
            )

        case .shy:
            return RoboEyesParams(
                eyeW: 56, eyeH: 56, borderRadius: 26, spaceBetween: 24,
                leftHappy: 0.4, rightHappy: 0.4,
                mouthType: .smile, mouthW: 0.7
            )

        case .excited:
            return RoboEyesParams(
                eyeW: 76, eyeH: 68, borderRadius: 30, spaceBetween: 16,
                leftHappy: 0.35, rightHappy: 0.35,
                mouthType: .bigSmile, mouthW: 1.5
            )

        case .scared:
            return RoboEyesParams(
                eyeW: 52, eyeH: 46, borderRadius: 18, spaceBetween: 36,
                yOffset: -2,
                mouthType: .block, mouthW: 0.8
            )

        case .bored:
            return RoboEyesParams(
                eyeW: 70, eyeH: 44, borderRadius: 12, spaceBetween: 24,
                leftFlat: 0.35, rightFlat: 0.35,
                yOffset: 2,
                mouthType: .line, mouthW: 1.2
            )

        case .focused:
            return RoboEyesParams(
                eyeW: 62, eyeH: 48, borderRadius: 16, spaceBetween: 14,
                leftAngry: 0.15, rightAngry: 0.15,
                mouthType: .line, mouthW: 0.6
            )

        case .suspicious:
            return RoboEyesParams(
                eyeW: 68, eyeH: 56, borderRadius: 20, spaceBetween: 20,
                leftAngry: 0.45, rightAngry: 0,
                rightHeightMul: 0.85,
                mouthType: .smirk, mouthW: 0.8
            )
        }
    }
}
