import Foundation
import AsyncHTTPClient
import NIOCore
import NIOFoundationCompat
import NIOHTTP1

/// Concrete implementation of `NetworkClient` backed by AsyncHTTPClient.
final class HTTPNetworkClient: NetworkClient, @unchecked Sendable {
    private let httpClient: HTTPClient
    private let ownsHTTPClient: Bool

    /// Initialize with an existing HTTPClient or create your own.
    /// - Parameters:
    ///   - httpClient: The HTTPClient instance to use.
    ///   - ownsHTTPClient: Whether this instance is responsible for shutting down the client.
    init(httpClient: HTTPClient, ownsHTTPClient: Bool = false) {
        self.httpClient = httpClient
        self.ownsHTTPClient = ownsHTTPClient
    }

    deinit {
        guard ownsHTTPClient else { return }
        do {
            try httpClient.syncShutdown()
        } catch {
            // Best-effort shutdown to avoid leaking resources.
        }
    }

    /// Execute a simple GET request and return the full body as Data.
    func get(url: String, headers: [(String, String)]?, timeoutSeconds: Int) async throws -> Data {
        var request = try HTTPClient.Request(url: url, method: .GET)
        if let headers {
            for (name, value) in headers { request.headers.add(name: name, value: value) }
        }
        let deadline = NIODeadline.now() + .seconds(Int64(timeoutSeconds))
        let response = try await httpClient.execute(request: request, deadline: deadline).get()
        guard (200..<300).contains(response.status.code) else {
            throw URLError(.badServerResponse)
        }
        if var byteBuffer = response.body { // ByteBuffer -> Data
            return byteBuffer.readData(length: byteBuffer.readableBytes) ?? Data()
        } else {
            return Data()
        }
    }

    /// Download a file to a path, reporting progress.
    func download(url: String, to destinationPath: String, progress: @escaping @Sendable (_ receivedBytes: Int64, _ totalBytes: Int64?) -> Void) async throws {
        let request = try HTTPClient.Request(url: url, method: .GET)
        // Use the non-delegate execute to avoid generic inference issues
        let response = try await httpClient.execute(request: request).get()
        guard (200..<300).contains(response.status.code) else {
            throw URLError(.badServerResponse)
        }

        // Prepare destination file
        let destinationURL = URL(fileURLWithPath: destinationPath)
        // Ensure parent directory exists
        try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Ensure destination file exists
        if !FileManager.default.fileExists(atPath: destinationURL.path) {
            FileManager.default.createFile(atPath: destinationURL.path, contents: nil)
        }
        // Write streaming body to file while reporting progress
        let handle = try FileHandle(forWritingTo: destinationURL)
        try handle.truncate(atOffset: 0)
        defer { try? handle.close() }

        let total = response.headers.first(name: "Content-Length").flatMap(Int64.init)
        var received: Int64 = 0

        if var body = response.body { // buffered response
            let data = body.readData(length: body.readableBytes) ?? Data()
            try handle.write(contentsOf: data)
            received += Int64(data.count)
            progress(received, total)
        } else {
            // Fallback to streaming using a delegate
            final class Delegate: HTTPClientResponseDelegate, @unchecked Sendable {
                typealias Response = Void
                let destinationURL: URL
                let progress: @Sendable (Int64, Int64?) -> Void
                var handle: FileHandle?
                var received: Int64 = 0
                let total: Int64?

                init(destinationURL: URL, total: Int64?, progress: @escaping @Sendable (Int64, Int64?) -> Void) {
                    self.destinationURL = destinationURL
                    self.total = total
                    self.progress = progress
                }

                func didReceiveHead(task: HTTPClient.Task<Void>, _ head: HTTPResponseHead) -> EventLoopFuture<Void> {
                    do {
                        // Ensure the file exists; create/truncate for writing
                        if !FileManager.default.fileExists(atPath: destinationURL.path) {
                            FileManager.default.createFile(atPath: destinationURL.path, contents: nil)
                        }
                        self.handle = try FileHandle(forWritingTo: destinationURL)
                        try self.handle?.truncate(atOffset: 0)
                    } catch {
                        return task.eventLoop.makeFailedFuture(error)
                    }
                    return task.eventLoop.makeSucceededFuture(())
                }

                func didReceiveBodyPart(task: HTTPClient.Task<Void>, _ buffer: ByteBuffer) -> EventLoopFuture<Void> {
                    do {
                        if let data = buffer.getData(at: buffer.readerIndex, length: buffer.readableBytes) {
                            try self.handle?.write(contentsOf: data)
                            received += Int64(data.count)
                            progress(received, total)
                        }
                        return task.eventLoop.makeSucceededFuture(())
                    } catch {
                        return task.eventLoop.makeFailedFuture(error)
                    }
                }

                func didFinishRequest(task: HTTPClient.Task<Void>) throws -> Void {
                    try self.handle?.close()
                }
            }

            let delegate = Delegate(destinationURL: destinationURL, total: total, progress: progress)
            _ = try await httpClient.execute(request: request, delegate: delegate).get()
        }
    }
}
