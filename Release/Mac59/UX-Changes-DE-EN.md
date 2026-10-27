# Build 59 — UX release (DE / EN)

**Status:** TestFlight available. Build 59 continues macOS 2.0.1 (58) on the existing app record **1297164068** and bundle **com.mobilebox.atsdiagnostic**. The 163 Mac tests and 3 targeted iOS tests passed. Core-flow native UI QA passed; archive, upload, Apple processing and owner-only TestFlight assignment are verified. Store submission is pending Apple screenshot processing. Localization covers the primary screens; detailed screens are not yet fully localized.

## Deutsch

- Verbesserter Kontrast der Aktionsschaltflächen: 5,42:1, im Modus „Erhöhter Kontrast“ 8,10:1. Eine separate Aktionsfarbe hält sie klar erkennbar.
- Die Titelleiste der Prüfseite zeigt jetzt „Verbindung prüfen“ statt des doppelten App-Namens.
- Die Primärbildschirme haben deutsche und englische Beschriftungen. HTTP-Verbindungen ohne TLS werden anhand der endgültigen Ziel-URL klar als „Unverschlüsselt“ angezeigt.
- Die vorhandenen Datei-Exporte bleiben unverändert und verwenden weiterhin die Teilen-Funktion; unter iOS bleibt der Teilen-Dialog erhalten.

**QA-Lernpunkt:** Das native „Sichern unter“-Experiment wurde entfernt: Beide `fileExporter`-/Save-As-Ansätze waren im Vollbild reproduzierbar deaktiviert. Es wird keine neue Speicherfunktion ausgeliefert.

## English

- Improved action-button contrast: 5.42:1, rising to 8.10:1 in High Contrast. A separate action tint keeps these controls distinct.
- The inspection screen title now says “Inspect connection” instead of repeating the app name.
- Primary screens now have German and English labels. HTTP connections without TLS are clearly identified as “Unencrypted” based on the final destination URL.
- Existing file exports remain unchanged and continue to use the share flow; iOS continues to use the share sheet.

**QA note:** The native Save As experiment was removed after both `fileExporter`/Save As approaches were reproducibly disabled in full-screen mode. No new save dialog is shipping.
