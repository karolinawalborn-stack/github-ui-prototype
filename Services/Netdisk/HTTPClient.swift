import Foundation

struct HTTPRequest {
    let method: String
    let url: URL
    var headers: [String: String] = [:]
    var query: [URLQueryItem] = []
    var body: Data?

    func makeURLRequest() -> URLRequest {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        var request = URLRequest(url: components?.url ?? url)
        request.httpMethod = method
        request.httpBody = body
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        return request
    }
}

enum HTTPClientError: Error {
    case invalidResponse
    case status(Int, String)
    case emptyBody
}

final class HTTPClient {
    static let shared = HTTPClient()
    private let session: URLSession
    private let logger = DiagnosticLogger.shared

    init(session: URLSession = .shared) { self.session = session }

    func data(for request: HTTPRequest, platform: NetdiskPlatform? = nil) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request.makeURLRequest())
            guard let http = response as? HTTPURLResponse else { throw HTTPClientError.invalidResponse }
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            guard (200..<300).contains(http.statusCode) else {
                let error = HTTPClientError.status(http.statusCode, bodyText)
                if let platform { logger.record(platform: platform, method: request.method, url: request.url.absoluteString, parameters: request.body, statusCode: http.statusCode, body: bodyText, error: error) }
                throw error
            }
            return (data, http)
        } catch {
            if let platform { logger.record(platform: platform, method: request.method, url: request.url.absoluteString, parameters: request.body, statusCode: nil, body: nil, error: error) }
            throw error
        }
    }

    func json<T: Decodable>(_ type: T.Type, request: HTTPRequest, platform: NetdiskPlatform) async throws -> T {
        let (data, _) = try await self.data(for: request, platform: platform)
        guard !data.isEmpty else { throw HTTPClientError.emptyBody }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
