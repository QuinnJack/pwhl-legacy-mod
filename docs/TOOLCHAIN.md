# Toolchain

## Installed locally (not committed)

| Tool | Purpose | Status |
| --- | --- | --- |
| NHL Modding Studio 0.1.0-beta.3 | Primary roster/asset editor; understands NHL Legacy relationships and roster containers | Installed |
| NHLView NG 3.0.2510.26 | Independent roster editor and round-trip validator | Installed |
| TDBView 4.4.2510.26 | Low-level TDB inspection/export | Installed |
| TDBAccess 3.2.2510.26 | Scriptable TDB read/write library | Installed |
| String Editor 3.0 | Localization/string inspection | Installed |
| NHL Legacy Modding Workbench 1.0.0 | Community asset workflow | Installed |
| Heck Texture Editor 1.1 | Texture/model preview and replacement | Installed |
| EA BIG Tool 1.3 | Legacy BIG archive utilities | Installed |
| Recompiled NHL Legacy 0.6.0 extractor | Extracted PC-compatible game baseline and BIG extraction | Installed |
| Git | Local history and reproducibility | Installed |

The optional NHLView Legacy graphical preview pack is not required for editing. Its download host stalled during setup; retry it later only if portrait/head previews are useful.

## Safety rules

1. Never edit `../game` directly.
2. Run `Initialize-Workspace.ps1` before a new experiment.
3. Record a checksum whenever a binary DB becomes a candidate release artifact.
4. Store human-reviewable changes in `data/` and mapping documents, not only in opaque binaries.
5. Do not commit original game files, extracted art/audio, third-party executables, or their archives.

