import TSCBasic
import Logging


/// This class is the main interface to download and run [Tailwind](https://tailwindcss.com) from a Swift project.
/// Every function of the interface we'll lazily download a portable Tailwind executable,
/// which includes the [NodeJS](https://nodejs.org/en) runtime, and invoke it using system processes.
public class SwiftyTailwind {
    private let version: TailwindVersion
    private let directory: AbsolutePath
    private let downloader: Downloading
    private let executor: Executing
    private let logger: Logger

    /// Default initializer.
    /// - Parameters:
    /// - version: The version of Tailwind to use. You can specify a fixed version or use the latest one.
    /// - directory: The directory where the executables will be downloaded.
    /// When not provided, it defaults to the system's default temporary directory.
    public convenience init(version: TailwindVersion = .latest, directory: AbsolutePath) {
        self.init(version: version, directory: directory, downloader: Downloader(), executor: Executor())
    }

     /// Default initializer.
     /// - Parameters:
     /// - version: The version of Tailwind to use. You can specify a fixed version or use the latest one.
    public convenience init(version: TailwindVersion = .latest) {
        self.init(version: version, directory: Downloader.defaultDownloadDirectory(), downloader: Downloader(), executor: Executor())
    }

    init(version: TailwindVersion,
         directory: AbsolutePath,
         downloader: Downloading,
         executor: Executing) {
        self.version = version
        self.directory = directory
        self.downloader = downloader
        self.executor = executor
        self.logger = Logger(label: "io.tuist.SwiftyTailwind")
    }

    @available(*, deprecated, message: "Tailwind v4 no longer supports `tailwindcss init`. This method is deprecated and will be removed in a future release. Create your config manually or via your own template.")
    public func initialize(directory: AbsolutePath = localFileSystem.currentWorkingDirectory!,
                           options: InitializeOption...) async throws {
        // Deprecated in Tailwind v4: the CLI no longer supports `init`.
        struct InitializationDeprecatedError: Error, CustomStringConvertible {
            var description: String {
                "SwiftyTailwind.initialize is deprecated: Tailwind v4 removed the `init` command. Create your config manually."
            }
        }
        throw InitializationDeprecatedError()
    }

    /// It runs the main Tailwind command.
    /// - Parameters:
    /// - directory: The directory from where to run the command. When not passed, it defaults to the working directory from where the process is running.
    /// - options: A set of ``SwiftyTailwind.RunOption`` options to customize the execution.
    public func run(input: AbsolutePath,
                    output: AbsolutePath,
                    directory: AbsolutePath = localFileSystem.currentWorkingDirectory!,
                    options: RunOption...) async throws {
        logger.info("Preparing to run Tailwind CLI.")
        var arguments: [String] = [
            "--input", input.pathString,
            "--output", output.pathString
        ]
        arguments.append(contentsOf: options.executableFlags)
        if (!options.contains(.autoPrefixer)) { arguments.append("--no-autoprefixer")}
        logger.info("Resolving Tailwind CLI binary (this may take a moment on first run)...")
        let executablePath = try await download()
        logger.info("Using Tailwind CLI at \(executablePath.pathString)")
        try await executor.run(executablePath: executablePath, directory: directory, arguments: arguments)
        logger.info("Tailwind CLI finished successfully.")
    }
    /// Downloads the Tailwind portable executable
    private func download() async throws -> AbsolutePath {
        try await downloader.download(version: version, directory: directory, numRetries: 0)
    }

    private func shouldFallbackInit(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("invalid command: init")
            || message.contains("unknown command: init")
            || message.contains("unknown command \"init\"")
    }

    private func writeConfigFiles(directory: AbsolutePath, options: [InitializeOption]) throws {
        let configPath = directory.appending(component: configFileName(options: options))
        if !localFileSystem.exists(configPath) {
            let contents = configFileContents(options: options)
            try localFileSystem.writeFileContents(configPath, bytes: ByteString(contents.utf8))
        }

        if options.contains(.postcss) {
            let postcssPath = directory.appending(component: "postcss.config.js")
            if !localFileSystem.exists(postcssPath) {
                let contents = """
                module.exports = {
                  plugins: {
                    tailwindcss: {},
                    autoprefixer: {},
                  },
                }
                """
                try localFileSystem.writeFileContents(postcssPath, bytes: ByteString(contents.utf8))
            }
        }
    }

    private func configFileName(options: [InitializeOption]) -> String {
        if options.contains(.ts) {
            return "tailwind.config.ts"
        }
        return "tailwind.config.js"
    }

    private func configFileContents(options: [InitializeOption]) -> String {
        if options.contains(.ts) {
            return """
            import type { Config } from "tailwindcss"

            export default {
              content: [],
              theme: {
                extend: {},
              },
              plugins: [],
            } satisfies Config
            """
        }

        let exportLine = options.contains(.esm) ? "export default" : "module.exports ="
        return """
        \(exportLine) {
          content: [],
          theme: {
            extend: {},
          },
          plugins: [],
        }
        """
    }
}

extension Array where Element == SwiftyTailwind.InitializeOption {
    /// Returns the flags to pass to the Tailwind CLI when invoking the `init` command.
    var executableFlags: [String] {
        return self.map(\.flag)
    }
}

extension Array where Element == SwiftyTailwind.RunOption {
    /// Returns the flags to pass to the Tailwind CLI when invoking the `init` command.
    var executableFlags: [String] {
        return self.map(\.flag).flatMap({$0})
    }
}

public extension SwiftyTailwind {
    enum InitializeOption: Hashable {
        /// Initializes configuration file as ESM. When passed, it passes the `--esm` flag to the `init` command.
        case esm
        /// Initializes configuration file as Typescript. When passed, it passes the `--ts` flag to the `init` command.
        case ts
        /// Initializes a `postcss.config.js` file. When passed, it passes the `--postcss` flag to the `init` command.
        case postcss
        /// Includes the default values for all options in the generated configuration file.
        /// When passed, it passes the `--full` flag to the `init` command.
        case full
        /// The CLI flag that represents the option.
        var flag: String {
            switch self {
            case .esm: return "--esm"
            case .ts: return "--ts"
            case .postcss: return "--postcss"
            case .full: return "--full"
            }
        }
    }

    // An enum that captures all the options that that you can pass to the Tailwind executable.
    enum RunOption: Hashable {
        /// Keeps the process running watching for file changes. When passed, it passes the `--watch` argument to the Tailwind executable.
        case watch
        /// It uses polling to watch file changes. When passed, it passes the `--poll` argument to the Tailwind executable.
        case poll
        /// It enables [auto-prefixer](https://github.com/postcss/autoprefixer). When passed, it doesn't pass the `--no-autoprefixer` variable.
        case autoPrefixer
        ///It  minifies the generated output CSS. When passed, it passes the `--minify` argument to the Tailwind executable.
        case minify
        ///It uses a configuration other than the one in the current working directory. When passed, it passes the `--config` argument to the Tailwind executable.
        case config(AbsolutePath)
        ///It runs PostCSS using the configuration file at the given path. When passed, it passes the `--postcss` argument to the Tailwind executable.
        case postcss(AbsolutePath)
        ///It specifies a [glob](https://en.wikipedia.org/wiki/Glob_(programming))
        ///pattern that the Tailwind executable uses to to tree-shake the output CSS
        /// eliminating the Tailwind classes that are not used.
        /// When passed, it passes the `--content` argument to the Tailwind executable.
        case content(String)
        ///The CLI flag that represents the option.
        var flag: [String] {
            switch self {
            case .watch:
                return ["--watch"]
            case .poll:
                return ["--poll"]
            case .autoPrefixer:
                return []
            case .minify:
                return ["--minify"]
            case .config(let path):
                return ["--config", path.pathString]
            case .postcss(let path):
                return ["--postcss", path.pathString]
            case .content(let content):
                return ["--content", content]
            }
        }
    }
}
