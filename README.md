# 小智助手 (SmartAssistant)

iOS 桌面电子宠物，通过 RoboEyes 表情 + 声音与用户互动，感知情绪、响应传感器事件。

## 核心特性

### 电子宠物模式
- 不说话，只通过表情和声音回应
- 语音输入 → AI 情绪推理 → 表情 + beep 音
- 自动语音监听，唤醒后可连续对话

### RoboEyes 表情系统
- WKWebView + HTML 渲染，60fps 流畅动画
- 20 种情绪表情（正常/开心/难过/生气/惊讶/害怕/困惑/害羞/眨眼...）
- 4 种眼皮形态：疲惫三角、生气三角、开心下睑、无聊平顶
- 自然眨眼 + 视线扫视 + 空闲表情循环
- 全 JSON 配置驱动，修改无需重编译

### 传感器交互
- 14 种传感器触发（摇晃/倒置/倾斜/旋转/快移/掉落/静止/黑暗/海拔变化/走路/靠近/高温/拿起）
- AND 条件引擎，多传感器组合触发
- 传感器 → JSON 阈值 → 表情 + 序列动画（不经过 AI）

### 调试系统
- iOS 内置调试面板：实时显示语音识别、AI 输入输出、情绪、Token 统计、余额
- AI 调用全程日志（请求/响应/耗时/Token）
- 桌面调试工具：`AIDebugger.html`（AI 联调）、`ExpressionDebugger.html`（表情参数）

## 项目结构

```
SmartAssistant/
├── AIDebugger.html              # AI + 表情 + 传感器联调工具
├── ExpressionDebugger.html      # 表情参数/序列/传感器调试工具
├── proxy.py                     # CORS 代理（调试用）
├── SmartAssistantPreview.html   # 表情预览
├── .github/workflows/           # CI/CD
├── SmartAssistant/
│   ├── App/
│   │   ├── SmartAssistantApp.swift
│   │   └── AppDelegate.swift
│   ├── Models/
│   │   ├── ExpressionType.swift      # 20 种情绪枚举 + RoboEyesParams
│   │   ├── ExpressionConfig.swift    # JSON 配置加载器
│   │   ├── ChatMessage.swift         # 消息模型 + AppConfig + BalanceInfo
│   │   └── SensorData.swift          # 传感器数据模型
│   ├── Services/
│   │   ├── AIChatService.swift       # AI 对话（SiliconFlow / OpenAI 兼容）
│   │   ├── SpeechRecognitionService.swift
│   │   ├── MotionService.swift       # 加速度/陀螺仪/姿态
│   │   ├── LocationService.swift
│   │   ├── CameraService.swift
│   │   ├── MicrophoneService.swift
│   │   └── SpeakerService.swift      # beep 音生成
│   ├── ViewModels/
│   │   ├── ChatViewModel.swift       # 核心交互逻辑
│   │   └── SensorViewModel.swift
│   ├── Views/
│   │   ├── ContentView.swift         # 主视图（表情 + 调试面板 + 照片预览）
│   │   ├── ExpressionWebView.swift   # WKWebView 表情渲染
│   │   ├── SettingsView.swift        # 设置页
│   │   └── SensorDashboardView.swift
│   ├── Utils/
│   │   └── PermissionManager.swift
│   └── Resources/
│       ├── roboeyes.html             # RoboEyes 渲染引擎
│       ├── expressions.json          # 表情/关键词/序列/传感器配置
│       └── Info.plist
```

## 快速开始

### 前置条件
- macOS + Xcode 16+
- iOS 17.0+ 设备（仅横屏）

### 1. 生成项目
```bash
cd SmartAssistant
xcodegen generate
open SmartAssistant.xcodeproj
```

### 2. 配置 AI API
在应用「设置」中填写：
- **API 端点**：默认 `https://api.siliconflow.cn/v1/chat/completions`
- **API Key**：你的 SiliconFlow Key
- **模型**：默认 `deepseek-ai/DeepSeek-V4-Flash`
- **余额 API**：默认 `https://api.siliconflow.cn/v1/user/info`

### 3. 运行
Xcode 选择设备 → `Cmd+R`

### 4. GitHub Actions 构建
推送代码自动触发 IPA 构建，用 AltStore 签名安装。

## 桌面调试工具

### AIDebugger.html
浏览器打开，功能：
- 配置 AI API（端点/Key/模型/余额）
- 手动输入文字 → AI 情绪推理 → RoboEyes 表情预览
- 14 种传感器参数化模拟
- 传感器原始值模拟器（加速度/陀螺仪/光照/温度/海拔...）
- 加载 iOS 的 `expressions.json` 实时调试
- CORS 问题用 `python proxy.py` + 勾选"代理"

### ExpressionDebugger.html
离线调试表情参数/关键词/序列/传感器配置，配合 `expressions.json` 使用。

## 表情配置文件

`SmartAssistant/Resources/expressions.json` 包含：
- `moods` — 20 种表情的 RoboEyes 参数
- `emotionKeywords` — 中文关键词 → 情绪映射
- `emotionClusters` — 情绪循环簇
- `sequences` — 8 种动画序列
- `sensorTriggers` — 14 种传感器触发条件
- `petEmpathy` — 情绪共情映射
- `commands` — 指令检测（拍照/天气等）

修改后放入 iOS 的 Documents 目录（通过 iTunes 文件共享），应用重启生效，无需重新打包。

## 可用 AI 服务

兼容 OpenAI Chat Completions API 格式：
- [SiliconFlow](https://siliconflow.cn)（默认，DeepSeek 模型）
- [Groq](https://console.groq.com)
- [Together AI](https://www.together.ai)
- [DeepSeek](https://platform.deepseek.com)
- 自部署 vLLM / Ollama

## License

MIT
