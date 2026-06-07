import SwiftUI
import WebKit

// MARK: - 直接用 HTML RoboEyes 渲染表情 (60fps)
struct ExpressionWebView: UIViewRepresentable {
    let mood: String
    let lookX: CGFloat
    let lookY: CGFloat
    var isFullscreen: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.preferredContentMode = .mobile

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        config.allowsInlineMediaPlayback = true
        config.suppressesIncrementalRendering = true
        
        // 性能优化：禁用不需要的特性
        let prefs2 = WKPreferences()
        prefs2.javaScriptCanOpenWindowsAutomatically = false
        config.preferences = prefs2

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isUserInteractionEnabled = false
        
        // 强制 60fps 渲染
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        if let url = Bundle.main.url(forResource: "roboeyes", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // 只在值变化时才调用 JS，避免不必要的桥开销
        if mood != context.coordinator.lastMood {
            context.coordinator.lastMood = mood
            webView.evaluateJavaScript("setMood('\(mood)')", completionHandler: nil)
        }
        
        let lxStr = String(format: "%.2f", Double(lookX))
        let lyStr = String(format: "%.2f", Double(lookY))
        if lxStr != context.coordinator.lastLX || lyStr != context.coordinator.lastLY {
            context.coordinator.lastLX = lxStr
            context.coordinator.lastLY = lyStr
            webView.evaluateJavaScript("setLook(\(lxStr), \(lyStr))", completionHandler: nil)
        }
    }

    class Coordinator {
        var lastMood = ""
        var lastLX = ""
        var lastLY = ""
    }
}
