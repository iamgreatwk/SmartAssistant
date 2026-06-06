# 小智助手 (SmartAssistant)

一个功能完整的 iOS 智能助手应用，集成多传感器感知、StackChan 风格表情系统、语音对话。

## 功能特性

### 🤖 智能对话
- 语音输入（Speech Recognition）
- 文字输入
- AI 对话（兼容 OpenAI API）
- TTS 语音播报（AVSpeechSynthesizer）
- 自动语音监听 + 静音检测

### 🎭 StackChan 表情系统
- 16 种动画表情（正常、开心、难过、思考、说话...）
- 眨眼动画
- 随音量变化的说话嘴型
- 浮动、旋转等自然动画

### 📡 传感器集成
| 传感器 | 框架 | 功能 |
|--------|------|------|
| 摄像头 | AVFoundation | 前后摄切换、拍照 |
| 麦克风 | AVFoundation | 录音、音量检测 |
| 扬声器 | AVFoundation | TTS 播报、提示音 |
| 加速度计 | CoreMotion | 三轴加速度、移动检测 |
| 陀螺仪 | CoreMotion | 三轴角速度 |
| 磁力计 | CoreMotion | 磁场方向 |
| 姿态 | CoreMotion | Roll/Pitch/Yaw |
| 计步器 | CoreMotion/CMPedometer | 步数统计 |
| GPS 定位 | CoreLocation | 经纬度、速度、海拔、方向 |

### 🏗️ 构建与分发
- GitHub Actions 自动构建 IPA
- 支持 AltStore 侧载签名
- 无需开发者账号（自用签名）

## 项目结构

```
SmartAssistant/
├── .github/workflows/build.yml    # CI/CD 工作流
├── project.yml                     # XcodeGen 配置
├── SmartAssistant/
│   ├── App/
│   │   ├── SmartAssistantApp.swift  # 应用入口
│   │   └── AppDelegate.swift       # 代理（音频等）
│   ├── Models/
│   │   ├── SensorData.swift        # 传感器数据模型
│   │   ├── ChatMessage.swift       # 对话消息模型
│   │   └── ExpressionType.swift    # 表情类型定义
│   ├── Services/
│   │   ├── CameraService.swift     # 摄像头服务
│   │   ├── MicrophoneService.swift # 麦克风服务
│   │   ├── SpeakerService.swift    # 扬声器/TTS服务
│   │   ├── MotionService.swift     # 运动传感器服务
│   │   ├── LocationService.swift   # 定位服务
│   │   ├── SpeechRecognitionService.swift  # 语音识别
│   │   └── AIChatService.swift     # AI对话服务
│   ├── ViewModels/
│   │   ├── ChatViewModel.swift     # 对话ViewModel
│   │   └── SensorViewModel.swift   # 传感器ViewModel
│   ├── Views/
│   │   ├── ContentView.swift       # 主视图（Tab导航）
│   │   ├── ExpressionView.swift    # StackChan表情视图
│   │   ├── SensorDashboardView.swift  # 传感器仪表盘
│   │   ├── CameraPreviewView.swift # 相机预览
│   │   └── SettingsView.swift      # 设置视图
│   ├── Utils/
│   │   └── PermissionManager.swift  # 权限管理器
│   └── Resources/
│       └── Info.plist              # 应用配置（含所有权限声明）
```

## 快速开始

### 前置条件

1. **macOS** + **Xcode 16+**
2. 安装 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：
   ```bash
   brew install xcodegen
   ```
3. GitHub 账号（用于 Actions 构建）

### 1. 生成 Xcode 项目

```bash
cd SmartAssistant
xcodegen generate
open SmartAssistant.xcodeproj
```

### 2. 配置 AI API

在应用「设置」页面配置：
- **API 端点**：`https://api.openai.com/v1/chat/completions`
- **API Key**：你的 OpenAI API Key
- **模型**：`gpt-4o`（或其他兼容模型）

也可以使用任何 OpenAI 兼容的 API 服务。

### 3. 本地运行

在 Xcode 中选择你的 iPhone，按 `Cmd+R` 运行。

### 4. GitHub Actions 自动构建

1. 将代码推送到 GitHub
2. Actions 自动触发构建
3. 在 Actions 页面下载 IPA artifact
4. 用 AltStore 签名安装

## AltStore 安装指南

### 什么是 AltStore？

[AltStore](https://altstore.io/) 是一个 iOS 侧载工具，可以用你自己的 Apple ID 签名安装 IPA，无需越狱。

### 安装步骤

1. **安装 AltStore**
   - 下载 [AltServer](https://altstore.io/)（macOS/Windows）
   - 连接 iPhone，通过 AltServer 安装 AltStore 到手机上

2. **获取 IPA**
   - 从 GitHub Actions Artifact 下载 `SmartAssistant.ipa`
   - 或者本地用 Xcode 构建 IPA

3. **签名安装**
   - 打开 iPhone 上的 AltStore
   - 进入 "My Apps" 标签
   - 点击 "+" 按钮，选择 IPA 文件
   - 输入你的 Apple ID 和密码
   - 等待签名完成

4. **信任证书**
   - 首次安装后，进入 设置 > 通用 > VPN与设备管理
   - 信任你的开发者证书

> **注意**：免费 Apple ID 签名的应用每 7 天需要重新签名。保持 AltStore 在后台运行可自动续签。

## 权限说明

应用需要以下权限（在 Info.plist 中已声明）：

| 权限 | 用途 |
|------|------|
| 摄像头 | 物体识别、场景感知 |
| 麦克风 | 语音输入 |
| 语音识别 | 语音转文字 |
| 定位 | 基于位置的服务 |
| 运动传感器 | 设备姿态感知 |
| 相册 | 图片分析处理 |

## 技术架构

```
┌─────────────────────────────────────────┐
│               SwiftUI Views              │
│  ContentView / ChatView / Dashboard     │
├─────────────────────────────────────────┤
│            ViewModels (MVVM)             │
│  ChatViewModel / SensorViewModel        │
├─────────────────────────────────────────┤
│              Services Layer              │
│  Camera / Mic / Speaker / Motion        │
│  Location / SpeechRecog / AIChat        │
├─────────────────────────────────────────┤
│          iOS System Frameworks           │
│  AVFoundation / CoreMotion /            │
│  CoreLocation / Speech / SwiftUI        │
└─────────────────────────────────────────┘
```

## 自定义配置

### 修改系统提示词

在设置中编辑「系统提示词」，定义助手的性格和行为。

### 使用其他 AI 服务

兼容 OpenAI API 格式的任何服务：
- [Groq](https://console.groq.com)（免费额度）
- [Together AI](https://www.together.ai/)
- [DeepSeek](https://platform.deepseek.com/)
- 自部署的 [vLLM](https://github.com/vllm-project/vllm) / [Ollama](https://ollama.ai/)
- 国内服务如百炼、智谱等（使用兼容端点）

### 修改 TTS 语音

`SpeakerService.swift` 中的 `TTSConfig.voiceIdentifier`。

## License

MIT — 个人使用项目
