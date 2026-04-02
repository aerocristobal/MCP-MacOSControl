# MCP-MacOSControl: Product Requirements & Architecture

**Version:** 0.3.0-draft  
**Last Updated:** 2026-04-01  
**Status:** Draft — All architectural decisions resolved  
**Repository:** [github.com/aerocristobal/MCP-MacOSControl](https://github.com/aerocristobal/MCP-MacOSControl)  
**Primary Target Device:** iPhone 17 Pro Max (2868×1320 pixels, 19.5:9 aspect ratio, @3x scale)

---

## 1. Problem Statement

AI assistants lack the ability to perceive and interact with the macOS desktop environment. Without visual context, spatial awareness, and input control, an AI cannot assist with tasks that require operating GUI applications — including the critical use case of controlling iOS apps through macOS Sequoia's iPhone Mirroring.

### 1.1 Why This Matters

iPhone Mirroring (macOS 15 Sequoia) renders an iOS device's screen as a macOS window. A macOS-level MCP server that can see, click, and type can transitively control iOS apps — without jailbreaking, without the iOS Simulator, without Xcode. This unlocks automation of iOS-only apps, testing workflows, and cross-device task orchestration from a single AI interface.

### 1.2 Current State

MCP-MacOSControl provides **39 tools** across 9 categories: mouse, keyboard, screen capture with OCR, window management, continuous ScreenCaptureKit capture, Vision framework analysis, CoreML on-device intelligence, real-time monitoring, and system permissions. The **primary gap** is iPhone Mirroring integration.

### 1.3 Prior Art

| Project | Language | Key Patterns to Adopt |
|---------|----------|-----------------------|
| iphone-mirror-mcp (kae-builds) | TypeScript | Normalized 0–1 coordinates, clipboard paste for text, swipe easing curves, CGEvent input |
| mirroir-mcp (jfarcand) | Rust | OCR-based element targeting, skill recording, permission controls, YOLO CoreML for icon detection |
| computer-control-mcp (AB498) | Python | Original inspiration. Not native macOS. |

**Key insight from mirroir-mcp:** macOS routes HID input to the frontmost app. The server must activate iPhone Mirroring before each input event. This is a fundamental constraint of the CGEvent approach.

---

## 2. Vision

Provide an AI assistant with full perceptual and motor control of a macOS desktop through a single native MCP server, with first-class support for controlling iOS apps via iPhone Mirroring.

---

## 3. Architectural Decisions (Resolved)

All open questions from v0.2.0 have been resolved:

### D1. Content Inset Detection — Dynamic Calibration via Vision

**Problem:** There is no public Apple API for iPhone Mirroring. The `com.apple.ScreenContinuity` app provides no developer surface for querying the content rect of the iPhone screen within its window. The Apple Developer Forums confirm this — a developer building RocketSim asked directly and was told the API surface is insufficient.

**Decision:** Use **dynamic calibration via the existing `detect_rectangles` Vision tool**. The approach:

1. `CGWindowListCopyWindowInfo` returns the window's outer bounds (including title bar and chrome).
2. Capture the window image via `CGWindowListCreateImage`.
3. Run `VisionAnalyzer.detectRectangles()` on the captured image to find the iPhone screen rectangle within the window. The phone screen content area is a distinct rectangle (sharp edges, high contrast against the window background/bezel chrome).
4. Cache the detected content rect, keyed by window size. Re-detect when the window size changes.
5. If rectangle detection fails (e.g., the iPhone screen content fills the window ambiguously), fall back to heuristic insets: title bar ~28pt top, ~0pt left/right/bottom.

This approach self-calibrates regardless of iPhone model, window zoom level (Larger/Actual Size/Smaller), or macOS version. The existing Vision framework infrastructure handles the heavy lifting.

**iPhone 17 Pro Max reference dimensions:**

| Property | Value |
|----------|-------|
| Pixel resolution | 2868 × 1320 |
| Logical points | ~956 × 440 |
| Aspect ratio | 19.5:9 (~2.17:1) |
| Scale factor | @3x |
| PPI | 460 |

The mirroring window renders the iPhone screen at a scaled-down resolution that preserves the 19.5:9 aspect ratio. The `CoordinateTranslator` uses the detected content rect's actual pixel dimensions, not the iPhone's native resolution, for coordinate mapping.

### D2. Window Resize Recovery — Automatic Recalibration

**Decision:** The `CoordinateTranslator` caches the content rect keyed by the window's current size (`width × height`). On every coordinate translation:

1. Query current window bounds via `CGWindowListCopyWindowInfo`.
2. If size differs from cached, re-run `detect_rectangles` calibration.
3. If the window is not found (closed/disconnected), return a `MIRRORING_NOT_RUNNING` error.
4. If calibration fails after resize, return `CALIBRATION_FAILED` error with a message suggesting the user try a different window size.

This makes the system resilient to window resizing, repositioning, and mirroring session drops.

### D3. CoreML Composition with iPhone — Yes

**Decision:** Add `iphone_analyze_with_llm` and `iphone_analyze_screen_now` tools that compose the existing `RealtimeAnalyzer` and `CoreMLManager` with iPhone-specific window capture and coordinate normalization. These tools capture only the mirroring window, run Vision/CoreML analysis, and return results with coordinates normalized to the iPhone screen (0–1).

### D4. UI Element Targeting — AXUIElement Accessibility Tree

**Decision:** Supplement visual OCR with `AXUIElement` accessibility tree reading for more reliable element targeting. This is the approach macOS itself uses for VoiceOver and other assistive technologies.

**Rationale:** Visual OCR works well for text but cannot identify non-text UI elements (icons, toggles, unlabeled buttons). The accessibility tree provides structured element hierarchy with roles, labels, and positions. However, **AXUIElement only works for macOS applications, not for the iPhone screen content rendered inside the mirroring window.** For iPhone Mirroring specifically, the approach remains visual (OCR + Vision framework analysis + optional CoreML icon detection).

**Implementation:** Add an `accessibility_tree` tool for macOS windows, and lean on OCR + `detect_rectangles` + `classify_image` for iPhone Mirroring content.

### D5. Architecture — Decompose the Monolith

**Decision:** Decompose `Server.swift` (currently 1270 lines, single switch with 39+ cases) into a modular tool router architecture. Each tool category becomes a self-contained module that registers its own tools and handlers.

See Section 7 for the detailed architecture.

### D6. iPhone Count — Single Session Only

**Decision:** Support exactly one iPhone Mirroring session. The `MirroringWindowDetector` finds the first matching `com.apple.ScreenContinuity` window and uses it. No multi-device management.

---

## 4. Existing Tool Inventory (39 Tools)

Fully implemented. See v0.2.0 Section 5 for the complete catalog with parameters. Unchanged.

**Summary by category:**

| Category | Count | Key Tools |
|----------|-------|-----------|
| Mouse Control | 6 | `click_screen`, `move_mouse`, `drag_mouse`, `mouse_down`, `mouse_up`, `get_screen_size` |
| Keyboard Control | 4 | `type_text`, `press_keys`, `key_down`, `key_up` |
| Screen Capture & OCR | 2 | `take_screenshot`, `take_screenshot_with_ocr` |
| Window Management | 2 | `list_windows`, `activate_window` |
| Utility | 1 | `wait_milliseconds` |
| Continuous Capture | 6 | `start_continuous_capture`, `stop_continuous_capture`, `get_capture_frame`, + 3 enumeration tools |
| Vision Analysis | 5 | `classify_image`, `detect_objects`, `detect_rectangles`, `detect_saliency`, `detect_faces` |
| CoreML Intelligence | 8 | `generate_text_llm`, `analyze_screen_with_llm`, `intelligent_screen_summary`, `extract_key_info`, + 4 model management |
| Real-Time Analysis | 4 | `analyze_screen_now`, `start_screen_monitoring`, `get_monitoring_results`, `stop_screen_monitoring` |
| System | 1 | `check_permissions` |

---

## 5. iPhone Mirroring: New Tools (18 Tools)

### 5.1 Mirroring Session Management (3 tools)

| Tool | Parameters | Returns |
|------|-----------|---------|
| `iphone_launch` | — | Launches or activates iPhone Mirroring app. Returns window info on success. |
| `iphone_status` | — | `{running, windowId, position, size, calibrated, contentRect}` |
| `iphone_calibrate` | — | Force re-run content rect detection. Returns detected insets. |

### 5.2 Input (8 tools)

| Tool | Parameters | Returns |
|------|-----------|---------|
| `iphone_tap` | `x` (0–1), `y` (0–1) | Activates mirroring window, translates coords, clicks. |
| `iphone_double_tap` | `x` (0–1), `y` (0–1) | Two rapid clicks with ~50ms gap. |
| `iphone_long_press` | `x` (0–1), `y` (0–1), `duration_ms?` (default: 500) | Mouse down, wait, mouse up. |
| `iphone_swipe` | `start_x`, `start_y`, `end_x`, `end_y` (0–1), `duration_ms?` (default: 300) | Ease-in-out drag with initial nudge. |
| `iphone_scroll` | `direction` (up/down/left/right), `amount?` | Scroll wheel events at center of content area. |
| `iphone_type_text` | `text` | Save clipboard → set text → Cmd+V → restore clipboard. |
| `iphone_clear_text` | — | Cmd+A then Delete. |
| `iphone_press_key` | `key`, `modifiers?` | Key event targeted to mirroring window. |

### 5.3 Navigation (3 tools)

| Tool | Parameters | Returns |
|------|-----------|---------|
| `iphone_home` | — | Activates mirroring window, sends Cmd+1. |
| `iphone_app_switcher` | — | Activates mirroring window, sends Cmd+2. |
| `iphone_spotlight` | — | Activates mirroring window, sends Cmd+3. |

### 5.4 Perception (4 tools)

| Tool | Parameters | Returns |
|------|-----------|---------|
| `iphone_screenshot` | `save_to_disk?` | Captures mirroring window content area only. Returns base64 PNG. |
| `iphone_screenshot_with_ocr` | — | base64 PNG + OCR results with coordinates normalized to 0–1. |
| `iphone_analyze_screen_now` | `include_classification?`, `include_objects?`, `include_rectangles?`, `include_text?` | Vision analysis of iPhone screen with 0–1 normalized results. |
| `iphone_analyze_with_llm` | `model_name`, `instruction`; optional analysis flags | Capture iPhone screen → Vision → CoreML LLM reasoning. |

---

## 6. macOS Accessibility Tree: New Tool (1 Tool)

| Tool | Parameters | Returns |
|------|-----------|---------|
| `accessibility_tree` | `app_name?`, `window_title?`, `max_depth?` (default: 3) | Structured AXUIElement hierarchy: role, label, value, position, size for each element. |

**Note:** This works for macOS app windows only. For iPhone Mirroring content, use visual tools (`iphone_screenshot_with_ocr`, `iphone_analyze_screen_now`).

---

## 7. Target Architecture

### 7.1 Modular Tool Router

The monolithic `Server.swift` (1270 lines, single switch) is decomposed into a protocol-based module system:

```swift
/// Each tool module conforms to this protocol
protocol ToolModule {
    /// The tools this module provides
    static var tools: [Tool] { get }
    
    /// Handle a tool call. Return nil if tool name not handled by this module.
    static func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result?
}
```

```
Sources/
└── MCP-MacOSControl/
    ├── Server.swift                         # @main, MCP setup, ToolRouter dispatch (~80 lines)
    ├── ToolRouter.swift                     # Collects modules, dispatches by name (~40 lines)
    │
    ├── Modules/
    │   ├── MouseModule.swift                # MouseControl tools + handlers
    │   ├── KeyboardModule.swift             # KeyboardControl tools + handlers
    │   ├── ScreenCaptureModule.swift        # Screenshot + OCR tools + handlers
    │   ├── WindowModule.swift               # Window management tools + handlers
    │   ├── ContinuousCaptureModule.swift    # ScreenCaptureKit tools + handlers
    │   ├── VisionModule.swift               # Vision analysis tools + handlers
    │   ├── CoreMLModule.swift               # CoreML + NLP tools + handlers
    │   ├── RealtimeModule.swift             # Screen monitoring tools + handlers
    │   ├── SystemModule.swift               # Permissions, utilities
    │   ├── AccessibilityModule.swift        # AXUIElement tree (NEW)
    │   └── IPhoneMirroringModule.swift      # All iphone_* tools + handlers (NEW)
    │
    ├── Core/                                # Stateless implementation classes (existing, unchanged)
    │   ├── MouseControl.swift
    │   ├── KeyboardControl.swift
    │   ├── ScreenCapture.swift
    │   ├── OCRProcessor.swift
    │   └── WindowManagement.swift
    │
    ├── Vision/                              # Vision + capture (existing, unchanged)
    │   ├── VisionAnalyzer.swift
    │   ├── RealtimeAnalyzer.swift
    │   └── ContinuousCaptureManager.swift
    │
    ├── Intelligence/                        # CoreML (existing, unchanged)
    │   └── CoreMLManager.swift
    │
    ├── IPhoneMirroring/                     # NEW — iPhone Mirroring implementation
    │   ├── MirroringWindowDetector.swift    # Find window, launch, check status
    │   ├── CoordinateTranslator.swift       # Dynamic calibration, normalized ↔ absolute
    │   ├── GestureEngine.swift              # Tap, swipe, scroll, long-press
    │   └── IOSNavigation.swift              # Home, App Switcher, Spotlight
    │
    ├── Accessibility/                       # NEW — AXUIElement tree reading
    │   └── AccessibilityTreeReader.swift
    │
    └── Utilities/
        └── Errors.swift                     # Structured error types (NEW)
```

### 7.2 ToolRouter

```swift
struct ToolRouter {
    static let modules: [ToolModule.Type] = [
        MouseModule.self,
        KeyboardModule.self,
        ScreenCaptureModule.self,
        WindowModule.self,
        ContinuousCaptureModule.self,
        VisionModule.self,
        CoreMLModule.self,
        RealtimeModule.self,
        SystemModule.self,
        AccessibilityModule.self,
        IPhoneMirroringModule.self,
    ]
    
    static var allTools: [Tool] {
        modules.flatMap { $0.tools }
    }
    
    static func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        for module in modules {
            if let result = try await module.handle(params) {
                return result
            }
        }
        return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
    }
}
```

This reduces `Server.swift` to ~30 lines: create `Server`, register `ToolRouter.allTools` for `ListTools`, and `ToolRouter.handle` for `CallTool`.

### 7.3 iPhone Mirroring Data Flow

```
AI calls iphone_tap(x: 0.5, y: 0.3)
    │
    ▼
IPhoneMirroringModule.handle()
    │
    ├── 1. MirroringWindowDetector.findWindow()
    │       └── CGWindowListCopyWindowInfo, filter by "iPhone Mirroring" owner name
    │       └── If not found → return MIRRORING_NOT_RUNNING error
    │
    ├── 2. CoordinateTranslator.translate(normalizedX: 0.5, normalizedY: 0.3)
    │       ├── Check cached content rect. If window size changed → recalibrate:
    │       │     ├── CGWindowListCreateImage (capture window)
    │       │     ├── VisionAnalyzer.detectRectangles (find iPhone screen rect)
    │       │     └── Cache result keyed by window size
    │       ├── Map (0.5, 0.3) to absolute screen coords within content rect
    │       └── Validate point is within bounds → INVALID_COORDINATES if not
    │
    ├── 3. WindowManagement.activateWindow("iPhone Mirroring")
    │       └── Must be frontmost for CGEvent input to route correctly
    │
    ├── 4. MouseControl.click(x: absoluteX, y: absoluteY)
    │       └── CGEvent left mouse down + up
    │
    └── 5. Return success
```

### 7.4 Coordinate Translation Detail

```
┌─────────────────────────────────────────────────┐
│ macOS Window (CGWindowListCopyWindowInfo bounds) │
│                                                 │
│  ┌─ Title Bar (~28pt) ────────────────────────┐ │
│  │  ● ● ●        iPhone Mirroring            │ │
│  └────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────┐ │
│  │                                            │ │
│  │    iPhone Screen Content (19.5:9)          │ │
│  │    ┌──────────────────────────────────┐    │ │
│  │    │                                  │    │ │
│  │    │  (0,0) ──────────────── (1,0)    │    │ │
│  │    │  │                          │    │    │ │
│  │    │  │   Normalized coords      │    │    │ │
│  │    │  │   (0-1 range)            │    │    │ │
│  │    │  │                          │    │    │ │
│  │    │  (0,1) ──────────────── (1,1)    │    │ │
│  │    │                                  │    │ │
│  │    └──────────────────────────────────┘    │ │
│  │              ▲                             │ │
│  │              │ detect_rectangles finds     │ │
│  │              │ this inner rect             │ │
│  └────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘

Translation formula:
  absoluteX = contentRect.x + (normalizedX × contentRect.width)
  absoluteY = contentRect.y + (normalizedY × contentRect.height)
```

---

## 8. Structured Error Handling

New `Errors.swift` provides typed error codes across all modules:

| Code | Meaning | Used By |
|------|---------|---------|
| `PERMISSION_DENIED` | macOS permission not granted | All modules |
| `WINDOW_NOT_FOUND` | Target window does not exist | WindowModule, IPhoneMirroringModule |
| `MIRRORING_NOT_RUNNING` | iPhone Mirroring app not active | IPhoneMirroringModule |
| `MIRRORING_NOT_AVAILABLE` | macOS < 15 or Intel Mac | IPhoneMirroringModule |
| `CALIBRATION_FAILED` | Could not detect iPhone screen rect in window | IPhoneMirroringModule |
| `INVALID_COORDINATES` | Coordinates outside valid range | IPhoneMirroringModule |
| `INPUT_FAILED` | CGEvent creation or posting failed | Mouse/KeyboardModule |
| `MODEL_NOT_LOADED` | CoreML model not loaded | CoreMLModule |
| `OCR_FAILED` | Vision text recognition failed | ScreenCaptureModule |

Error response format:

```json
{
  "content": [{"type": "text", "text": "MIRRORING_NOT_RUNNING: iPhone Mirroring is not active. Launch it first with iphone_launch."}],
  "isError": true
}
```

---

## 9. Non-Functional Requirements

| ID | Requirement |
|----|-------------|
| NFR-1 | Screenshot + return: < 500ms. |
| NFR-2 | OCR processing: < 2s. |
| NFR-3 | Input actions: < 100ms. |
| NFR-4 | Content rect calibration: < 1s (Vision detect_rectangles). |
| NFR-5 | macOS 13.0 (Ventura) minimum for core tools. macOS 15.0 (Sequoia) for iPhone Mirroring. Apple Silicon required for mirroring. |
| NFR-6 | Single `swift build -c release` produces working binary. MCP Swift SDK v0.10.0+ only external dependency. |
| NFR-7 | stdio transport only. No network listeners. |

---

## 10. Security Considerations

1. **Local-only.** stdio transport.
2. **No credentials.** Never stores or transmits secrets.
3. **No persistence by default.** Screenshots are in-memory base64.
4. **Clipboard restore.** `iphone_type_text` saves and restores original clipboard contents.
5. **Frontmost window requirement.** The mirroring window must be focused for input, which means the AI's actions are visible to the user.
6. **iPhone Mirroring gives transitive access to all iOS apps** including banking, health, and authentication apps.

---

## 11. Development Roadmap

### Phase 1: Modular Architecture (Prep)

Decompose `Server.swift` into `ToolRouter` + per-category `Module` files. Zero functionality change — pure refactor.

**Verification:** All 39 existing tools pass manual integration testing unchanged. Server.swift drops from 1270 lines to ~30.

### Phase 2: iPhone Mirroring Core

Build `IPhoneMirroring/` module and `IPhoneMirroringModule`.

**Deliverables:**
- `MirroringWindowDetector` — Find by owner name, launch, status check.
- `CoordinateTranslator` — Dynamic calibration via `detect_rectangles`, auto-recalibrate on resize.
- `GestureEngine` — Tap, double-tap, long-press, swipe (with easing), scroll.
- `IOSNavigation` — Home (Cmd+1), App Switcher (Cmd+2), Spotlight (Cmd+3).
- 18 new `iphone_*` tools.

**Exit criteria:** AI agent launches iPhone Mirroring, opens an iOS app via Spotlight, interacts with UI elements, reads screen via OCR. Demonstrated on iPhone 17 Pro Max with at least two iOS apps.

### Phase 3: Accessibility + CoreML Composition

- `AccessibilityTreeReader` + `accessibility_tree` tool for macOS windows.
- `iphone_analyze_with_llm` composing CoreML with iPhone screenshots.
- `iphone_analyze_screen_now` composing Vision analysis with normalized coords.
- Structured error codes across all modules.
- `scroll` and `double_click` tools for core mouse control.
- `button` parameter on `click_screen`.

### Phase 4: Polish

- Unit tests for `CoordinateTranslator` and key mapping.
- Manual integration test scripts documented in `TESTING.md`.
- Fix README project structure section.
- `wait_for_text` tool — poll + OCR until text appears or timeout.

### Phase 5: Advanced (Future)

- Multi-display support.
- Notification observation for iPhone notifications in macOS Notification Center.
- Skill recording/replay (inspired by mirroir-mcp).
- YOLO CoreML model for non-text UI element detection on iPhone screen.

---

## 12. Testing Strategy

### 12.1 Unit Tests (CI-compatible)

| Test | What |
|------|------|
| `CoordinateTranslatorTests` | Given window bounds and content rect, verify normalized ↔ absolute conversion. Verify out-of-bounds returns error. Verify cache invalidation on size change. |
| `KeyMappingTests` | Verify key name → CGKeyCode for all supported keys. |
| `ErrorCodeTests` | Verify error types produce correct string codes. |

### 12.2 Integration Tests (Manual, require display + permissions)

| Test | Steps | Expected |
|------|-------|----------|
| Calibration accuracy | Launch mirroring, `iphone_calibrate`, tap four corners | Taps land within iPhone screen bounds |
| Resize recovery | `iphone_tap` → resize window → `iphone_tap` again | Second tap auto-recalibrates, lands correctly |
| Disconnect handling | `iphone_tap` while mirroring is closed | Returns `MIRRORING_NOT_RUNNING` error |
| End-to-end: Messages | `iphone_launch` → `iphone_spotlight` → type "Messages" → `iphone_tap` → compose → send | Message sent successfully |

---

## 13. Known Issues in Current Codebase

| Issue | Severity | Phase to Fix |
|-------|----------|--------------|
| Server.swift is 1270-line monolith | Medium | Phase 1 |
| README project structure lists 5 files (actual: 10) | Low | Phase 4 |
| No `scroll` or `double_click` tools | Medium | Phase 3 |
| `click_screen` is left-click only | Low | Phase 3 |
| No automated tests | Medium | Phase 4 |
| Errors are unstructured strings | Low | Phase 3 |

---

## 14. References

- [MCP Specification](https://modelcontextprotocol.io/specification)
- [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk)
- [Apple Vision Framework — Text Recognition](https://developer.apple.com/documentation/vision/recognizing-text-in-images)
- [CGEvent Reference](https://developer.apple.com/documentation/coregraphics/cgevent)
- [CGWindowListCopyWindowInfo](https://developer.apple.com/documentation/coregraphics/cgwindowlistcopywindowinfo(_:_:))
- [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)
- [CoreML Framework](https://developer.apple.com/documentation/coreml)
- [AXUIElement (Accessibility)](https://developer.apple.com/documentation/applicationservices/axuielement)
- [iPhone Mirroring — macOS Sequoia](https://support.apple.com/en-us/105114)
- [iPhone 17 Pro Max Specs](https://www.apple.com/iphone-17-pro/specs/) — 2868×1320, 19.5:9, @3x
- [iphone-mirror-mcp](https://github.com/kae-builds/iphone-mirror-mcp) — Reference: normalized coords, clipboard paste, swipe easing
- [mirroir-mcp](https://github.com/jfarcand/mirroir-mcp) — Reference: OCR-based targeting, skill system, permission controls
- [com.apple.ScreenContinuity](https://georgegarside.com/blog/ios/how-to-resize-iphone-mirroring-window/) — Bundle ID, plist config, View menu scaling

---

*This document is a living artifact. Update it as decisions are made and the architecture evolves.*
