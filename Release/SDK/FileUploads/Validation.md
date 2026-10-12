# Dateibasierte SDK-Uploads

19 kontrollierte Tests bestehen auf macOS und iOS 27.0 (isoliertes iPad); zwei opt-in Live-Testmethoden übersprungen, keine Fehler oder Laufzeitwarnungen. Der neue Test sendet 150.017 Bytes aus einer Datei, prüft die vollständige Echo-Antwort samt Hash und die unveränderte Quelldatei sowie die HAR-Kennzeichnung des unbekannten Anfragekörpers.

RecordingClient.upload(for:fromFile:using:) übergibt die Datei direkt an die bestehende URLSession. Das Journal liest den Anfragekörper nicht vorab und behauptet keine tatsächlich gesendete Bytezahl. Es speichert Antwortvorschau, volle Antwortgröße und Hash; der HAR-Anfragekörper bleibt unavailable und schützt damit vor unvollständigem Replay. Die Request-Kopie enthält keinen redundanten Body/Stream. Session-Konfiguration und Authentifizierung bleiben beim Host.

Eine tatsächliche Vorschau der übertragenen Datei, Streaming, automatische URLProtocol-Aufzeichnung und vollständige SDK-Diagnoseoberfläche bleiben offen. App-Build 39 enthält dieses separate Paket noch nicht.
