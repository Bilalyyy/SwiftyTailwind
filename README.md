# SwiftyTailwind 🍃

**SwiftyTailwind** is a Swift package that allows you to download and run the
[Tailwind CSS](https://tailwindcss.com) CLI directly from a Swift project.

It is commonly used with server-side Swift frameworks such as
[Vapor](https://vapor.codes) to generate and watch Tailwind CSS styles during development.

This repository is a maintained fork adapted for modern Vapor workflows.

---

## Usage

Add `SwiftyTailwind` as a dependency in your project's `Package.swift`:

```swift
.package(url: "https://github.com/Bilalyyy/SwiftyTailwind.git", from: "0.5.0")
```

Then create an instance of SwiftyTailwind:

```swift
let tailwind = SwiftyTailwind(version: .latest, directory: "./cache")
```

If you don't pass any argument, it defaults to the latest version in the system's default temporary directory. If you work in a team, we recommend fixing the version to minimize non-determinism across environments.

### Initializing a `tailwind.config.js`

You can create a `tailwind.config.js` configuration file by running the [`initialize`](https://swiftytailwind.tuist.io/documentation/swiftytailwind/swiftytailwind/initialize(directory:options:)) function on the `SwiftyTailwind` instance:


```swift
try await tailwind.initialize()
```

Check out all the available options in [the documentation](https://swiftytailwind.tuist.io/documentation/swiftytailwind/swiftytailwind/initializeoption).

### Running Tailwind

To run Tailwind against a project, you can use the [`run`](https://swiftytailwind.tuist.io/documentation/swiftytailwind/swiftytailwind/run(input:output:directory:options:)) function:

```swift
try await subject.run(input: inputCSSPath, output: outputCSSPath, options: .content("views/**/*.html"))
```

If you'd like Tailwind to keep watching for file changes, you can pass the `.watch` option:


```swift
try await subject.run(input: inputCSSPath, 
                      output: outputCSSPath, 
                      options: .watch, .content("views/**/*.html"))
```

Check out all the available options in the [documentation](https://swiftytailwind.tuist.io/documentation/swiftytailwind/swiftytailwind/runoption).

### Integrating with Vapor

You can integrate this with Vapor by setting up a `tailwind.swift`:

```swift
import SwiftyTailwind
import TSCBasic
import Vapor

func tailwind(_ app: Application) async throws {
  let resourcesDirectory = try AbsolutePath(validating: app.directory.resourcesDirectory)
  let publicDirectory = try AbsolutePath(validating: app.directory.publicDirectory)

  let tailwind = SwiftyTailwind()
  try await tailwind.run(
    input: .init(validating: "Styles/app.css", relativeTo: resourcesDirectory),
    output: .init(validating: "styles/app.generated.css", relativeTo: publicDirectory),
    options: .content("\(app.directory.viewsDirectory)**/*.leaf")
  )
}
```

Then in `configure.swift`:

```swift
try await tailwind(app)
app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
```

And in your `index.leaf`:

```html
<link rel="stylesheet" href="/styles/app.generated.css" />
```
### Running Vapor and Tailwind watch in parallel

It can be desirable for Tailwind to watch and rebuild changes without restarting the Vapor server.
It is also best to restrict this behavior for development only.

You can integrate this behavior by setting up a `tailwind.swift`:

```swift
#if DEBUG
import SwiftyTailwind
import TSCBasic
import Vapor

func runTailwind(_ app: Application) async throws {
    let resourcesDirectory = try AbsolutePath(validating: app.directory.resourcesDirectory)
    let publicDirectory = try AbsolutePath(validating: app.directory.publicDirectory)
    let tailwind = SwiftyTailwind()
    
    async let runTailwind: () = tailwind.run(
        input: .init(validating: "Styles/app.css", relativeTo: resourcesDirectory),
        output: .init(validating: "styles/app.generated.css", relativeTo: publicDirectory),
        options: .watch, .content("\(app.directory.viewsDirectory)**/*.leaf"))
    return try await runTailwind
}
#endif
```

and then in `entrypoint.swift`, replace `try await app.execute()` with:

```swift
#if DEBUG
        if (env.arguments.contains { arg in arg == "migrate" }) {
            try await app.execute()
        } else {
            async let runApp: () = try await app.execute()
            _ = await [try runTailwind(app), try await runApp]
        }
#else
        try await app.execute()
#endif
```

The check for `migrate` in the arguments will ensure that it doesn't run when doing migrations in development.
Additionally, it may be a good idea to setup a script to minify the CSS before deploying to production.

## Credits

This project is based on the original [SwiftyTailwind](https://vapor.codes](https://github.com/tuist/SwiftyTailwind)) package by Tuist
and its contributors.

This fork exists to maintain and adapt the package for modern Vapor
projects.
