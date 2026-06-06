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
    
    /// 表情参数
    struct ExpressionParams {
        var eyeScale: CGFloat = 1.0
        var eyeOffsetY: CGFloat = 0
        var pupilScale: CGFloat = 1.0
        var pupilOffsetX: CGFloat = 0
        var mouthType: MouthType = .normal
        var mouthScale: CGFloat = 1.0
        var cheekColor: CGFloat = 0     // 腮红 0-1
    }
    
    enum MouthType {
        case normal     // 一字嘴 —
        case smile      // 微笑弧线 )
        case bigSmile   // 大笑 D
        case open       // 张嘴 ○ (说话)
        case sad        // 难过嘴 (
        case surprised  // 小方块 ■
        case smirk      // 歪嘴
        case kiss       // 亲亲 ◎
    }
    
    var params: ExpressionParams {
        switch self {
        case .normal:
            return ExpressionParams(mouthType: .normal, mouthScale: 1.0)
            
        case .happy:
            return ExpressionParams(
                eyeScale: 0.9, mouthType: .smile, mouthScale: 1.0, cheekColor: 0.5
            )
            
        case .veryHappy:
            return ExpressionParams(
                eyeScale: 0.65, mouthType: .bigSmile, mouthScale: 1.3, cheekColor: 0.8
            )
            
        case .sad:
            return ExpressionParams(
                eyeScale: 1.0, eyeOffsetY: 3, pupilScale: 0.8,
                mouthType: .sad, mouthScale: 0.9
            )
            
        case .angry:
            return ExpressionParams(
                eyeScale: 0.95, pupilScale: 0.6, mouthType: .normal,
                mouthScale: 0.8, cheekColor: 0.7
            )
            
        case .surprised:
            return ExpressionParams(
                eyeScale: 1.4, pupilScale: 0.3, mouthType: .surprised, mouthScale: 1.1
            )
            
        case .thinking:
            return ExpressionParams(
                eyeScale: 0.85, pupilOffsetX: 10, mouthType: .smirk, mouthScale: 0.7
            )
            
        case .listening:
            return ExpressionParams(
                eyeScale: 1.15, pupilScale: 1.2, mouthType: .smile, mouthScale: 0.5
            )
            
        case .speaking:
            return ExpressionParams(mouthType: .open, mouthScale: 1.0)
            
        case .sleepy:
            return ExpressionParams(eyeScale: 0.25, mouthType: .open, mouthScale: 0.4)
            
        case .wink:
            return ExpressionParams(
                eyeScale: 1.0, mouthType: .smile, mouthScale: 1.0, cheekColor: 0.3
            )
            
        case .love:
            return ExpressionParams(
                eyeScale: 0.75, mouthType: .kiss, mouthScale: 0.9, cheekColor: 1.0
            )
            
        case .confused:
            return ExpressionParams(
                eyeScale: 1.0, pupilOffsetX: -6, mouthType: .sad, mouthScale: 0.6
            )
            
        case .cool:
            return ExpressionParams(
                eyeScale: 0.95, mouthType: .smirk, mouthScale: 1.0
            )
            
        case .shy:
            return ExpressionParams(
                eyeScale: 0.8, pupilOffsetX: 6, mouthType: .smile,
                mouthScale: 0.7, cheekColor: 0.9
            )
            
        case .excited:
            return ExpressionParams(
                eyeScale: 1.3, pupilScale: 0.4, mouthType: .bigSmile,
                mouthScale: 1.5, cheekColor: 0.7
            )
        }
    }
}
