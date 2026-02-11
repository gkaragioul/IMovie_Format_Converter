# VideoConverterOsx

A native macOS batch converter app that converts dragged-and-dropped media into an iMovie-friendly format.

The app is built with SwiftUI and a conversion core around `ffmpeg`, with progress tracking for both per-file and overall batch status.

## Why this format

The converter targets a profile that imports reliably into iMovie:

- Container: `QuickTime MOV` (`.mov`)
- Video: `H.264` (`libx264`, `yuv420p`, profile `high`, level `4.1`)
- Audio: `AAC` stereo at `192k`
- Streaming-friendly atom placement: `+faststart`

Output files are named as `<original>_imovie.mov` (with numeric suffixes on collision).

## Features

- Drag and drop one or many video files
- Drag and drop folders (recursive scan for supported media)
- Batch queue with per-item status (`Pending`, `Converting`, `Done`, `Failed`)
- Per-item progress bars and overall progress bar
- Export path picker
- Cancel in-progress conversion
- Built-in app icon generation and bundling
- One-command export to a desktop `.app` bundle

## Supported input extensions

`3gp`, `avi`, `m2ts`, `m4v`, `mkv`, `mov`, `mp4`, `mpeg`, `mpg`, `mts`, `mxf`, `ts`, `vob`, `webm`, `wmv`

## Project layout

- `Sources/VideoConverterOsxApp/VideoConverterOsxApp.swift`: macOS SwiftUI app and UI logic
- `Sources/VideoConverterCore/ConversionEngine.swift`: ffmpeg/ffprobe integration and progress parsing
- `Tests/VideoConverterCoreTests/ConversionEngineTests.swift`: parser tests + ffmpeg integration test
- `scripts/build_icon.sh`: generates `.icns` from scripted artwork
- `scripts/export_app.sh`: builds release binary and exports `.app` to Desktop
- `Assets/AppIcon.icns`: dock icon used by the exported app bundle

## Requirements

- macOS 13+
- Swift 5.10+ toolchain
- `ffmpeg` + `ffprobe` on PATH (or bundled in app resources)

Install ffmpeg on Apple Silicon:

```bash
brew install ffmpeg
```

## Build and test

```bash
swift build
swift test
```

## Run in development

```bash
swift run VideoConverterOsxApp
```

## Export desktop app bundle

```bash
./scripts/export_app.sh
```

Default export location:

- `/Users/<your-user>/Desktop/VideoConverterOsx.app`

The export script bundles `ffmpeg` and `ffprobe` into app resources when they are available.

## Using the app

1. Launch `VideoConverterOsx.app`.
2. Click `Select Media` or drag files/folders into the drop zone.
3. Click `Set Export Path` and choose your output folder.
4. Click `Convert`.
5. Wait for queue completion and review any failed rows.

## Error handling behavior

- Missing input files are marked failed without crashing the app.
- Conversion failures are isolated per item; remaining queue continues.
- If duration probing fails, conversion still proceeds (progress granularity may reduce).

## Version

Current release target: `v1.0`
