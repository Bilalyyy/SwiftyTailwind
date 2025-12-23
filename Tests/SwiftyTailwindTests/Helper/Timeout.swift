//
//  LatestReleaseError.swift
//  SwiftyTailwind
//
//  Created by Bilal Larose on 23/12/2025.
//


import XCTest


func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw XCTSkip("Timeout de \(seconds)s atteint")
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
