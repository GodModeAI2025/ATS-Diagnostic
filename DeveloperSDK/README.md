# ATSRecording

Eigenständiges Swift-Paket für iOS 18+ und macOS 15+. Der erste Baustein ist ausdrücklich gewählte Aufzeichnung über eine vorhandene URLSession. Die vollständigen Antwortdaten werden unverändert an die aufrufende App zurückgegeben; das Journal enthält begrenzte, separat kopierte Vorschauen und den Hash der vollständigen erfolgreichen Antwort.

```swift
import ATSRecording
let recorder = try RecordingClient()
let (data, response) = try await recorder.data(for: request, using: existingSession)
let captured = await recorder.records()
let export = await recorder.jsonData()
```

Die bestehende Session behält ihre Cookies, Weiterleitungen, Cache-, Proxy- und Authentifizierungsregeln. Das Paket installiert keinen Trust-Handler und registriert keine globalen Protokollklassen. Fehler werden mit ursprünglichem Domain/Code erfasst und unverändert weitergeworfen. Nach einem fehlgeschlagenen `data(for:)` sind Teilkörper und deren Bytezahl nicht verfügbar; diese Werte bleiben unbekannt. Request-Streams werden nicht vorab gelesen.

Standard: 200 Einträge, 64 KiB Vorschau je Körper, 64 MiB kodiertes Journal. Zu große Einträge werden ausgelassen; abgeschlossene ältere Einträge werden zur Einhaltung der Grenzen entfernt. `clear()` leert abgeschlossene Einträge und beendet keine laufenden Anfragen. Das Journal bleibt im Arbeitsspeicher. Exporte können vertrauliche Header oder Körper enthalten und müssen von der integrierenden App ausdrücklich geteilt werden.

Noch offen: automatische URLProtocol-Integration, Streaming-/Upload-/Download-Aufzeichnung, vollständige Redirect- und Verbindungsmetriken, HAR/App-Import, Ereignisbenachrichtigungen und Shake-/Präsentationshooks. Dieses Paket ist noch nicht in Build 38 eingebettet. Die vollständige historische SDK-Parität ist damit nicht erreicht.

Prüfung: `swift test`. Die Tests verwenden eine kontrollierte URLProtocol-Gegenstelle in der vom Aufrufer bereitgestellten Session und prüfen vollständige Rückgabe trotz leerer Vorschau, unveränderte Fehler, tatsächliche POST-Daten, begrenztes Journal und explizites Leeren.

Zusätzlich: `ATS_RECORDING_LIVE=1 swift test` prüft example.com sowie die unveränderte Systemablehnung von expired.badssl.com und wrong.host.badssl.com. Diese Live-Prüfung wurde auf macOS ausgeführt; iOS ist bisher kompiliert, die SDK-Laufzeit dort noch nicht geprüft.
