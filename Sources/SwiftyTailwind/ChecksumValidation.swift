import Foundation
import TSCBasic

protocol ChecksumValidating {
    func generateChecksumFrom(_ filePath: AbsolutePath) throws -> String
    func compareChecksum(from filePath: AbsolutePath, to checksum: String) throws -> Bool
}

struct ChecksumValidation: ChecksumValidating {
    func generateChecksumFrom(_ filePath: AbsolutePath) throws -> String {
        let checksumGenerationTask = Process()
#if os(Linux)
        checksumGenerationTask.launchPath = "/usr/bin/sha256sum"
        checksumGenerationTask.arguments = [filePath.pathString]
#else
        checksumGenerationTask.launchPath = "/usr/bin/shasum"
        checksumGenerationTask.arguments = ["-a", "256", filePath.pathString]
#endif
        
        let pipe = Pipe()
        checksumGenerationTask.standardOutput = pipe
        checksumGenerationTask.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: String.Encoding.utf8) else {
            throw DownloaderError.errorReadingFilesForChecksumValidation
        }
        let checksum = output.split(separator: " ").first.map(String.init) ?? ""
        guard !checksum.isEmpty else {
            throw DownloaderError.errorReadingFilesForChecksumValidation
        }
        return checksum
    }
    
    func compareChecksum(from filePath: AbsolutePath, to checksum: String) throws -> Bool {
        let checksumString = try String(contentsOf: filePath.asURL)
        return checksumString
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .contains { $0.hasPrefix(checksum) }
    }
}
