#!/bin/bash
# 本地构建脚本 — 生成 Xcode 项目并构建 IPA

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
SCHEME="SmartAssistant"

echo "🔨 小智助手 - 本地构建脚本"
echo "=========================="
echo ""

# 检查 XcodeGen
if ! command -v xcodegen &> /dev/null; then
    echo "❌ 需要安装 XcodeGen"
    echo "   brew install xcodegen"
    exit 1
fi

# 生成 Xcode 项目
echo "📦 生成 Xcode 项目..."
cd "$PROJECT_DIR"
xcodegen generate

# 清理旧构建
echo "🧹 清理旧构建..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 构建 Archive
echo "🏗️ 构建 Archive..."
xcodebuild archive \
    -project "$PROJECT_DIR/SmartAssistant.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$BUILD_DIR/$SCHEME.xcarchive" \
    -destination 'generic/platform=iOS' \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    DEVELOPMENT_TEAM="" \
    PROVISIONING_PROFILE_SPECIFIER="" | xcpretty || xcodebuild archive \
    -project "$PROJECT_DIR/SmartAssistant.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$BUILD_DIR/$SCHEME.xcarchive" \
    -destination 'generic/platform=iOS' \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    DEVELOPMENT_TEAM="" \
    PROVISIONING_PROFILE_SPECIFIER=""

echo ""
echo "📦 导出 IPA..."

# 创建 ExportOptions.plist
cat > "$BUILD_DIR/exportOptions.plist" << 'EOF'
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
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/$SCHEME.xcarchive" \
    -exportPath "$BUILD_DIR/$SCHEME" \
    -exportOptionsPlist "$BUILD_DIR/exportOptions.plist" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

IPA_PATH="$BUILD_DIR/$SCHEME/$SCHEME.ipa"

if [ -f "$IPA_PATH" ]; then
    echo ""
    echo "✅ 构建成功！"
    echo "📱 IPA 路径: $IPA_PATH"
    echo "📏 文件大小: $(du -h "$IPA_PATH" | cut -f1)"
    echo ""
    echo "🔜 下一步："
    echo "   1. 将 IPA 传到 iPhone"
    echo "   2. 用 AltStore 打开并签名安装"
    echo "   3. 或者用 AltServer 直接安装"
    echo ""
    echo "📖 详细指南: ALTSTORE_GUIDE.md"
else
    echo "❌ 构建失败，未找到 IPA 文件"
    exit 1
fi
