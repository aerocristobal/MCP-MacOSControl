// STORY-037 — oscal-drift CLI.
//
// Bidirectional drift detector across the three OSCAL artifacts:
//   1. SECURITY.md §7/§8 ↔ oscal/component-definition.json   (STORY-022)
//   2. SECURITY.md §4    ↔ oscal/plan-of-action-and-milestones.json (this story)
//
// One CLI, two subcommands, so CI can call it once per PR and surface
// failures with a consistent format. The component-definition drift
// check is delegated to OscalCoverageChecker (STORY-022); the POA&M
// drift check uses PoamCoverageChecker (this story).
//
// Subcommands:
//   check                 Run both drift checks, exit non-zero on any failure.
//   check-section4-poam   Only the §4 ↔ POA&M coverage check.
//   check-controls        Only the §7/§8 ↔ component-definition check.
//
// Exit codes:
//   0   no drift
//   1   drift detected (failure messages printed to stderr)
//   2   usage error
//   3   could not read a referenced file

import Foundation
import OSCALComplianceSupport

struct DriftPaths {
    var securityMd: String
    var componentDefinition: String
    var poam: String
}

func defaultPaths() -> DriftPaths {
    DriftPaths(
        securityMd: "docs/SECURITY.md",
        componentDefinition: "oscal/component-definition.json",
        poam: "oscal/plan-of-action-and-milestones.json"
    )
}

func parsePaths(from argv: [String], starting i: Int) -> DriftPaths {
    var paths = defaultPaths()
    var idx = i
    while idx < argv.count {
        let arg = argv[idx]
        switch arg {
        case "--security-md":
            idx += 1
            if idx < argv.count { paths.securityMd = argv[idx] }
        case "--component-definition":
            idx += 1
            if idx < argv.count { paths.componentDefinition = argv[idx] }
        case "--poam":
            idx += 1
            if idx < argv.count { paths.poam = argv[idx] }
        default:
            break
        }
        idx += 1
    }
    return paths
}

func usage() {
    let msg = """
    Usage: oscal-drift <command> [--security-md PATH] [--component-definition PATH] [--poam PATH]

    Commands:
      check                  Run all drift checks (controls + POA&M).
      check-controls         SECURITY.md §7/§8 ↔ component-definition.json (STORY-022).
      check-section4-poam    SECURITY.md §4 ↔ plan-of-action-and-milestones.json (STORY-037).

    Default paths:
      --security-md           docs/SECURITY.md
      --component-definition  oscal/component-definition.json
      --poam                  oscal/plan-of-action-and-milestones.json

    Exit codes: 0 ok, 1 drift, 2 usage, 3 unreadable file.
    """
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
}

// MARK: - Section-4 ↔ POA&M check

func checkSection4Poam(paths: DriftPaths) -> Int32 {
    let report: PoamCoverageReport
    do {
        report = try PoamCoverageChecker().report(securityMdPath: paths.securityMd, poamPath: paths.poam)
    } catch {
        FileHandle.standardError.write("oscal-drift: \(error)\n".data(using: .utf8)!)
        return 3
    }
    var failed = false
    if !report.missingSections.isEmpty {
        failed = true
        let sorted = report.missingSections.sorted()
        FileHandle.standardError.write(
            "oscal-drift: section4_poam_drift — SECURITY.md §4 statements WITHOUT a matching open POA&M item: \(sorted.joined(separator: ", "))\n"
                .data(using: .utf8)!)
    }
    if !report.extraSections.isEmpty {
        failed = true
        let sorted = report.extraSections.sorted()
        FileHandle.standardError.write(
            "oscal-drift: section4_poam_drift — POA&M items reference SECURITY.md §4 subsections that no longer exist: \(sorted.joined(separator: ", "))\n"
                .data(using: .utf8)!)
    }
    if !report.openRisksForClosedSections.isEmpty {
        failed = true
        FileHandle.standardError.write(
            "oscal-drift: section4_poam_drift — risks still open-like after their §4 statement was removed: \(report.openRisksForClosedSections.joined(separator: ", "))\n"
                .data(using: .utf8)!)
    }
    if !report.closedRisksLackingEvidence.isEmpty {
        failed = true
        FileHandle.standardError.write(
            "oscal-drift: section4_poam_drift — risks with status=closed but no closure evidence in risk-log (need story or commit reference): \(report.closedRisksLackingEvidence.joined(separator: ", "))\n"
                .data(using: .utf8)!)
    }
    if !failed {
        print("oscal-drift: section4_poam ok  covered=\(report.coveredSections.count)  accepted=\(report.acceptedSections.count)")
    }
    return failed ? 1 : 0
}

// MARK: - Controls check (STORY-022 delegated)

func checkControls(paths: DriftPaths) -> Int32 {
    let checker = OscalCoverageChecker(
        componentDefinitionPath: paths.componentDefinition,
        securityMdPath: paths.securityMd
    )
    let r: OscalCoverageReport
    do {
        r = try checker.report()
    } catch {
        FileHandle.standardError.write("oscal-drift: \(error)\n".data(using: .utf8)!)
        return 3
    }
    var failed = false
    if !r.missingControls.isEmpty {
        failed = true
        FileHandle.standardError.write(
            "oscal-drift: control_mapping_drift — claimed in SECURITY.md but absent from OSCAL: \(r.missingControls.sorted().joined(separator: ", "))\n"
                .data(using: .utf8)!)
    }
    if !r.extraControls.isEmpty {
        failed = true
        FileHandle.standardError.write(
            "oscal-drift: control_mapping_drift — implemented in OSCAL but not referenced by SECURITY.md: \(r.extraControls.sorted().joined(separator: ", "))\n"
                .data(using: .utf8)!)
    }
    if !failed {
        print("oscal-drift: control_mapping ok  controls=\(r.implementedControls.count)")
    }
    return failed ? 1 : 0
}

// MARK: - Entry

let args = CommandLine.arguments
guard args.count >= 2 else {
    usage()
    exit(2)
}

let command = args[1]
let paths = parsePaths(from: args, starting: 2)

switch command {
case "check":
    let a = checkControls(paths: paths)
    let b = checkSection4Poam(paths: paths)
    exit(a == 0 && b == 0 ? 0 : 1)
case "check-controls":
    exit(checkControls(paths: paths))
case "check-section4-poam":
    exit(checkSection4Poam(paths: paths))
case "-h", "--help":
    usage()
    exit(0)
default:
    usage()
    exit(2)
}
