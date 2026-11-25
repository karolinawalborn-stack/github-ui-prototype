import SwiftUI
import WebKit

@MainActor
final class WebLoginCoordinator: NSObject, WKNavigationDelegate {
    let platform: NetdiskPlatform
    let webView: WKWebView
    let onSaved: () -> Void
    private let credentialStore = CredentialStore.shared

    init(platform: NetdiskPlatform, onSaved: @escaping () -> Void) {
        self.platform = platform
        self.onSaved = onSaved
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
    }

    func load() {
        webView.load(URLRequest(url: Endpoints.config(for: platform).baseURL))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { await saveCookiesIfAvailable() }
    }

    func saveCookiesIfAvailable() async {
        let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        guard !cookies.isEmpty else { return }
        let header = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        try? credentialStore.saveCookie(header, platform: platform)
        onSaved()
    }
}

struct WebLoginView: UIViewRepresentable {
    let platform: NetdiskPlatform
    let onSaved: () -> Void

    func makeCoordinator() -> WebLoginCoordinator { WebLoginCoordinator(platform: platform, onSaved: onSaved) }

    func makeUIView(context: Context) -> WKWebView {
        context.coordinator.load()
        return context.coordinator.webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
