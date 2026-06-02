# 🎨 Nastarxa Paint Checker

(Useable but still need some feature and bug fixing)

Detect transparent (alpha) pixels in images and generate visual markers, heatmaps, overlays, and detailed analysis reports.

Perfect for checking paint gaps, transparency leaks, missing fills, export mistakes, and cleanup issues in animation, game assets, sprites, illustrations, and texture workflows.

![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)
![Language](https://img.shields.io/badge/language-AutoHotkey_v2-green)

---

## 🖼 Image Preview

![1](docs/images/1.png)

---

## ✨ Features

### 🔍 Transparency Detection

Quickly identify transparent pixels using an adjustable Alpha Threshold (0–255).

### 🎨 Filled Output

Generate a transparency mask using a custom fill color.

* User-defined hex color
* Built-in color presets
* Optional Fill On Top mode

### 🌡️ Heatmap Output

Visualize transparency density using a color gradient:

```text
Red → Yellow → Green → Blue
```

### 🖼️ Overlay Output

Combine multiple views into a single image:

1. Original image
2. Heatmap layer
3. Fill markers

Overlay opacity is fully adjustable.

### 📊 Detailed Analysis Report

Generate a text report containing:

* Transparent pixel count
* Coverage percentage
* Bounding box information
* Alpha distribution
* Connected-component cluster analysis

### 📁 Batch Processing

Process:

* Single images
* Multiple images
* Entire folders
* Recursive subfolders

### 🔎 Advanced Preview Window

Double-click any preview to open:

* Mouse-wheel zoom
* Drag panning
* Side-by-side comparison mode

### 💾 Flexible Export

Choose which outputs to save:

* Filled
* Heatmap
* Overlay
* Report

Optional ZIP export is also available.

### ⏱️ Progress Tracking

Large batches include:

* Progress bar
* Current file information
* Estimated remaining time (ETA)

### 🚀 No External Dependencies

Supports TGA files natively.

---

## 🖼️ Generated Outputs

| Output  | Description                                             |
| ------- | ------------------------------------------------------- |
| Filled  | Highlights transparent pixels using a custom fill color |
| Heatmap | Visualizes transparency density using a color gradient  |
| Overlay | Combines original image, heatmap, and fill markers      |
| Report  | Detailed transparency statistics and cluster analysis   |

---

## 📂 Supported Formats

```text
PNG
JPG
JPEG
BMP
TIFF
TIF
TGA
```

---

## ⚙️ Requirements

* Windows 7 or newer
* AutoHotkey v2 (source version only)

---

## 🚀 Quick Start

1. Launch Nastarxa Paint Checker.
2. Drop image files or folders into the window.
3. Adjust Alpha Threshold if needed.
4. Select which outputs to generate.
5. Click **Start**.
6. Review previews and analysis results.
7. Save outputs individually or export as ZIP.

---

## 📤 Output Location

Generated files are saved:

* Beside the original image

or

* Inside a `_paint_check_output` folder when enabled

---

## ⚡ Performance

Nastarxa Paint Checker is optimized for large images and batch operations.

Techniques used include:

* GDI+ LockBits pixel access
* Direct memory processing
* Multi-pass distance transforms
* Optimized flood-fill cluster detection
* Byte-array visited buffers

---

## 📜 License

MIT
See [LICENSE](/LICENSE).

---

## ⚠️ Disclaimer

This project was developed with the assistance of AI tools.
AI was used to support code writing, refactoring, and documentation, while the design direction, features, and final implementation were guided and reviewed by the author.
