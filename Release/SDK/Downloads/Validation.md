# SDK-Downloads

18 kontrollierte Tests bestehen auf macOS und iOS (isoliertes iPad, iOS 27.0). Zwei opt-in Live-Testmethoden wurden übersprungen. Der finale iOS-Ergebnisbericht meldet null Fehler und keine Laufzeitwarnungen.

Drei neue Tests prüfen unveränderte 150.017-Byte-Download-Datei mit vollständigem Hash über drei Leseblöcke trotz Drei-Byte-Vorschau, Vorschaugröße null und unveränderte Transportfehler. Die Aufzeichnung liest die temporäre Datei in 64-KiB-Blöcken. Nachgelagerte Journal-I/O-Fehler ersetzen keinen erfolgreichen Download; sie melden recordingOmitted. Die SDK-API übergibt bei Data-Uploads eine Request-Kopie ohne redundanten Body/Stream, damit der explizite Upload-Body maßgeblich bleibt.

Datei-Uploads, Streaming, automatische URLProtocol-Aufzeichnung und die vollständige SDK-Diagnoseoberfläche bleiben offen. Dieses separate SDK ist nicht in App-Build 39 eingebettet. Der ältere iPhone-Upload-Testprozess sammelt noch Simulator-Diagnosedaten; dieser Bericht stützt sich auf den abgeschlossenen finalen iPad-Lauf.
