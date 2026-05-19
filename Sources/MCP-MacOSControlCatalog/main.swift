// STORY-020 — App Compatibility Catalog CLI
// Tiny argv parser + dispatcher into `CatalogGeneratorCLI.run`. All logic lives
// in the library so unit tests can drive it without spawning a subprocess.

import Foundation
import MacOSControlLib

func usage() -> Never {
    let exe = (CommandLine.arguments.first as NSString?)?.lastPathComponent ?? "mcp-macos-control-catalog"
    FileHandle.standardError.write(Data("""
    usage: \(exe) --observations <path> --registry <path> --output <path>

      --observations  Path to the canonical observations JSON.
                      Format: array of objects with keys bundle_identifier,
                      interaction_method, macOS_version, timestamp, scenario_name
                      (see docs/compatibility-observations-schema.md).
      --registry      Path to default-app-capabilities.json (or a compatible override).
      --output        Path to write the generated Markdown.

    Exit codes:
      0   success (no discrepancies, or only single-run discrepancies)
      2   persistent discrepancies (3+ consecutive runs disagree with the registry)
      64  usage error
      65  data error (could not read inputs or write output)

    """.utf8))
    exit(CatalogGeneratorCLI.ExitCode.usage)
}

func resolveURL(_ raw: String) -> URL {
    let expanded = (raw as NSString).expandingTildeInPath
    if (expanded as NSString).isAbsolutePath {
        return URL(fileURLWithPath: expanded)
    }
    let cwd = FileManager.default.currentDirectoryPath
    return URL(fileURLWithPath: cwd).appendingPathComponent(expanded)
}

var observationsPath: URL?
var registryPath: URL?
var outputPath: URL?

var args = Array(CommandLine.arguments.dropFirst())
while !args.isEmpty {
    let flag = args.removeFirst()
    switch flag {
    case "--observations":
        guard !args.isEmpty else { usage() }
        observationsPath = resolveURL(args.removeFirst())
    case "--registry":
        guard !args.isEmpty else { usage() }
        registryPath = resolveURL(args.removeFirst())
    case "--output":
        guard !args.isEmpty else { usage() }
        outputPath = resolveURL(args.removeFirst())
    case "-h", "--help":
        usage()
    default:
        FileHandle.standardError.write(Data("unknown argument: \(flag)\n".utf8))
        usage()
    }
}

guard let observationsPath, let registryPath, let outputPath else {
    usage()
}

let exit_code = await CatalogGeneratorCLI.run(
    observationsPath: observationsPath,
    registryPath: registryPath,
    outputPath: outputPath
)
exit(exit_code)
