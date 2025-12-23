import Foundation
import XCTest
import TSCBasic
import AsyncHTTPClient
@testable import SwiftyTailwind


final class DownloaderTests: XCTestCase {
    var subject: Downloader!
    var network: NetworkClient!
    
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
}

