# DeskSway B1 Soft / Graphite

Created with the installed VectorCraft application's official loopback command API on 2026-11-05. These are editable vector reconstructions of the selected B1 concept, not cropped image-generation previews.

- `DeskSway-B1-Graphite.vectorcraft`: editable 1024 × 1024 app artwork; white continuous S arrows over a `#637180` → `#303943` tile, with transparent outer margins.
- `DeskSway-MenuBar.vectorcraft`: the same outline scaled into an 18 × 18 transparent artboard, filled black for use as a template mask.
- Matching SVG files provide portable vector sources. `MenuBar-18.png` and `MenuBar-36.png` are size previews.
- VectorCraft exported `Resources/Icons/AppIcon-1024.png` and the PDF now stored at `Sources/DeskSway/Resources/MenuBarIcon.pdf`; export responses reported no warnings.
- `Sources/DeskSway/Resources/DeskSway.icns` contains macOS icon sizes 16, 32, 128, 256 and 512 points at 1× and 2×. It was packaged with macOS `sips` and `iconutil` from the 1024-pixel export.

The app loads the PDF from its SwiftPM resource bundle, sizes it to 18 points and marks it as an AppKit template so the system supplies its menu-bar color. The existing pause dimming and accessibility description remain. The build script includes the resource bundle and ICNS before signing.

Validation: release app build and signature verification, all 50 existing tests, and AppKit loading of the bundled 18 × 18 PDF and ICNS passed. Native PNG exports were visually inspected. The rebuilt app was restarted successfully; the local ad-hoc rebuild caused its permissions to be reported as unrecognized, so input conversion requires the user to restore permission recognition. Live menu-bar light/dark appearance has not been visually verified.
