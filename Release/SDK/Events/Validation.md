# SDK-Ereignisse

Zehn kontrollierte macOS-Tests bestanden. Vier neue Tests prüfen Aufzeichnung/Leeren/Streamabschluss, erkennbare Ereignislücken bei langsamen Empfängern samt erneuter Journalabfrage, Freigabe des Beobachterlimits und Producer-Lebensdauer. Die beiden opt-in Live-Testmethoden wurden in diesem Lauf ausgelassen; frühere Live-Nachweise bleiben gesondert dokumentiert. iOS-Simulator-Build erfolgreich. Anschließend bestanden auf dem isolierten iPhone-Simulator zehn kontrollierte Tests (zwei opt-in Live-Testmethoden zunächst übersprungen) und ein gesonderter gezielter Live-Lauf mit zwei Testmethoden/drei HTTPS-Fällen ohne Fehler oder übersprungene Fälle.

Ereignisse enthalten Revision, Typ und gegebenenfalls Record-ID. 32 gepufferte Ereignisse je Beobachter, maximal 16 Beobachter. Zu große Journal-Einträge erzeugen einen Omission-Hinweis; die Netzwerkantwort bleibt unverändert. Abmeldung oder Task-Abbruch beendet die Beobachtung. Beobachter halten den Recorder nicht am Leben; Recorder-Freigabe beendet Streams. Gepufferte Werte können beim Abschluss noch ausgelesen werden.

Das ist SDK-Infrastruktur für integrierende Apps, noch keine automatische URLProtocol-Aufzeichnung oder fertige Shake-/Präsentationsoberfläche. Die hochgeladene App-Version 2.0 (39) ist unverändert.

Native iOS-Live-Ergebnisse: example.com HTTP 200; expired.badssl.com und wrong.host.badssl.com jeweils Systemablehnung NSURLErrorDomain/-1202, unverändert zurückgegeben und aufgezeichnet. Die Testumgebung wurde über eine Kopie der von Xcode erzeugten xctestrun-Datei mit dem dokumentierten EnvironmentVariables-Feld aktiviert. Testbundle und __TESTROOT__-Bezüge blieben am ursprünglichen Build-Ort. Die Tester-/Store-Freigabe ist davon unabhängig.
