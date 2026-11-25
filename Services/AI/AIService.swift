import Foundation

protocol AIService {
    func streamRewrite(source: String, style: RewriteStyle, model: AIModel) -> AsyncThrowingStream<String, Error>
}

final class MockAIService: AIService {
    func streamRewrite(source: String, style: RewriteStyle, model: AIModel) -> AsyncThrowingStream<String, Error> {
        let output = "整理了一份 2005—2026 年的考研英语真题，每篇都配逐句精讲，二刷查漏刚好用。\n\n夸克 → pan.quark.cn/s/c41e0a77d2f9\n百度 → pan.baidu.com/s/1Ka9Wm3rTq?pwd=6x2m\n迅雷 → pan.xunlei.com/s/VNa1Pq0zR8?pwd=h3k9\n\n链接永久有效，先存再看。"
        let chunks = output.map(String.init)
        return AsyncThrowingStream { continuation in
            Task {
                for chunk in chunks {
                    try? await Task.sleep(nanoseconds: 28_000_000)
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }
}
