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
        case line
        case smile
        case bigSmile
        case open
        case sad
        case block
        case smirk
        case kiss
    }
    
    /// 动画序列帧（供 ExpressionConfig 使用）
    struct SeqStep {
        let expr: ExpressionType
        let lx: CGFloat
        let ly: CGFloat
        let isBlink: Bool
        
        init(expr: ExpressionType, lx: CGFloat = 0, ly: CGFloat = 0, blink: Bool = false) {
            self.expr = expr; self.lx = lx; self.ly = ly; self.isBlink = blink
        }
    }

    /// 当前表情的 RoboEyes 参数
    /// 从 expressions.json 读取表情参数
    var roboParams: RoboEyesParams {
        let config = ExpressionConfig.shared
        if let mood = config.moods[rawValue] {
            return RoboEyesParams(
                eyeW: mood.eyeW, eyeH: mood.eyeH,
                borderRadius: mood.br, spaceBetween: mood.sb,
                leftTired: mood.lT, rightTired: mood.rT,
                leftAngry: mood.lA, rightAngry: mood.rA,
                leftHappy: mood.lH, rightHappy: mood.rH,
                leftFlat: mood.lF, rightFlat: mood.rF,
                leftHeightMul: mood.lM, rightHeightMul: mood.rM,
                yOffset: mood.yo
            )
        }
        return RoboEyesParams()
    }
}
