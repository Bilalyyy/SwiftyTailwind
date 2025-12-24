import XCTest
import TSCBasic
@testable import SwiftyTailwind

final class SwiftyTailwindTests: XCTestCase {
    // TODO: These tests failed

    func test_run() async throws {
        try await withTemporaryDirectory(removeTreeOnDeinit: true, { tmpDir in
            // Given
            let subject = SwiftyTailwind(directory: tmpDir)

            let inputCSSPath = tmpDir.appending(component: "input.css")
            let inputCSSContent = """
            @tailwind utilities;
            """
            let outputCSSPath = tmpDir.appending(component: "output.css")
            let contentPath = tmpDir.appending(component: "index.html")
            let contentHTML = """
            <p class="font-bold">Hello</p>
            """

            try localFileSystem.writeFileContents(inputCSSPath, bytes: ByteString(inputCSSContent.utf8))
            try localFileSystem.writeFileContents(contentPath, bytes: ByteString(contentHTML.utf8))

            // When
            try await subject.run(input: inputCSSPath,
                                  output: outputCSSPath,
                                  directory: tmpDir,
                                  options: .content(contentPath.pathString))

            // Then
            let content = String(bytes: try localFileSystem.readFileContents(outputCSSPath).contents, encoding: .utf8)
            XCTAssertTrue(localFileSystem.exists(outputCSSPath))
            XCTAssertTrue(content?.contains(".font-bold") != nil)
            XCTAssertTrue(content?.contains("font-weight: 700") != nil)
        })
    }
}
