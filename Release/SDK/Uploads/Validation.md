# SDK-Uploads aus Data

Die optionale RecordingClient-API verwendet URLSession.upload(for:from:) auf der vom Host übergebenen Session. Der explizite Body ist für die Aufzeichnung maßgeblich, auch wenn URLRequest einen anderen Body enthält. Der Recorder speichert eine begrenzte Kopie, volle Bytezahlen und den vollständigen Antwort-Hash; er gibt Antwort und Fehler unverändert weiter.

Zwei neue kontrollierte Tests prüfen tatsächlichen Upload-Stream/Antwort/Hash und Transportfehler einschließlich unbekannter Antwortgröße. Der macOS-Lauf ist abgeschlossen: 15 Tests bestanden, zwei Live-Testmethoden übersprungen. Der ältere iPhone-Lauf ist inzwischen abgeschlossen: 15 bestanden, zwei übersprungen. Er meldete die damals noch bestehende Warnung zum redundanten Upload-Request-Body; die Korrektur ist durch spätere abgeschlossene iPad-Läufe ohne Laufzeitwarnungen belegt (siehe ../FileUploads/iOSTests.json).

Datei-Uploads, Downloads, Streaming und automatische URLProtocol-Aufzeichnung bleiben offen. Das separate SDK ist nicht Teil des hochgeladenen App-Builds 39.
