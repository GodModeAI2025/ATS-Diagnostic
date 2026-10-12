# ATSRecording

Eigenständiges Swift-Paket für iOS 18+ und macOS 15+. Der erste Baustein ist ausdrücklich gewählte Aufzeichnung über eine vorhandene URLSession. Die vollständigen Antwortdaten werden unverändert an die aufrufende App zurückgegeben; das Journal enthält begrenzte, separat kopierte Vorschauen und den Hash der vollständigen erfolgreichen Antwort.

```swift
import ATSRecording
let recorder = try RecordingClient()
let (data, response) = try await recorder.data(for: request, using: existingSession)
let captured = await recorder.records()
let export = await recorder.jsonData()
let har = try await recorder.harData()
```

Die bestehende Session behält ihre Cookies, Weiterleitungen, Cache-, Proxy- und Authentifizierungsregeln. Das Paket installiert keinen Trust-Handler und registriert keine globalen Protokollklassen. Fehler werden mit ursprünglichem Domain/Code erfasst und unverändert weitergeworfen. Nach einem fehlgeschlagenen `data(for:)` sind Teilkörper und deren Bytezahl nicht verfügbar; diese Werte bleiben unbekannt. Request-Streams werden nicht vorab gelesen.

Standard: 200 Einträge, 64 KiB Vorschau je Körper, 64 MiB kodiertes Journal. Zu große Einträge werden ausgelassen; abgeschlossene ältere Einträge werden zur Einhaltung der Grenzen entfernt. `clear()` leert abgeschlossene Einträge und beendet keine laufenden Anfragen. Das Journal bleibt im Arbeitsspeicher. Exporte können vertrauliche Header oder Körper enthalten und müssen von der integrierenden App ausdrücklich geteilt werden.

Noch offen: automatische URLProtocol-Integration, Streaming-/Upload-/Download-Aufzeichnung, vollständige Redirect- und Verbindungsmetriken sowie eine vollständige SDK-Diagnoseoberfläche. Optionale Aktivierungshooks sind unten beschrieben. Dieses Paket ist noch nicht in Build 39 eingebettet. Die vollständige historische SDK-Parität ist damit nicht erreicht.

Prüfung: `swift test`. Die Tests verwenden eine kontrollierte URLProtocol-Gegenstelle in der vom Aufrufer bereitgestellten Session und prüfen vollständige Rückgabe trotz leerer Vorschau, unveränderte Fehler, tatsächliche POST-Daten, begrenztes Journal und explizites Leeren.

Zusätzlich: `ATS_RECORDING_LIVE=1 swift test` prüft example.com sowie die unveränderte Systemablehnung von expired.badssl.com und wrong.host.badssl.com. Diese Live-Prüfung wurde auf macOS und anschließend auf dem isolierten iPhone-Simulator mit iOS 27.0 ausgeführt. Zehn kontrollierte Tests und drei Live-Fälle bestanden dort.

HAR-Export und App-Import sind implementiert. Fehlende Protokollangaben bleiben unbekannt. Fehler und Hashwerte stammen aus der importierten Aufzeichnung und werden als solche gekennzeichnet. Bei gekürztem, binärem oder unbekanntem Anfragekörper wird keine vollständige Replay-Anfrage vorgetäuscht; die App deaktiviert Replay und cURL-Ausgabe. Anfragefelder stammen aus dem übergebenen URLRequest; von der Session ergänzte Cookies/Headers und einzelne Redirect-Hops sind noch nicht vollständig erfasst.

## Ereignisse

`let observation = try await recorder.observe()` liefert `observation.events`. Ereignisse melden den aktuellen Stand (`initial`), abgeschlossene Aufzeichnungen (`recorded` mit ID), wegen des Speicherlimits ausgelassene Aufzeichnungen (`recordingOmitted`) und das Leeren (`cleared`). Die Nutzdaten enthalten nur Revision/Typ/ID, keine Körperkopien. Jede Beobachtung puffert die neuesten 32 Ereignisse; maximal 16 Beobachter pro Recorder. Bei einer Revisionslücke `await recorder.records()` neu laden, statt alte Änderungen einzeln anzuwenden.

`await observation.cancel()` meldet einen Beobachter explizit ab. Task-Abbruch beendet die AsyncStream-Beobachtung ebenfalls; bereits gepufferte Ereignisse können nach explizitem Abschluss noch ausgelesen werden. Ein Beobachter hält den Recorder nicht am Leben. Wird der Recorder freigegeben, enden seine Streams. Die aufrufende App entscheidet über Darstellung und Aktivierung.

## Eigene Aktivierung und Schütteln

`RecordingActivation` läuft auf dem MainActor. Mit `isEnabled = true` und einem `handler` bestimmt die integrierende App ihre Präsentation. `activate()` löst eine eigene Aktion aus; der Handler erhält `.custom` oder `.shake`. Ohne Freigabe oder Handler bleibt die Aktivierung unbehandelt.

Auf iOS kann eine host-eigene `UIWindowScene` eine `RecordingWindow` verwenden und ihr `recordingActivation` zuweisen. Der Host muss den Aktivierungscontroller selbst halten; die Window-Referenz darauf ist schwach. Eine aktivierte Shake-Aktion wird vom SDK-Hook konsumiert; sonst läuft die Bewegung durch UIKit weiter. Der Hook ersetzt in diesem eingeschalteten Fall die normale Shake-Aktion. Es gibt keine globale Methodenänderung und keine automatische Präsentation beim Start.

Der native Beispielhost unter `Examples/ActivationDemo` demonstriert diese Verdrahtung pro Scene. Die API-Steuerung ist mit 13 kontrollierten Tests auf macOS und iOS geprüft; die echte Simulator-Shake-Prüfung des Beispielhosts läuft noch. Die automatische URLProtocol-Aufzeichnung und eine vollständige SDK-Diagnoseoberfläche bleiben offen.

## Uploads aus Data

`try await recorder.upload(for: request, from: body, using: session)` verwendet die bestehende URLSession direkt. Der explizite Upload-Body wird mit voller Bytezahl und begrenzter Vorschau protokolliert; der Aufrufer erhält die vollständige Antwort. Transportfehler bleiben unverändert. Datei-Uploads, Downloads und Streaming sind weiterhin offen.
