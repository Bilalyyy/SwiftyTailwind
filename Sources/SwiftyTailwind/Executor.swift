import Foundation
import TSCBasic
import Logging


/// Executing describes the interface to run system processes.
/// Executors are used by `SwiftyTailwind` to run the Tailwind executable using system processes.
protocol Executing {
    /// Runs a system process using the given executable path and arguments.
    /// - Parameters:
    /// - executablePath: The absolute path to the executable to run.
    /// - directory: The working directory from to run the executable.
    /// - arguments: The arguments to pass to the executable.
    func run(executablePath: AbsolutePath,
             directory: AbsolutePath,
             arguments: [String]) async throws
}

final class Executor: Executing, @unchecked Sendable {
    
    let logger: Logger
    
    ///Creates a new instance of `Executor`
    init() {
        self.logger = Logger(label: "com.app-soon.SwiftyTailwind.Executor")
    }

    func run(executablePath: TSCBasic.AbsolutePath, directory: AbsolutePath, arguments: [String]) async throws {
        return try await withCheckedThrowingContinuation({ continuation in
            // Capture needed values by value to satisfy @Sendable closure requirements
            let logger = self.logger
            let execPathString = executablePath.pathString
            let workingDir = directory
            let passedArguments = arguments

            DispatchQueue.global(qos: .userInitiated).async { [logger, execPathString, workingDir, passedArguments] in
                let fullArguments = [execPathString] + passedArguments
                logger.info("Working directory: \(workingDir.pathString)")
                logger.info("Executing: \(fullArguments.joined(separator: " "))")

                var capturedStdout = Data()
                var capturedStderr = Data()

                let process = Process(arguments: fullArguments,
                                      workingDirectory: workingDir,
                                      outputRedirection: .stream(
                                        stdout: { output in
                                            capturedStdout.append(contentsOf: output)
                                            if let outputString = String(bytes: output, encoding: .utf8), !outputString.isEmpty {
                                                logger.info("\(outputString)")
                                            }
                                        },
                                        stderr: { error in
                                            capturedStderr.append(contentsOf: error)
                                            if let errorString = String(bytes: error, encoding: .utf8), !errorString.isEmpty {
                                                // We don't use `logger.error` here because some useful warnings are sent through the standard error.
                                                logger.info("\(errorString)")
                                            }
                                        }
                                      ), startNewProcessGroup: false)
                do {
                    try process.launch()
                    let status = try process.waitUntilExit().exitStatus

                    switch status {
                    case .terminated(code: 0):
                        continuation.resume()
                    default:
                        let stdoutString = String(data: capturedStdout, encoding: .utf8) ?? ""
                        let stderrString = String(data: capturedStderr, encoding: .utf8) ?? ""
                        let message = "Process exited with status: \(status).\nSTDOUT:\n\(stdoutString)\nSTDERR:\n\(stderrString)"
                        continuation.resume(throwing: NSError(domain: "com.app-soon.SwiftyTailwind.Executor", code: 1, userInfo: [NSLocalizedDescriptionKey: message]))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        })
    }
}

