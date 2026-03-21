# VideoConverterOsx

> **This project is no longer maintained.** It was a personal tool that served its purpose and is now archived as open source under the MIT license. No further updates, bug fixes, or support will be provided. That said, the app works — feel free to build it yourself and use it as-is.

A native macOS batch converter app that converts dragged-and-dropped media into an iMovie-friendly format (H.264 + AAC in a `.mov` container). Built with SwiftUI and powered by `ffmpeg`.

## Building a working app from source

### Prerequisites

- A Mac running **macOS 13+**
- **Xcode Command Line Tools** (or full Xcode) with Swift 5.10+
- **ffmpeg** and **ffprobe** installed via Homebrew

```bash
# Install Xcode Command Line Tools (if not already installed)
xcode-select --install

# Install ffmpeg
brew install ffmpeg
```

### Option 1: Export as a desktop .app bundle (recommended)

This builds a release binary and creates a standalone `VideoConverterOsx.app` on your Desktop, with `ffmpeg` and `ffprobe` bundled inside:

```bash
git clone https://github.com/georgekgr12/VideoConverterOsx.git
cd VideoConverterOsx
chmod +x scripts/export_app.sh scripts/build_icon.sh
./scripts/export_app.sh
```

The app will appear at `~/Desktop/VideoConverterOsx.app`. Double-click to launch.

### Option 2: Run directly from source

```bash
git clone https://github.com/georgekgr12/VideoConverterOsx.git
cd VideoConverterOsx
swift run VideoConverterOsxApp
```

This requires `ffmpeg` and `ffprobe` to be on your PATH.

## How to use the app

1. Launch `VideoConverterOsx.app`
2. Click **Select Media** or drag files/folders into the drop zone
3. Click **Set Export Path** and choose your output folder
4. Click **Convert**
5. Wait for the queue to finish — failed items are shown inline

Output files are named `<original>_imovie.mov`.

## What it converts to

| Setting | Value |
|---------|-------|
| Container | QuickTime MOV (`.mov`) |
| Video | H.264 (`libx264`, `yuv420p`, profile high, level 4.1) |
| Audio | AAC stereo at 192k |
| Atom placement | `+faststart` (streaming-friendly) |

## Supported input formats

`3gp`, `avi`, `m2ts`, `m4v`, `mkv`, `mov`, `mp4`, `mpeg`, `mpg`, `mts`, `mxf`, `ts`, `vob`, `webm`, `wmv`

## Features

- Drag and drop files or entire folders (recursive scan)
- Batch queue with per-item status and progress bars
- Overall progress tracking
- Export path picker
- Cancel in-progress conversions
- Conversion failures are isolated per item; the rest of the queue continues

## Project structure

- `Sources/VideoConverterOsxApp/` — SwiftUI app and UI logic
- `Sources/VideoConverterCore/` — ffmpeg/ffprobe integration and progress parsing
- `Tests/VideoConverterCoreTests/` — unit and integration tests
- `scripts/export_app.sh` — builds and exports the `.app` bundle
- `scripts/build_icon.sh` — generates the app icon

## License

[MIT](LICENSE)
