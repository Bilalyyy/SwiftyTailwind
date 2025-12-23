//
//  MockNetworkClient.swift
//  SwiftyTailwind
//
//  Created by Bilal Larose on 23/12/2025.
//


import Foundation
@testable import SwiftyTailwind

final class MockNetworkClient: NetworkClient {
    // Configure fake latest tag and fake file contents
    var latestTag: String = "\"v3.4.0\"" // minimal JSON with tag_name
    var binaryData: Data = Data([0x00, 0x01, 0x02, 0x03])

    func get(url: String, headers: [(String, String)]?, timeoutSeconds: Int) async throws -> Data {
        // Return a minimal JSON payload expected by Downloader.latestVersion()
        let json: [String: Any] = ["tag_name": "v3.4.0"]
        return try JSONSerialization.data(withJSONObject: json)
    }

    func download(url: String, to destinationPath: String, progress: @escaping (_ receivedBytes: Int64, _ totalBytes: Int64?) -> Void) async throws {
        // Simulate progress and write deterministic bytes to destination
        progress(Int64(binaryData.count), Int64(binaryData.count))
        try binaryData.write(to: URL(fileURLWithPath: destinationPath))
    }
}
