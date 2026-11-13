import Foundation

enum RecipeHTTP {
    private final class NoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.timeoutIntervalForRequest = 18
        config.timeoutIntervalForResource = 35
        return URLSession(configuration: config)
    }

    static func download(_ url: URL, limit: Int) async throws -> (Data, URL) {
        let session = session()
        defer { session.finishTasksAndInvalidate() }
        let (stream, response) = try await session.bytes(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let final = response.url, response.expectedContentLength <= Int64(limit) else {
            throw RecipeImportError.page
        }
        var data = Data()
        for try await byte in stream {
            guard data.count < limit else { throw RecipeImportError.page }
            data.append(byte)
        }
        return (data, final)
    }

    static func google(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let session = session()
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request, delegate: NoRedirect())
        guard let http = response as? HTTPURLResponse else { throw RecipeImportError.service }
        return (data, http)
    }
}
