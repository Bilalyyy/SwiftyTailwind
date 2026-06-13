import Foundation
import XCTest
import TSCBasic
import AsyncHTTPClient
@testable import SwiftyTailwind


final class DownloaderTests: XCTestCase {
    var subject: Downloader!
    var network: MockNetworkClient!
    
    override func setUp() {
        super.setUp()
        let mock = MockNetworkClient()
        self.network = mock
        subject = Downloader(network: mock)
    }
    
    override func tearDown() {
        subject = nil
        network = nil
        super.tearDown()
    }
    
    func test_download() async throws {
        _ = try await withTemporaryDirectory { tmpDirectory in
            let path = try await self.subject.download(version: .latest, directory: tmpDirectory)
            XCTAssertTrue(localFileSystem.exists(path))
        }
    }

    func test_download_latestFallsBackToCachedBinaryWhenLatestReleaseRequestFails() async throws {
        _ = try await withTemporaryDirectory { tmpDirectory in
            let cachedBinary = try self.createCachedBinary(version: "v3.3.0", in: tmpDirectory)
            self.network.shouldFailGet = true

            let path = try await self.subject.download(version: .latest, directory: tmpDirectory)

            XCTAssertEqual(path.pathString, cachedBinary.pathString)
        }
    }

    func test_download_latestFallsBackToCachedBinaryWhenLatestDownloadFails() async throws {
        _ = try await withTemporaryDirectory { tmpDirectory in
            let cachedBinary = try self.createCachedBinary(version: "v3.3.0", in: tmpDirectory)
            self.network.latestTag = "v3.4.0"
            self.network.shouldFailDownload = true

            let path = try await self.subject.download(version: .latest, directory: tmpDirectory)

            XCTAssertEqual(path.pathString, cachedBinary.pathString)
        }
    }

    func test_download_fixedVersionDoesNotFallBackToCachedBinary() async throws {
        _ = try await withTemporaryDirectory { tmpDirectory in
            try self.createCachedBinary(version: "v3.3.0", in: tmpDirectory)
            self.network.shouldFailDownload = true

            do {
                _ = try await self.subject.download(version: .fixed("v3.4.0"), directory: tmpDirectory)
                XCTFail("Expected fixed version download to fail instead of falling back to another version.")
            } catch MockNetworkClientError.requestFailed {
                XCTAssertTrue(true)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // Note: This integration test uses real network calls and should be updated
    // if you want to inject a real network client instead of using mock.
    func test_download_integration() async throws {
        // Activez ce test en définissant SWIFTYTAILWIND_INTEGRATION=1 dans l’environnement
        let shouldRun = ProcessInfo.processInfo.environment["SWIFTYTAILWIND_INTEGRATION"] == "1"
        try XCTSkipUnless(shouldRun, "Test d’intégration réseau désactivé par défaut. Définissez SWIFTYTAILWIND_INTEGRATION=1 pour l’exécuter.")

        // Timeout global pour éviter les exécutions trop longues
        let timeout: TimeInterval = 90

        do {
            _ = try await withTimeout(seconds: timeout) {
                try await withTemporaryDirectory { tmpDirectory in
                    print("[DownloaderTests] Démarrage du téléchargement dans: \(tmpDirectory.pathString)")
                    let path = try await self.subject.download(version: .latest, directory: tmpDirectory)
                    print("[DownloaderTests] Téléchargement terminé. Binaire: \(path.pathString)")
                    XCTAssertTrue(localFileSystem.exists(path), "Le binaire téléchargé devrait exister sur le disque.")
                }
            }
        } catch {
            // Ajoute du contexte utile si ça échoue
            XCTFail("Échec du test d’intégration de téléchargement: \(error.localizedDescription)\n\(String(describing: error))")
        }
    }

    @discardableResult
    private func createCachedBinary(version: String, in directory: AbsolutePath) throws -> AbsolutePath {
        guard let binaryName = cachedBinaryName() else {
            throw DownloaderError.unableToDetermineBinaryName
        }

        let versionDirectory = directory.appending(component: version)
        try localFileSystem.createDirectory(versionDirectory, recursive: true)
        let binaryPath = versionDirectory.appending(component: binaryName)
        try localFileSystem.writeFileContents(binaryPath, bytes: ByteString([0x00, 0x01, 0x02, 0x03]))
        try localFileSystem.chmod(.executable, path: binaryPath)
        return binaryPath
    }

    private func cachedBinaryName() -> String? {
        guard let architecture = ArchitectureDetector().architecture()?.tailwindValue else {
            return nil
        }

        #if os(Windows)
        return "tailwindcss-windows-\(architecture).exe"
        #elseif os(Linux)
        return "tailwindcss-linux-\(architecture)"
        #else
        return "tailwindcss-macos-\(architecture)"
        #endif
    }
}
