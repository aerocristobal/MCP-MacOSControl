# New Features: Continuous Capture & Vision Framework Integration

## Overview

This update adds **11 powerful new tools** bringing the total to **26 tools**, with two major enhancements:

1. **Continuous Screen Capture** using ScreenCaptureKit
2. **Advanced Vision Framework** capabilities (image classification, object detection, face detection, etc.)

---

## 🎥 Continuous Capture with ScreenCaptureKit

### Why Continuous Capture?

Unlike one-shot screenshots, continuous capture allows you to:
- Monitor displays, windows, or applications in real-time
- Capture frames at configurable frame rates (up to 60 FPS)
- Build screen recording or monitoring applications
- Perform live analysis on screen content

### New Tools (6)

#### 1. **start_continuous_capture**
Start capturing frames continuously from a display, window, or application.

**Parameters:**
- `capture_type` (string, required): "display", "window", or "application"
- `target_identifier` (string, optional):
  - For display: Display ID (defaults to main display)
  - For window: Window ID or title to search
  - For application: Bundle identifier or app name
- `frame_rate` (integer, optional): Capture FPS, default 30

**Example Usage:**
```
"Start continuous capture of the main display at 30 FPS"
"Start capturing the Chrome window continuously"
"Start continuous capture of com.apple.Safari application"
```

#### 2. **stop_continuous_capture**
Stop the active continuous capture session.

**Parameters:** None

**Example:**
```
"Stop continuous capture"
```

#### 3. **get_capture_frame**
Get the latest captured frame as a base64-encoded PNG image.

**Parameters:** None

**Returns:** PNG image data

**Example:**
```
"Get the latest capture frame"
"Show me the current captured frame"
```

#### 4. **list_capturable_displays**
List all available displays that can be captured.

**Returns:**
```json
[
  {
    "displayID": 123456,
    "width": 2560,
    "height": 1440,
    "frame": {
      "x": 0,
      "y": 0,
      "width": 2560,
      "height": 1440
    }
  }
]
```

#### 5. **list_capturable_windows**
List all windows available for ScreenCaptureKit capture.

**Returns:** Array of window objects with:
- `windowID`: Unique window identifier
- `title`: Window title
- `ownerName`: Application name
- `bundleIdentifier`: App bundle ID
- `frame`: Window position and size

#### 6. **list_capturable_applications**
List all running applications available for capture.

**Returns:** Array of app objects with:
- `bundleIdentifier`: e.g., "com.apple.Safari"
- `applicationName`: e.g., "Safari"
- `processID`: Process ID

---

## 🧠 Vision Framework Integration

### Advanced Image Analysis Capabilities

The Vision framework provides on-device machine learning for image analysis:

### New Tools (5)

#### 7. **classify_image**
Classify what objects/scenes are present in an image.

**Parameters:**
- `image_data` (string, required): Base64-encoded image
- `top_k` (integer, optional): Number of top results, default 5

**Returns:**
```json
[
  {
    "identifier": "dog",
    "confidence": 0.95,
    "confidencePercentage": 95
  },
  {
    "identifier": "golden_retriever",
    "confidence": 0.87,
    "confidencePercentage": 87
  }
]
```

**Example Usage:**
```
"Classify what's in this screenshot"
"What objects are in the captured image?"
```

#### 8. **detect_objects**
Detect objects (primarily animals) with bounding boxes.

**Parameters:**
- `image_data` (string, required): Base64-encoded image
- `minimum_confidence` (number, optional): Threshold 0.0-1.0, default 0.5

**Returns:**
```json
[
  {
    "boundingBox": {
      "x": 120,
      "y": 200,
      "width": 300,
      "height": 400
    },
    "labels": [
      {
        "identifier": "dog",
        "confidence": 0.92,
        "confidencePercentage": 92
      }
    ],
    "confidence": 0.92,
    "confidencePercentage": 92
  }
]
```

**Use Cases:**
- Detect animals in photos
- Locate objects with pixel coordinates
- Build object tracking systems

#### 9. **detect_rectangles**
Detect rectangular shapes (UI elements, documents, screens, etc.).

**Parameters:**
- `image_data` (string, required): Base64-encoded image
- `minimum_confidence` (number, optional): Threshold 0.0-1.0, default 0.5

**Returns:**
```json
[
  {
    "boundingBox": {
      "x": 50,
      "y": 100,
      "width": 500,
      "height": 300
    },
    "corners": {
      "topLeft": [50, 100],
      "topRight": [550, 100],
      "bottomRight": [550, 400],
      "bottomLeft": [50, 400]
    },
    "confidence": 0.87,
    "confidencePercentage": 87
  }
]
```

**Use Cases:**
- Detect UI windows and buttons
- Find documents or screens within screenshots
- Locate rectangular objects for automation

#### 10. **detect_saliency**
Detect attention-grabbing regions in an image.

**Parameters:**
- `image_data` (string, required): Base64-encoded image

**Returns:**
```json
{
  "salientObjects": [
    {
      "boundingBox": {
        "x": 200,
        "y": 150,
        "width": 400,
        "height": 300
      },
      "confidence": 0.85
    }
  ],
  "objectCount": 1
}
```

**Use Cases:**
- Identify most important regions in images
- Auto-crop to interesting content
- Prioritize areas for further analysis

#### 11. **detect_faces**
Detect faces in images with bounding boxes and orientation.

**Parameters:**
- `image_data` (string, required): Base64-encoded image

**Returns:**
```json
[
  {
    "boundingBox": {
      "x": 300,
      "y": 250,
      "width": 200,
      "height": 250
    },
    "confidence": 0.98,
    "roll": -0.1,
    "yaw": 0.2
  }
]
```

**Additional Info:**
- `roll`: Head tilt angle
- `yaw`: Left/right turn angle

**Use Cases:**
- Face detection and counting
- Privacy: Blur faces in screenshots
- Zoom to faces in images

---

## Complete Workflow Examples

### Example 1: Continuous Monitoring with Classification

```
1. "Start continuous capture of the main display at 10 FPS"
2. Wait a few seconds...
3. "Get the latest capture frame"
4. "Classify what's in this image"
   → Returns: screen, computer, desktop, etc.
```

### Example 2: Window Analysis

```
1. "List capturable windows"
   → Find Chrome window ID
2. "Start capturing the Chrome window"
3. "Get capture frame"
4. "Detect rectangles in this image"
   → Find UI elements, buttons, dialogs
```

### Example 3: Object Detection Pipeline

```
1. "Take a screenshot"
2. "Detect objects in the screenshot"
3. "Detect faces in the screenshot"
4. "Classify the image"
   → Complete analysis of screen content
```

### Example 4: Application Monitoring

```
1. "List capturable applications"
2. "Start continuous capture of com.apple.Safari"
3. Periodically: "Get capture frame and classify"
   → Monitor what's happening in Safari
```

---

## Technical Details

### ScreenCaptureKit Features

- **Modern API**: Uses macOS 13+ ScreenCaptureKit
- **High Performance**: Hardware-accelerated capture
- **Flexible Targeting**: Displays, windows, or entire applications
- **Configurable FPS**: 1-60 frames per second
- **Low Latency**: Real-time frame access

### Vision Framework Features

- **On-Device Processing**: All ML runs locally
- **Privacy-Preserving**: No data sent to servers
- **High Accuracy**: Apple-trained models
- **Fast**: Optimized for Apple Silicon
- **Comprehensive**: Multiple analysis types

### Performance Considerations

**Continuous Capture:**
- Higher FPS = More CPU/memory usage
- Recommended: 10-30 FPS for most use cases
- 60 FPS for high-precision monitoring

**Vision Analysis:**
- Classification: ~50-200ms per image
- Object Detection: ~100-300ms per image
- Face Detection: ~50-150ms per image
- Works best with reasonably-sized images (<4K)

---

## Updated Tool Count

| Category | Tools | Total |
|----------|-------|-------|
| Mouse Control | 6 | 6 |
| Keyboard Control | 4 | 4 |
| Screenshots (one-shot) | 2 | 2 |
| Window Management | 2 | 2 |
| Utility | 1 | 1 |
| **Continuous Capture** | **6** | **6** |
| **Vision Framework** | **5** | **5** |
| **TOTAL** | | **26** |

---

## Comparison with Original

| Feature | Before | Now |
|---------|--------|-----|
| Total Tools | 15 | **26** |
| Screenshot Types | One-shot only | One-shot + Continuous |
| Vision Capabilities | OCR only | OCR + Classification + Detection |
| Capture Targets | Screen/Windows | Displays/Windows/Apps |
| Frame Rate Control | N/A | Configurable FPS |
| Object Detection | ❌ | ✅ |
| Face Detection | ❌ | ✅ |
| Rectangle Detection | ❌ | ✅ |
| Saliency Detection | ❌ | ✅ |

---

## Use Cases Enabled

### Screen Recording & Monitoring
- Record application windows continuously
- Monitor display changes in real-time
- Build custom screen recording tools

### UI Automation
- Detect UI elements (rectangles)
- Find clickable buttons and dialogs
- Navigate interfaces programmatically

### Content Analysis
- Classify screenshot content
- Detect what's on screen
- Build smart screen readers

### Privacy & Security
- Detect and blur faces
- Identify sensitive content
- Monitor for unwanted content

### Accessibility
- Identify salient regions for attention
- Build smart zoom features
- Enhance screen reader capabilities

### Quality Assurance
- Automated UI testing
- Visual regression testing
- Screenshot comparison

---

## Installation & Setup

1. **Build the updated version:**
   ```bash
   swift build -c release
   ```

2. **Install:**
   ```bash
   sudo cp .build/release/mcp-macos-control /usr/local/bin/
   ```

3. **Restart Claude Desktop** to load the new tools

4. **Grant Permissions** (same as before):
   - Accessibility
   - Screen Recording

---

## Breaking Changes

**None!** All existing 15 tools work exactly as before. The new tools are purely additive.

---

## Future Enhancements

Potential additions:
- Text detection in images (separate from OCR)
- Barcode/QR code scanning
- Horizon detection
- Image similarity comparison
- Video export from continuous capture

---

## Conclusion

This update transforms MCP-MacOSControl from a screenshot and automation tool into a **comprehensive computer vision and monitoring platform**. With 26 tools total, it's now one of the most feature-complete MCP servers for macOS.

**Key Advantages:**
- ✅ Real-time screen monitoring
- ✅ Advanced ML-powered image analysis
- ✅ Zero external dependencies (all native frameworks)
- ✅ High performance on Apple Silicon
- ✅ Privacy-preserving (on-device processing)
