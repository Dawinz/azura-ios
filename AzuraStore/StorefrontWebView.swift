import SwiftUI
import WebKit

/// Full storefront UI from the live Azura Store site (Hot Sales, Flash Sale, etc.).
struct StorefrontWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.isOpaque = true
        webView.backgroundColor = .white
        webView.customUserAgent =
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1 AzuraStore/1.1"
        context.coordinator.webView = webView
        webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Keep the first loaded storefront; don't thrash reloads on SwiftUI redraws.
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var webView: WKWebView?

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let dest = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            let scheme = dest.scheme?.lowercased() ?? ""
            if scheme == "tel" || scheme == "mailto" || scheme == "sms" {
                UIApplication.shared.open(dest)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }
    }
}

struct StorefrontShell: View {
    @EnvironmentObject var store: ShopStore
    @State private var isLoading = true

    private var storefrontURL: URL {
        var raw = store.storeURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { raw = "https://azuramall.shop/" }
        if !raw.lowercased().hasPrefix("http") { raw = "https://\(raw)" }
        if !raw.hasSuffix("/") { raw += "/" }
        return URL(string: raw) ?? URL(string: "https://azuramall.shop/")!
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            StorefrontWebView(url: storefrontURL)
                .ignoresSafeArea()
            if isLoading {
                ProgressView("Loading Azura Store…")
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .onAppear {
            // Hide spinner once the page has had time to paint.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                isLoading = false
            }
        }
    }
}
