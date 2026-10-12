# Asynchrone Verlaufsspeicherung

JSON-Kodierung und atomare, geschützte Dateischreibvorgänge laufen jetzt im eigenen HistoryPersistence-Actor statt auf dem MainActor der Oberfläche. Monoton steigende Revisionen verhindern, dass ein verspäteter älterer Schreibauftrag einen neueren Stand oder einen geleerten Verlauf ersetzt. Nur Fehler der aktuellen Revision werden in der Oberfläche gemeldet.

Zwei neue Tests prüfen verspätete Schreibaufträge nach clear sowie den vollständigen Roundtrip von Körpern und Zertifikatdaten. Die abschließende iPad-Gesamtsuite besteht: 107 Testmethoden (108 Ausführungen wegen parametrisiertem Fall), keine Fehler oder Laufzeitwarnungen. Der erste Gesamtlauf hatte einen bestehenden Loopback-Proxy-Fehler „Network is down“; der vollständige Wiederholungslauf einschließlich dieses Falls bestand. Der zwischenzeitliche Methodenfilter hatte nur die beiden Speicherungstests ausgewählt und ist kein Proxy-Nachweis.

Initiales Laden und Größenbegrenzung laufen weiterhin synchron; asynchrone Initialisierung, Coalescing und garantierter Flush beim Hintergrundwechsel bleiben offen. Dieser App-Code ist noch nicht in dem hochgeladenen Build 39 enthalten.
