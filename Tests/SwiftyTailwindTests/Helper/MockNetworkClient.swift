//
//  MockNetworkClient.swift
//  SwiftyTailwind
//
//  Created by Bilal Larose on 23/12/2025.
//


import Foundation
@testable import SwiftyTailwind

enum MockNetworkClientError: Error {
    case requestFailed
}

final class MockNetworkClient: NetworkClient {
    // Configure fake latest tag and fake file contents
    var latestTag: String = "v3.4.0"
    var binaryData: Data = Data([0x00, 0x01, 0x02, 0x03])
    var shouldFailGet: Bool = false
    var shouldFailDownload: Bool = false
    var requestedURLs: [String] = []

    func get(url: String, headers: [(String, String)]?, timeoutSeconds: Int) async throws -> Data {
        if shouldFailGet {
            throw MockNetworkClientError.requestFailed
        }

        // Return a minimal JSON payload expected by Downloader.latestVersion()
        let json: [String: Any] = ["tag_name": latestTag]
        return try JSONSerialization.data(withJSONObject: json)
    }

    func download(url: String, to destinationPath: String, progress: @escaping (_ receivedBytes: Int64, _ totalBytes: Int64?) -> Void) async throws {
        requestedURLs.append(url)
        if shouldFailDownload {
            throw MockNetworkClientError.requestFailed
        }

        // Simulate progress and write deterministic bytes to destination
        if url.hasSuffix(Downloader.sha256FileName) {
            let checksumData = Data("054edec1d0211f624fed0cbca9d4f9400b0e491c43742af2c5b0abebf0c990d8  tailwindcss\n".utf8)
            progress(Int64(checksumData.count), Int64(checksumData.count))
            try checksumData.write(to: URL(fileURLWithPath: destinationPath))
        } else {
            progress(Int64(binaryData.count), Int64(binaryData.count))
            try binaryData.write(to: URL(fileURLWithPath: destinationPath))
        }
    }
}
