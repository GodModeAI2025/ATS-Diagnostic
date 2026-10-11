# SDK-Ereignisse

Zehn kontrollierte macOS-Tests bestanden. Vier neue Tests prüfen Aufzeichnung/Leeren/Streamabschluss, erkennbare Ereignislücken bei langsamen Empfängern samt erneuter Journalabfrage, Freigabe des Beobachterlimits und Producer-Lebensdauer. Die beiden opt-in Live-Testmethoden wurden in diesem Lauf ausgelassen; frühere Live-Nachweise bleiben gesondert dokumentiert. iOS-Simulator-Build erfolgreich, SDK-Laufzeit dort weiterhin offen.

Ereignisse enthalten Revision, Typ und gegebenenfalls Record-ID. 32 gepufferte Ereignisse je Beobachter, maximal 16 Beobachter. Zu große Journal-Einträge erzeugen einen Omission-Hinweis; die Netzwerkantwort bleibt unverändert. Abmeldung oder Task-Abbruch beendet die Beobachtung. Beobachter halten den Recorder nicht am Leben; Recorder-Freigabe beendet Streams. Gepufferte Werte können beim Abschluss noch ausgelesen werden.

Das ist SDK-Infrastruktur für integrierende Apps, noch keine automatische URLProtocol-Aufzeichnung oder fertige Shake-/Präsentationsoberfläche. Die hochgeladene App-Version 2.0 (39) ist unverändert.
