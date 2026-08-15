import Foundation

/// Intercepts every request made through `URLSession.shared` while registered,
/// records it, and answers with a canned response matched by URL-path suffix.
/// Anything unstubbed gets a 599 so a test can never silently hit the network.
///
/// State is global (URLProtocol gives no per-instance hook), so suites using
/// this must run `.serialized` and call `reset()` between tests.
final class StubURLProtocol: URLProtocol {
    struct RecordedRequest {
        let url: URL
        let method: String
        let headers: [String: String]
        let body: Data
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var stubs: [(pathSuffix: String, status: Int, body: String)] = []
    nonisolated(unsafe) private static var recordedStorage: [RecordedRequest] = []

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        stubs = []
        recordedStorage = []
    }

    static func stub(pathSuffix: String, status: Int, jsonBody: String) {
        lock.lock(); defer { lock.unlock() }
        stubs.append((pathSuffix, status, jsonBody))
    }

    static var recorded: [RecordedRequest] {
        lock.lock(); defer { lock.unlock() }
        return recordedStorage
    }

    static func recorded(pathSuffix: String) -> [RecordedRequest] {
        recorded.filter { $0.url.path.hasSuffix(pathSuffix) }
    }

    // MARK: - URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let body = Self.drainBody(of: request)

        Self.lock.lock()
        Self.recordedStorage.append(RecordedRequest(
            url: url,
            method: request.httpMethod ?? "",
            headers: request.allHTTPHeaderFields ?? [:],
            body: body
        ))
        let match = Self.stubs.first { url.path.hasSuffix($0.pathSuffix) }
        Self.lock.unlock()

        let status = match?.status ?? 599
        let responseBody = match?.body ?? #"{"message":"unstubbed request in test"}"#
        let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(responseBody.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// URLSession hands `httpBody` to protocols as a stream — drain either form.
    private static func drainBody(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 64 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: bufferSize)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
