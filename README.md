# MCP macOS Control

A native macOS MCP (Model Context Protocol) server built in Swift that provides **74 tools** for comprehensive computer control — mouse, keyboard, screen capture, OCR, window management, Vision analysis, CoreML intelligence, accessibility tree reading, event-driven UI waiting via AXObserver, application lifecycle event waiting via NSWorkspace, and **iPhone Mirroring automation** via macOS Sequoia.

[![CI](https://github.com/aerocristobal/MCP-MacOSControl/actions/workflows/ci.yml/badge.svg)](https://github.com/aerocristobal/MCP-MacOSControl/actions/workflows/ci.yml)

## Overview

MCP macOS Control enables AI agents to perceive and interact with macOS applications and, through iPhone Mirroring, iOS apps on a connected iPhone. All processing happens on-device using native Apple frameworks.

**Key capabilities:**
- Full mouse and keyboard automation via CoreGraphics events
- Screen capture with OCR text extraction (Vision framework)
- iPhone Mirroring control with normalized coordinates (macOS 15+)
- Accessibility tree reading via AXUIElement API
- On-device CoreML LLM inference (zero cloud tokens)
- Real-time screen monitoring with continuous capture
- Multi-display support
- Rate limiting, structured logging, and CI/CD

## Requirements

- macOS 13.0 (Ventura) or later (macOS 15 for iPhone Mirroring)
- Apple Silicon or Intel Mac (Apple Silicon recommended)
- Swift 5.9+ / Xcode 16+
- MCP SDK 0.12.0+

## Installation

```bash
git clone https://github.com/aerocristobal/MCP-MacOSControl.git
cd MCP-MacOSControl
swift build -c release
```

The executable is at `.build/release/mcp-macos-control`.

### Claude Desktop Configuration

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "macos-control": {
      "command": "/path/to/MCP-MacOSControl/.build/release/mcp-macos-control"
    }
  }
}
```

## Permissions

macOS requires explicit permissions:

1. **Accessibility** (System Settings > Privacy & Security > Accessibility) -- required for mouse, keyboard, window activation, and accessibility tree
2. **Screen Recording** (System Settings > Privacy & Security > Screen Recording) -- required for screenshots, OCR, and continuous capture

See [docs/PERMISSIONS.md](docs/PERMISSIONS.md) for detailed setup.

## Security

The threat model, AppleScript denylist, audit-record schema, and NIST SP 800-53 control mapping live in [docs/SECURITY.md](docs/SECURITY.md). Vulnerabilities should be reported via a private GitHub Security Advisory — see §6 of that document.

**Supply-chain controls (STORY-021, see §8).** Every push and pull request:

- Generates a CycloneDX 1.5+ SBOM (via Syft) covering every transitive Swift package.
- Runs Grype SBOM scanning + GitHub's native Dependency Review against the SBOM.
- Fails the build on CVSS ≥ 9.0 (Critical) findings; CVSS 7.0–8.9 (High) warns via a PR comment without blocking.
- Enforces a license allow-list: MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC.

Tagged releases attach the SBOM (and a VEX document, when statements exist) to the GitHub Release as evidence artifacts. Dependabot opens monthly Swift-package and weekly GitHub-Actions upgrade PRs against the same gate. Policy is declared in [`.github/sbom-policy.yml`](.github/sbom-policy.yml).

### Compliance Artifacts

Machine-readable compliance posture for downstream SSP authors, assessors, and continuous-monitoring consumers. All three artifacts are versioned in `oscal/` and validated against the NIST OSCAL schemas on every push.

| Artifact | OSCAL model | Purpose |
|----------|-------------|---------|
| [`oscal/component-definition.json`](oscal/component-definition.json) | OSCAL 1.1.2 Component Definition | Mirror of [`docs/SECURITY.md`](docs/SECURITY.md) §7/§8 control implementation, with `rel:implementation` and `rel:verification` links into source and tests. Maintained per STORY-022. |
| [`oscal/plan-of-action-and-milestones.json`](oscal/plan-of-action-and-milestones.json) | OSCAL 1.1.2 POA&M | One open item per accepted-risk statement in `docs/SECURITY.md` §4, plus historical closed items. Each item carries status, owner, related-controls, and milestones. UUID registry: [`oscal/poam-id-allocations.md`](oscal/poam-id-allocations.md). Maintained per STORY-037. |
| [`oscal/assessment-results.json`](oscal/assessment-results.json) | OSCAL 1.1.2 Assessment Results | Continuous-monitoring observations derived from the STORY-024 AuditRecord stream. One observation per AuditRecord. Append-only; nightly emit job amends new observations without rewriting prior ones. AuditRecord ↔ Observation mapping: [`oscal/assessment-results-mapping.md`](oscal/assessment-results-mapping.md). Maintained per STORY-037. |

Drift between `docs/SECURITY.md` and the OSCAL artifacts is enforced bidirectionally by [`swift run oscal-drift check`](Sources/OscalDrift/main.swift) — CI fails on any of: a §7/§8 control claim without an OSCAL `implemented-requirement`, an OSCAL `implemented-requirement` not referenced by §7/§8, a §4 accepted-risk statement without a matching open POA&M item, or a POA&M item whose `security-md-section` no longer exists.

## Tools (75 total, 16 modules)

### Mouse Control (MouseModule -- 9 tools)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `click_screen` | Click at coordinates (left/right/middle) | x, y |
| `double_click` | Double-click at coordinates | x, y |
| `move_mouse` | Move cursor | x, y |
| `mouse_down` | Hold mouse button | -- |
| `mouse_up` | Release mouse button | -- |
| `drag_mouse` | Drag between two points | from_x, from_y, to_x, to_y |
| `scroll` | Scroll in a direction | direction |
| `get_screen_size` | Get screen resolution | -- |
| `list_displays` | List all connected displays | -- |

### Keyboard Control (KeyboardModule -- 4 tools)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `type_text` | Type text at cursor | text |
| `press_keys` | Key combos (e.g., `[["cmd", "c"]]`) | keys |
| `key_down` | Hold a key | key |
| `key_up` | Release a key | key |

### Screen Capture and OCR (ScreenCaptureModule -- 2 tools)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `take_screenshot` | Capture screen or window as PNG | -- |
| `take_screenshot_with_ocr` | Screenshot + text extraction | -- |

### Window Management (WindowModule -- 2 tools)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `list_windows` | List all open windows | -- |
| `activate_window` | Bring window to foreground | title_pattern |

### Continuous Capture (ContinuousCaptureModule -- 6 tools)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `start_continuous_capture` | Start real-time capture | capture_type |
| `stop_continuous_capture` | Stop capture session | -- |
| `get_capture_frame` | Get latest frame | -- |
| `list_capturable_displays` | List available displays | -- |
| `list_capturable_windows` | List capturable windows | -- |
| `list_capturable_applications` | List running apps | -- |

### Vision Analysis (VisionModule -- 5 tools)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `classify_image` | Scene/object classification | image_data |
| `detect_objects` | Object detection with bounding boxes | image_data |
| `detect_rectangles` | Rectangle/UI element detection | image_data |
| `detect_saliency` | Attention region detection | image_data |
| `detect_faces` | Face detection | image_data |

### CoreML Intelligence (CoreMLModule -- 8 tools)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `list_coreml_models` | List available models | -- |
| `load_coreml_model` | Load model for inference | name, path |
| `unload_coreml_model` | Unload model | name |
| `get_model_info` | Model metadata | name |
| `generate_text_llm` | On-device text generation | model_name, prompt |
| `analyze_screen_with_llm` | Screen + Vision + LLM | model_name, instruction |
| `intelligent_screen_summary` | NLP-based screen summary | -- |
| `extract_key_info` | Extract entities from OCR | ocr_results |

### Real-Time Analysis (RealtimeModule -- 4 tools)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `analyze_screen_now` | Quick capture + Vision analysis | -- |
| `start_screen_monitoring` | Continuous analysis | -- |
| `get_monitoring_results` | Latest analysis results | -- |
| `stop_screen_monitoring` | Stop monitoring | -- |

### System (SystemModule -- 3 tools)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `check_permissions` | Check Accessibility and Screen Recording | -- |
| `wait_milliseconds` | Pause execution | milliseconds |
| `wait_for_text` | Poll OCR until text appears | text |

### Accessibility (AccessibilityModule -- 5 tools)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `accessibility_tree` | Read AXUIElement tree of macOS app | -- |
| `click_element` | Click an element by semantic AX attributes | -- |
| `perform_ax_action` | Dispatch any standard AX action (AXPress, AXIncrement, AXShowMenu, etc.) | -- |
| `find_elements` | Find elements matching a semantic predicate | -- |
| `element_at_position` | Resolve the AX element under a screen coordinate | x, y |

Returns structured JSON with role, title, value, position, size, and children for each UI element. Configurable `max_depth` (default 6). Note: works for macOS apps only -- iPhone Mirroring content requires `iphone_screenshot_with_ocr`.

### Event-Driven Waiting (WaitForUIEventModule -- 1 tool)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `wait_for_ui_event` | Subscribe to an `AXObserver` notification and block until it fires | notification, application |

Replaces fixed sleeps and screenshot-polling loops with precise event-driven synchronization. Supported notifications: `AXWindowCreated`, `AXUIElementDestroyed`, `AXFocusedUIElementChanged`, `AXValueChanged`, `AXSelectedTextChanged`, `AXTitleChanged`, `AXMainWindowChanged`, `AXFocusedWindowChanged`. Multiple concurrent calls on the same `(application, notification)` pair share a single underlying `AXObserver`. Default timeout 30s, hard cap 300s. See the `ax_observer_notifications` MCP prompt for routing guidance.

### Element-State Polling (WaitForElementStateModule -- 1 tool)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `wait_for_element_state` | Poll the AX tree until an element matches a state condition | condition, application |

The documented fallback to `wait_for_ui_event` for transitions that have no `AXObserver` notification (a button becoming enabled, a spinner disappearing, a row becoming selected). Condition syntax is `"<field> = <value>"`. Boolean fields: `enabled`, `exists`, `focused`, `selected`, `expanded`, `visible_in_viewport`, `is_main`, `is_minimized`, `is_frontmost` (e.g. `enabled = true`, `exists = false`). String field: `value` (exact, case-sensitive, quoted — e.g. `value = 'Connected'`). Fixed 100ms poll cadence (override with `MCP_MACOS_CONTROL_POLL_INTERVAL_MS`). Default timeout 30s, hard cap 120s — for long event-driven waits prefer `wait_for_ui_event`.

### Application Lifecycle Events (WaitForAppEventModule -- 1 tool)

| Tool | Description | Required Params |
|------|-------------|----------------|
| `wait_for_app_event` | Subscribe to an NSWorkspace application-lifecycle notification and block until it fires | event |

The event-driven way to sequence "open app → app is ready → interact" workflows. Unlike `wait_for_ui_event` (AXObserver, requires an already-running AX-queryable target), this is pre-launch capable and needs no accessibility permission. Supported events: `launched`, `activated`, `terminated`, `deactivated`, `hidden`, `unhidden`. Optional `bundle_identifier` (reverse-DNS, e.g. `com.apple.TextEdit`) filters to one app; omit it to resolve on the next matching event from any application. Resolves only on the *next* transition, never the current state. Multiple concurrent calls on the same `(event, bundle_identifier)` share one underlying observer. Default timeout 30s, hard cap 300s. See the `interaction_hierarchy` MCP prompt for when to prefer it over `wait_for_ui_event`.

### Interaction Router (SmartInteractModule -- 1 tool) — **recommended for AI agents**

| Tool | Description | Required Params |
|------|-------------|----------------|
| `smart_interact` | State an intent (`click`/`type`) and a target; the router auto-selects and falls through AX semantic → AppleScript → hit-test → coordinate layers | intent |

**The recommended entry point for UI interaction.** Instead of choosing between `click_element`, `run_applescript`, `element_at_position`, and `click_screen` yourself, state your *intent* and let the router pick the most reliable available layer. It consults the per-app capability registry to skip layers known to fail for the target app, and returns a `decision_log` documenting every layer attempted, skipped, or failed (with reasons), plus `interaction_method` and `confidence`. On exhaustion it returns the structured error `all_layers_failed` with retry suggestions. The router only knows the action *dispatched*, not its effect — verify after acting with `wait_for_ui_event` / `wait_for_element_state`. See the `interaction_hierarchy` MCP prompt.

### iPhone Mirroring (IPhoneMirroringModule -- 21 tools)

Requires macOS 15 (Sequoia) with iPhone Mirroring configured. All coordinates use normalized 0.0-1.0 range relative to the iPhone screen content area.

| Tool | Description | Required Params |
|------|-------------|----------------|
| `iphone_status` | Check mirroring status and connection | -- |
| `iphone_launch` | Launch/activate iPhone Mirroring | -- |
| `iphone_calibrate` | Force content rect re-calibration | -- |
| `iphone_tap` | Tap at normalized coordinates | x, y |
| `iphone_double_tap` | Double-tap | x, y |
| `iphone_long_press` | Long-press with duration | x, y |
| `iphone_swipe` | Swipe with ease-in-out curve | start_x, start_y, end_x, end_y |
| `iphone_scroll` | Scroll wheel events | -- |
| `iphone_type_text` | Paste text via clipboard | text |
| `iphone_clear_text` | Select all + delete | -- |
| `iphone_press_key` | Send key event | key |
| `iphone_home` | Go to home screen (Cmd+1) | -- |
| `iphone_app_switcher` | Open App Switcher (Cmd+2) | -- |
| `iphone_spotlight` | Open Spotlight (Cmd+3) | -- |
| `iphone_screenshot` | Capture iPhone screen content | -- |
| `iphone_screenshot_with_ocr` | Screenshot + OCR (normalized coords) | -- |
| `iphone_analyze_screen_now` | Vision analysis on iPhone screen | -- |
| `iphone_analyze_with_llm` | iPhone screen + CoreML LLM | model_name, instruction |
| `iphone_open_app` | Open iOS app by name via Spotlight | app_name |
| `iphone_wait_for_text` | Poll iPhone OCR for text | text |
| `iphone_reconnect` | Wait for mirroring reconnection | -- |

**How iPhone Mirroring works:** The server detects the iPhone Mirroring window, calibrates the iPhone screen content area via Vision rectangle detection, and translates normalized coordinates to absolute screen coordinates. Swipe gestures use ease-in-out easing with an initial nudge to ensure iOS gesture recognition. Text input uses clipboard paste for universal language support.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MCP_MACOS_CONTROL_LOG_LEVEL` | `warn` | Log level: error, warn, info, debug, trace |
| `MCP_MACOS_CONTROL_MAX_INPUT_RATE` | `10` | Maximum input events per second |
| `MCP_MACOS_CONTROL_OVERRIDES_PATH` | _(see below)_ | Path to the per-app capability override file |
| `MCP_MACOS_CONTROL_AUDIT_DIR` | `~/Library/Logs/com.mcp.macos-control/audit/` | STORY-024: audit log directory |
| `MCP_MACOS_CONTROL_AUDIT_RETENTION_DAYS` | `365` | STORY-024: retention window before records move to archive |
| `MCP_MACOS_CONTROL_AUDIT_REMOTE` | `oslog` | STORY-024: off-host sink — `oslog`, `http`, or `syslog` |
| `MCP_MACOS_CONTROL_AUDIT_REMOTE_URL` | _(unset)_ | STORY-024: required when `REMOTE=http`; must be an `http(s)` URL |
| `MCP_MACOS_CONTROL_AUDIT_ACK_TIMEOUT_MS` | `5000` | STORY-024: per-record remote-ack timeout |
| `MCP_MACOS_CONTROL_AUDIT_ADMIN_ENABLED` | `false` | STORY-024: set `true` to expose the `force_rotate_unacked` MCP tool |

See [`docs/AUDIT-LOG-OPERATIONS.md`](docs/AUDIT-LOG-OPERATIONS.md) for the full
audit subsystem operator guide (chain verification, retention, incident
response, sink-specific configuration).

## Per-App Capability Overrides

The server ships a registry of per-application interaction-layer capabilities
(`ax_supported`, `applescript_supported`, `hit_test_supported`) so smart routing
can skip layers known to fail for a given app (e.g. Electron apps with unusable
accessibility trees). The shipped defaults live in the package bundle
(`Sources/MacOSControlLib/Router/Defaults/default-app-capabilities.json`, ~27
well-known apps) and are exposed read-only via the MCP Resource
`mcp://capability-registry/contents` (JSON: `schema_version` + `entries[]`, each
entry carrying a `source` of `defaults` or `user_override`).

Power users can shadow individual entries without rebuilding. Create:

```
~/Library/Application Support/mcp-macos-control/app-overrides.json
```

(or point `MCP_MACOS_CONTROL_OVERRIDES_PATH` at any path) using the same schema:

```json
{
  "schema_version": 1,
  "entries": [
    { "bundle_id": "com.example.app", "ax_supported": true,
      "applescript_supported": false, "hit_test_supported": true }
  ]
}
```

Override loading is **fail-soft**: a malformed override file is skipped (the
server logs a structured `invalid_capability_registry_override` error and starts
normally using the shipped defaults). Unknown JSON fields are ignored, so the
schema is forward-compatible. Override changes take effect on server restart
(no hot-reload). The bundled default file is kept current by the STORY-020
compatibility-catalog work.

## Architecture

```
Sources/
  MacOSControlLib/                   # Library target
    ToolModule.swift                 # ToolModule protocol
    ToolRouter.swift                 # Module registry + dispatch
    Errors.swift                     # MCPError structured errors
    Logger.swift                     # Structured logging
    RateLimiter.swift                # Token bucket rate limiter
    MouseControl.swift               # CGEvent mouse automation
    KeyboardControl.swift            # CGEvent keyboard automation
    ScreenCapture.swift              # Screenshot capture
    OCRProcessor.swift               # Vision OCR
    WindowManagement.swift           # Window list/activate
    VisionAnalyzer.swift             # Vision framework analysis
    CoreMLManager.swift              # CoreML model management
    ContinuousCaptureManager.swift   # ScreenCaptureKit streams
    RealtimeAnalyzer.swift           # Continuous vision analysis
    Accessibility/
      AccessibilityTreeBuilder.swift # AXUIElement tree traversal
      AXNodeSerializer.swift         # JSON shaping + schema_version
      AXNode.swift                   # Tree value type
    IPhoneMirroring/
      MirroringWindowDetector.swift  # Window detection + focus guard
      CoordinateTranslator.swift     # Content rect calibration + coord translation
      GestureEngine.swift            # Tap, swipe, scroll gestures
      IOSNavigation.swift            # Home, Spotlight, App Switcher, open app
      IPhoneTextInput.swift          # Clipboard paste, key events
    Modules/
      MouseModule.swift              # 9 mouse tools
      KeyboardModule.swift           # 4 keyboard tools
      ScreenCaptureModule.swift      # 2 capture tools
      WindowModule.swift             # 2 window tools
      ContinuousCaptureModule.swift  # 6 continuous capture tools
      VisionModule.swift             # 5 vision tools
      CoreMLModule.swift             # 8 CoreML tools
      RealtimeModule.swift           # 4 realtime tools
      SystemModule.swift             # 3 system tools
      AccessibilityModule.swift      # 1 accessibility tool
      IPhoneMirroringModule.swift    # 21 iPhone tools
  MCP-MacOSControl/
    Server.swift                     # Entry point (33 lines)
Tests/
  MCP-MacOSControlTests/            # 178 unit tests
```

## Development

```bash
swift build           # Debug build
swift build -c release # Release build
swift test            # Run the unit suite (integration suite auto-skips)
```

CI runs on every push via GitHub Actions (macOS 15, build + test).

### Integration Suite (STORY-012)

A separate, opt-in end-to-end suite (`MCP-MacOSControlIntegrationTests`)
exercises full agent workflows against **real** macOS apps through the real
`ToolRouter` — open/type/save, NSWorkspace launch flow, `smart_interact`
routing + fallback, coordinate-tool backward compatibility, the structured-error
contract across every registered code, and an iPhone Mirroring smoke test. It
needs a logged-in GUI session and Accessibility permission, so it is gated
behind `CI_MACOS_INTEGRATION` and runs on merge to `main` + nightly, not
per-PR. Without the flag every scenario skips, so a plain `swift test` stays
green.

```bash
# Grant Accessibility to the process running swift test first, then:
CI_MACOS_INTEGRATION=true swift test --filter MCP_MacOSControlIntegrationTests
```

See [Integration CI Setup](docs/INTEGRATION-CI-SETUP.md) and
[CONTRIBUTING.md](CONTRIBUTING.md).

## Documentation

- [Quick Start Guide](docs/QUICKSTART.md)
- [Permissions Guide](docs/PERMISSIONS.md)
- [Testing Checklist](docs/TESTING.md)
- [Integration CI Setup](docs/INTEGRATION-CI-SETUP.md)
- [CoreML Integration](docs/COREML_INTEGRATION.md)
- [Product Requirements](docs/PRD-MCP-MacOSControl.md)
- [App Compatibility Catalog](docs/APP-COMPATIBILITY.md) — evidence-based catalog regenerated from integration test observations (STORY-020)

## License

MIT License

## Acknowledgments

- Built with the [Model Context Protocol](https://modelcontextprotocol.io) Swift SDK
- Uses Apple's native frameworks (CoreGraphics, Vision, CoreML, ScreenCaptureKit, AppKit)
