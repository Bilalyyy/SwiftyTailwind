import Foundation
import AsyncHTTPClient
import NIOCore
import NIOFoundationCompat
@testable import SwiftyTailwind

/// Default implementation backed by AsyncHTTPClient.HTTPClient
final class HTTPNetworkClient: NetworkClient {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    func get(url: String, headers: [(String, String)]?, timeoutSeconds: Int) async throws -> Data {
        var request = HTTPClientRequest(url: url)
        if let headers {
            for (name, value) in headers { request.headers.add(name: name, value: value) }
        }
        let response = try await httpClient.execute(request, timeout: .seconds(Int64(timeoutSeconds)))
        let body = try await response.body.collect(upTo: 1024 * 1024 * 20) // 20MB safety
        return Data(buffer: body)
    }

    func download(url: String, to destinationPath: String, progress: @escaping (_ receivedBytes: Int64, _ totalBytes: Int64?) -> Void) async throws {
        let request = try HTTPClient.Request(url: url)
        // Use the same FileDownloadDelegate as Downloader currently uses
        let delegate = try FileDownloadDelegate(path: destinationPath, reportProgress: { p in
            progress(Int64(p.receivedBytes), p.totalBytes.map(Int64.init))
        })
        try await withCheckedThrowingContinuation { continuation in
            httpClient.execute(request: request, delegate: delegate).futureResult.whenComplete { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
