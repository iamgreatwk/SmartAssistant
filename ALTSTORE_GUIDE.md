# AltStore 签名安装完整指南

## 概述

AltStore 是一个让你可以在未越狱的 iPhone 上用你自己的 Apple ID 签名安装 IPA 的工具。每 7 天需要重新签名一次（AltStore 在后台可自动续签）。

## 第一步：安装 AltStore

### macOS 用户

1. 下载 [AltServer for macOS](https://altstore.io/)
2. 解压并打开 AltServer
3. 用数据线连接 iPhone 到 Mac
4. 菜单栏点击 AltServer 图标 → `Install AltStore` → 选择你的 iPhone
5. 输入 Apple ID 和密码
6. 等待安装完成

### Windows 用户

1. 下载 [AltServer for Windows](https://altstore.io/)
2. 安装 iTunes 和 iCloud（从 Apple 官网下载，不要用 Microsoft Store 版本）
3. 用数据线连接 iPhone
4. 系统托盘点击 AltServer → `Install AltStore` → 选择 iPhone
5. 输入 Apple ID 和密码

### 首次信任

安装 AltStore 后，进入 iPhone：
- **设置** → **通用** → **VPN 与设备管理**
- 找到你的 Apple ID 对应的开发者证书
- 点击 **信任**

## 第二步：获取 IPA

### 方式 1：GitHub Actions（推荐）

1. 将项目推送到你的 GitHub 仓库
2. 进入 GitHub → Actions → Build IPA for AltStore
3. 选择最新的 workflow run
4. 下载 `SmartAssistant-xxxxx` artifact
5. 解压得到 `SmartAssistant.ipa`

### 方式 2：本地构建

```bash
cd SmartAssistant

# 生成 Xcode 项目
xcodegen generate

# 构建 Archive
xcodebuild archive \
  -project SmartAssistant.xcodeproj \
  -scheme SmartAssistant \
  -archivePath build/SmartAssistant.xcarchive \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# 创建 ExportOptions.plist
cat > exportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>compileBitcode</key>
    <false/>
    <key>signingStyle</key>
    <string>manual</string>
</dict>
</plist>
EOF

# 导出 IPA
xcodebuild -exportArchive \
  -archivePath build/SmartAssistant.xcarchive \
  -exportPath build/SmartAssistant \
  -exportOptionsPlist exportOptions.plist \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# IPA 位置
echo "IPA: build/SmartAssistant/SmartAssistant.ipa"
```

## 第三步：签名安装到 iPhone

### 方式 1：通过 AltStore App 直接安装

1. 将 IPA 文件通过隔空投送、邮件等方式传到 iPhone
2. 在 iPhone 上打开「文件」App，找到 IPA 文件
3. 点击 IPA 文件 → 选择用 AltStore 打开
4. 输入 Apple ID 和密码
5. 等待签名安装完成

### 方式 2：通过 AltServer 安装

1. Mac/PC 上打开 AltServer
2. iPhone 通过 WiFi 或数据线连接
3. 确保 AltStore 在 iPhone 后台运行
4. Mac 菜单栏 → AltServer → `Install App via AltServer`
5. 选择 IPA 文件和你的 iPhone

## 第四步：续签与保持

### 自动续签

- 确保 iPhone 与 Mac/PC 在同一 WiFi 网络
- AltServer 在后台运行
- iPhone 上的 AltStore 会自动在后台刷新签名
- 签名过期前 24 小时会提示续签

### 手动续签

1. 打开 iPhone 上的 AltStore
2. 进入 "My Apps" 标签
3. 点击 "Refresh All" 或单个应用的 "Refresh"

### 签名限制

- 免费 Apple ID：最多 3 个签名应用，每 7 天续签
- 付费开发者账号：最多不限应用，签名有效期 1 年
- 签名过期后应用无法打开，需重新签名

## 常见问题

### Q: 安装时提示 "Unable to verify app"
**解决方案**：确保已信任证书（设置 > 通用 > VPN与设备管理 > 信任）

### Q: 7 天后应用闪退
**解决方案**：签名过期，在 AltStore 中刷新签名

### Q: AltStore 显示 "Could not find AltServer"
**解决方案**：确保 Mac/PC 和 iPhone 在同一 WiFi 网络，或通过数据线连接

### Q: 手机端无法直接安装
**解决方案**：使用 AltServer on Mac/PC，通过数据线传输

### Q: 想用自己的 Bundle ID
修改 `project.yml` 中的 `PRODUCT_BUNDLE_IDENTIFIER`，然后重新生成 Xcode 项目和构建。
