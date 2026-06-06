import Foundation

/// StackChan 表情类型
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
        }
    }

    /// 眼型
    enum EyeType {
        case dots      // 圆眼 (默认)
        case arches    // 弧形眯眼 (大笑)
        case slant     // 斜线 (生气)
        case lines     // 横线 (困)
        case big       // 大圆眼 (惊讶/兴奋)
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

    /// 表情参数 — 完全匹配 HTML 预览
    struct ExpressionParams {
        var eyeType: EyeType = .dots
        var eyeW: CGFloat = 1.0       // 眼宽缩放
        var eyeH: CGFloat = 1.0       // 眼高缩放
        var pupil: CGFloat = 0        // 瞳孔半径系数 (0=无瞳孔)
        var pupilL: Bool = false      // 左瞳孔偏移
        var pupilR: Bool = false      // 右瞳孔偏移
        var mouthType: MouthType = .line
        var mouthW: CGFloat = 1.0     // 嘴宽缩放
        var cheek: CGFloat = 0        // 腮红强度 0-1
    }

    var params: ExpressionParams {
        switch self {
        case .normal:
            return ExpressionParams()

        case .happy:
            return ExpressionParams(
                eyeW: 0.9, eyeH: 0.9,
                mouthType: .smile, mouthW: 1.0,
                cheek: 0.5
            )

        case .veryHappy:
            return ExpressionParams(
                eyeType: .arches, eyeW: 0.6, eyeH: 0.6,
                mouthType: .bigSmile, mouthW: 1.3,
                cheek: 0.8
            )

        case .sad:
            return ExpressionParams(
                mouthType: .sad, mouthW: 0.9
            )

        case .angry:
            return ExpressionParams(
                eyeType: .slant,
                pupil: 0.6,
                mouthType: .line, mouthW: 0.8,
                cheek: 0.7
            )

        case .surprised:
            return ExpressionParams(
                eyeType: .big, eyeW: 1.4, eyeH: 1.4,
                pupil: 0.3,
                mouthType: .block, mouthW: 1.1
            )

        case .thinking:
            return ExpressionParams(
                eyeW: 0.85, eyeH: 0.85,
                pupilR: true,
                mouthType: .smirk, mouthW: 0.7
            )

        case .listening:
            return ExpressionParams(
                eyeW: 1.15, eyeH: 1.15,
                mouthType: .smile, mouthW: 0.5
            )

        case .speaking:
            return ExpressionParams(
                mouthType: .open, mouthW: 1.0
            )

        case .sleepy:
            return ExpressionParams(
                eyeType: .lines, eyeW: 0.25, eyeH: 0.25,
                mouthType: .open, mouthW: 0.4
            )

        case .wink:
            return ExpressionParams(
                mouthType: .smile, mouthW: 1.0,
                cheek: 0.3
            )

        case .love:
            return ExpressionParams(
                eyeW: 0.75, eyeH: 0.75,
                mouthType: .kiss, mouthW: 0.9,
                cheek: 1.0
            )

        case .confused:
            return ExpressionParams(
                pupilL: true,
                mouthType: .sad, mouthW: 0.6
            )

        case .cool:
            return ExpressionParams(
                eyeW: 0.95, eyeH: 0.95,
                mouthType: .smirk, mouthW: 1.0
            )

        case .shy:
            return ExpressionParams(
                eyeW: 0.8, eyeH: 0.8,
                pupilR: true,
                mouthType: .smile, mouthW: 0.7,
                cheek: 0.9
            )

        case .excited:
            return ExpressionParams(
                eyeType: .big, eyeW: 1.3, eyeH: 1.3,
                pupil: 0.4,
                mouthType: .bigSmile, mouthW: 1.5,
                cheek: 0.7
            )
        }
    }
}
