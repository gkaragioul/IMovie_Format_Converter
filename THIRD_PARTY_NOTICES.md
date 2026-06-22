# Third-Party Notices

This project does not vendor third-party binaries in source control. The default `scripts/export_app.sh` build does not bundle `ffmpeg` or `ffprobe`; users install FFmpeg separately, for example with Homebrew.

## Optional bundled export

### FFmpeg and ffprobe

- Project: FFmpeg
- Website: https://ffmpeg.org/
- Purpose: media probing and conversion
- License: LGPL-2.1+ by default, or GPL if the bundled binary was built with GPL components
- Optional bundling: `scripts/export_app.sh --bundle-ffmpeg`, copied from the builder's local `PATH`

The FFmpeg license obligations depend on the exact binary that is bundled. If `--bundle-ffmpeg` is used, the export script writes these files into the app bundle resources:

- `FFmpeg-LICENSE.txt` from `ffmpeg -L`
- `FFmpeg-BUILD-CONFIG.txt` from `ffmpeg -version`

Before redistributing an exported `.app` with bundled FFmpeg binaries, review those generated files. If the bundled FFmpeg build is LGPL, preserve the LGPL notices and do not restrict users from replacing or reverse-engineering the FFmpeg components as allowed by the LGPL. If the bundled FFmpeg build is GPL, the redistributed combined work may need to comply with the GPL, including source availability obligations.

## Project license shipped with app bundles

`scripts/export_app.sh` copies this project's `LICENSE` file into the exported app bundle as `Contents/Resources/LICENSE.txt` and copies this notice file as `Contents/Resources/THIRD_PARTY_NOTICES.md`.
