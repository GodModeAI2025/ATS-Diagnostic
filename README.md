# ATS Diagnostic

Native connection diagnostics and a request workspace for iPhone and iPad.

Open `ATSDiagnostic.xcodeproj` in Xcode. Project configuration lives in `project.yml`; regenerate with `xcodegen generate` after adding targets or files.

Diagnostics stay on the device. The app contacts destinations explicitly entered by the person using it. System certificate validation remains active. Inspecting one connection does not establish that every configuration or code path of another app meets App Transport Security requirements.

The delivery checklist in `Release/Completion.md` records the full intended functionality and verification gates.
