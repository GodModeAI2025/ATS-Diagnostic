# ATS Diagnostic

Native connection diagnostics and a request workspace for iPhone and iPad.

Open `ATSDiagnostic.xcodeproj` in Xcode. Project configuration lives in `project.yml`; regenerate with `xcodegen generate` after adding targets or files.

Diagnostics stay on the device. The app contacts destinations explicitly entered by the person using it. System certificate validation remains active. Inspecting one connection does not establish that every configuration or code path of another app meets App Transport Security requirements.

The `ATSDiagnostic` scheme uses the original app identity. `ATSDiagnosticPreview` uses the separate authorized internal-testing identity; both run the same source and keep the on-device name ATS Diagnostic.

The interface adapts to available window width. Wide layouts place input, statistics and results in separate panes. Larger accessibility text switches metric cards to a vertical stack. Small vector illustrations support the content in light and dark appearances.

The delivery checklist in `Release/Completion.md` records functionality and verification gates.
