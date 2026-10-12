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

Noch offen: automatische URLProtocol-Integration, automatische Erfassung vorhandener Sessions, Vorschau tatsächlich übertragener Datei-Uploads und Abschluss abgebrochener Stream-Konsumenten, vollständige Redirect- und Verbindungsmetriken sowie eine vollständige SDK-Diagnoseoberfläche. Optionale Aktivierungshooks sind unten beschrieben. Dieses Paket ist noch nicht in Build 39 eingebettet. Die vollständige historische SDK-Parität ist damit nicht erreicht.

Prüfung: `swift test`. Die Tests verwenden eine kontrollierte URLProtocol-Gegenstelle in der vom Aufrufer bereitgestellten Session und prüfen vollständige Rückgabe trotz leerer Vorschau, unveränderte Fehler, tatsächliche POST-Daten, begrenztes Journal und explizites Leeren.

Zusätzlich: `ATS_RECORDING_LIVE=1 swift test` prüft example.com sowie die unveränderte Systemablehnung von expired.badssl.com und wrong.host.badssl.com. Diese Live-Prüfung wurde auf macOS und anschließend auf dem isolierten iPhone-Simulator mit iOS 27.0 ausgeführt. Zehn kontrollierte Tests und drei Live-Fälle bestanden dort.

HAR-Export und App-Import sind implementiert. Fehlende Protokollangaben bleiben unbekannt. Fehler und Hashwerte stammen aus der importierten Aufzeichnung und werden als solche gekennzeichnet. Bei gekürztem, binärem oder unbekanntem Anfragekörper wird keine vollständige Replay-Anfrage vorgetäuscht; die App deaktiviert Replay und cURL-Ausgabe. Anfragefelder stammen aus dem übergebenen URLRequest; von der Session ergänzte Cookies/Headers und einzelne Redirect-Hops sind noch nicht vollständig erfasst.

## Ereignisse

`let observation = try await recorder.observe()` liefert `observation.events`. Ereignisse melden den aktuellen Stand (`initial`), abgeschlossene Aufzeichnungen (`recorded` mit ID), wegen des Speicherlimits ausgelassene Aufzeichnungen (`recordingOmitted`) und das Leeren (`cleared`). Die Nutzdaten enthalten nur Revision/Typ/ID, keine Körperkopien. Jede Beobachtung puffert die neuesten 32 Ereignisse; maximal 16 Beobachter pro Recorder. Bei einer Revisionslücke `await recorder.records()` neu laden, statt alte Änderungen einzeln anzuwenden.

`await observation.cancel()` meldet einen Beobachter explizit ab. Task-Abbruch beendet die AsyncStream-Beobachtung ebenfalls; bereits gepufferte Ereignisse können nach explizitem Abschluss noch ausgelesen werden. Ein Beobachter hält den Recorder nicht am Leben. Wird der Recorder freigegeben, enden seine Streams. Die aufrufende App entscheidet über Darstellung und Aktivierung.

## Eigene Aktivierung und Schütteln

`RecordingActivation` läuft auf dem MainActor. Mit `isEnabled = true` und einem `handler` bestimmt die integrierende App ihre Präsentation. `activate()` löst eine eigene Aktion aus; der Handler erhält `.custom` oder `.shake`. Ohne Freigabe oder Handler bleibt die Aktivierung unbehandelt.

Auf iOS kann eine host-eigene `UIWindowScene` eine `RecordingWindow` verwenden und ihr `recordingActivation` zuweisen. Der Host muss den Aktivierungscontroller selbst halten; die Window-Referenz darauf ist schwach. Eine aktivierte Shake-Aktion wird vom SDK-Hook konsumiert; sonst läuft die Bewegung durch UIKit weiter. Der Hook ersetzt in diesem eingeschalteten Fall die normale Shake-Aktion. Es gibt keine globale Methodenänderung und keine automatische Präsentation beim Start.

Der native Beispielhost unter `Examples/ActivationDemo` demonstriert diese Verdrahtung pro Scene. Die API-Steuerung ist mit 13 kontrollierten Tests auf macOS und iOS geprüft; die Custom-Präsentation ist im iPad-Simulator bestätigt. Echter Shake bleibt mit den verfügbaren Gerätewerkzeugen unverifiziert (kein dokumentierter MCP-Befehl bzw. Shake-Menüeintrag in Device Hub). Die automatische URLProtocol-Aufzeichnung und eine vollständige SDK-Diagnoseoberfläche bleiben offen.

## Uploads aus Data

`try await recorder.upload(for: request, from: body, using: session)` verwendet die bestehende URLSession direkt. Der explizite Upload-Body wird mit voller Bytezahl und begrenzter Vorschau protokolliert; der Aufrufer erhält die vollständige Antwort. Transportfehler bleiben unverändert. Streaming und Datei-Uploads sind unten beschrieben.

## Downloads

`try await recorder.download(for: request, using: session)` gibt die von URLSession erzeugte Datei und Antwort unverändert zurück. Die SDK-Aufzeichnung liest die Datei in 64-KiB-Blöcken, berechnet SHA-256 über den vollständigen Inhalt und speichert nur die konfigurierte Vorschau. Auch bei Vorschaugröße null bleiben Dateigröße und Hash erhalten. Falls das nachgelagerte Lesen für das Journal scheitert, bleibt der erfolgreiche Download erfolgreich und ein `recordingOmitted`-Ereignis wird gemeldet. Die aufrufende App ist weiter für den Umgang mit der temporären Datei verantwortlich.

## Datei-Uploads

`try await recorder.upload(for: request, fromFile: fileURL, using: session)` übergibt die vorhandene Datei direkt an URLSession. Das SDK liest den Anfragekörper nicht vorab; seine Vorschau und gesendete Bytezahl bleiben unbekannt. Der HAR-Export kennzeichnet diesen Körper als nicht verfügbar. Die vollständige Antwort, begrenzte Antwortvorschau und der vollständige Antwort-Hash werden wie bei Data-Uploads behandelt. Die Quelldatei gehört weiterhin der aufrufenden App.

## Gestreamte Antworten

`let (stream, response) = try await recorder.bytes(for: request, using: session)` nutzt die übergebene Session direkt. `for try await byte in stream` liefert jedes konsumierte Byte. Vorschau und Hash-Puffer bleiben begrenzt; SHA-256 wird über alle konsumierten Bytes berechnet und erst bei EOF als vollständiger Hash gespeichert. Bei einem Iterator-Transportfehler bleiben beobachtete Teilbytes und der Originalfehler erhalten, ohne vollständigen Hash. Die beobachtete Dauer umfasst auch die Zeit der Konsumierung, keine isolierte Netzwerkmetrik.

Der Stream ist einmalig und mit einem Iterator zu konsumieren; Iteratoren nicht kopieren oder gleichzeitig benutzen. Ein zweiter Iterator wird mit `ConsumptionError.alreadyConsumed` abgewiesen. `stream.task` erlaubt dem Host die normale Task-Steuerung. Vor EOF/Fehler gibt es keinen abgeschlossenen Journaleintrag. Wird die Schleife vorzeitig verlassen oder gar nicht begonnen, wird kein abgeschlossener Eintrag behauptet; automatische Abschlussbeobachtung solcher Konsumenten bleibt offen. Das SDK übernimmt keine zusätzlichen Authentifizierungs- oder Trust-Handler.

Die Streaming-API ist zusätzlich gegen echte HTTPS-Gegenstellen auf macOS und iOS 27.0 geprüft: example.com HTTP 200 mit passendem vollständigem Hash, expired.badssl.com und wrong.host.badssl.com mit unveränderter Systemablehnung und exakt protokolliertem Rückgabefehler. Siehe `Release/SDK/Streaming/Live` im Hauptprojekt. Das ist kein physischer TestFlight-Installationsnachweis.

## Strukturierter Stream-Abschluss

`try await recorder.withBytes(for: request, using: session) { stream, response in ... }` finalisiert die Aufzeichnung beim Verlassen des Consumer-Scopes, einschließlich früher Rückgabe und Parserfehlern. Der Consumer kann auf dem MainActor laufen. Ein Parserfehler bleibt der originale Consumer-Fehler und wird nicht als Transportfehler gespeichert. Bei regulärem EOF bleibt der vollständige Eintrag erhalten, ohne zweite Aufzeichnung.

Bei früher Beendigung enthält `responseBytes` die tatsächlich beobachteten Bytes, `responseComplete` ist false und der vollständige Hash fehlt. HAR stellt die gesamte Antwortgröße als unbekannt (-1) dar; `_atsDiagnostic.observedResponseBytes` bewahrt die beobachtete Anzahl. Dadurch behaupten auch ältere App-Importer keine vollständige Antwortgröße. `stream.finishRecording()` bietet diesen Abschluss auch explizit für die Low-Level-API. Er beendet die Beobachtung und cancelt die Netzwerk-Task nicht; später konsumierte Bytes ändern den abgeschlossenen Eintrag nicht. Ohne strukturierten Scope oder expliziten Abschluss bleibt ein früh verlassener Low-Level-Stream weiterhin ohne abgeschlossenen Eintrag.

## Foundation-Verbindungsmetriken

`try await recorder.dataWithMetrics(for: request, using: session)` erfasst zusätzlich die von Foundation gemeldeten Task-Metriken. Uploads (Data/Datei), Downloads, `bytes` und `withBytes` bieten dafür `collectMetrics: true`. Die bisherigen Aufrufe behalten standardmäßig ihr Verhalten. Ein optionaler `delegate:` erhält die aufgabenspezifischen Callbacks; ohne diesen Parameter wird der vorhandene Task-Delegate der Session berücksichtigt.

Der Beobachter speichert Metriken und leitet die übrigen Objective-C-Delegate-Callbacks an die Host-Implementierung weiter, darunter Weiterleitungsentscheidungen. Es wird kein eigener Authentifizierungs- oder Trust-Handler implementiert. Der Metrik-Callback wird zusätzlich an den Host weitergeleitet. Die integrierende App muss dies gegen ihre tatsächlichen Delegate-Implementierungen prüfen.

`RecordedExchange.metrics` enthält native Task-Dauer, Redirect-Anzahl und einzelne Transaktionen mit URL, Status, gemeldetem Protokoll, lokalen/entfernten Adressen und DNS-/TCP-/TLS-/Sende-/Warte-/Empfangszeiten. Fehlende Zeitwerte bleiben unbekannt. Höchstens128 Transaktionen werden gespeichert; Gesamtzahl und Kürzung werden ausgewiesen. Die lokale Adresse kann eine private Netzwerkadresse sein; URLs und Exporte können vertrauliche Angaben enthalten.

Diese Transportmetriken sind getrennt von der Dauer des Stream-Konsumenten und von den tatsächlich konsumierten Körperbytes. Bei frühem Stream-Abschluss können Metriken noch fehlen; ein späterer Callback verändert den bereits abgeschlossenen Journaleintrag nicht. HAR bewahrt die Metriken unter `_atsDiagnostic.taskMetrics`, ohne die Zeiten eines einzelnen Redirect-Hops als Gesamtzeit der HAR-Anfrage auszugeben.

Die SDK-Erweiterung ist nicht Bestandteil des bereits eingereichten beziehungsweise in TestFlight freigegebenen App-Builds50.

### Delegate-delivered data tasks

`RecordingSessionDelegate(recorder:forwardingTo:previewLimit:)` can be supplied as the delegate when the host creates a URLSession with its own configuration. The wrapper observes newly created delegate-based data tasks, bounded response chunks, native metrics and completion; other optional Objective-C callbacks are forwarded to the host delegate. No new authentication handler or trust override is installed. The host still receives the original data and error.

Keep the wrapper alive through the session. Existing sessions cannot have their delegate replaced. Per-task delegates can supersede the session delegate. Completion-handler and async bodies, upload/download tasks, background sessions and automatic URLProtocol/global capture are not covered by this API; use the explicit RecordingClient APIs where applicable. No empty-body hash is invented when Foundation has not delivered response data (except HTTP semantics that require no body). Native buffering can discard bytes before an error reaches the data delegate.

At most 64 active tasks retain previews, each at most 64 KiB; `omittedTaskCount` reports capacity omissions. The journal has its own configured retention budget. Each task is keyed by object identity, including when one wrapper serves multiple sessions with identical numeric task identifiers. Journal insertion is asynchronous after the host completion callback; await a recorded event before exporting. Record duration spans task creation through completion, including suspension; native task metrics remain separate.
