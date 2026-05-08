# Third-Party Notices

This project does not vendor third-party binaries in source control. When you run `scripts/export_app.sh`, the exported macOS app can include locally installed `ffmpeg` and `ffprobe` binaries in `VideoConverterOsx.app/Contents/Resources/`.

## Bundled at export time

### FFmpeg and ffprobe

- Project: FFmpeg
- Website: https://ffmpeg.org/
- Purpose: media probing and conversion
- License: LGPL-2.1+ by default, or GPL if the bundled binary was built with GPL components
- Bundled by: `scripts/export_app.sh`, copied from the builder's local `PATH`

The FFmpeg license obligations depend on the exact binary that is bundled. The export script writes these files into the app bundle resources when `ffmpeg` is available:

- `FFmpeg-LICENSE.txt` from `ffmpeg -L`
- `FFmpeg-BUILD-CONFIG.txt` from `ffmpeg -version`

Before redistributing an exported `.app`, review those generated files. If the bundled FFmpeg build is LGPL, preserve the LGPL notices and do not restrict users from replacing or reverse-engineering the FFmpeg components as allowed by the LGPL. If the bundled FFmpeg build is GPL, the redistributed combined work may need to comply with the GPL, including source availability obligations.

## Project license shipped with app bundles

`scripts/export_app.sh` copies this project's `LICENSE` file into the exported app bundle as `Contents/Resources/LICENSE.txt` and copies this notice file as `Contents/Resources/THIRD_PARTY_NOTICES.md`.
