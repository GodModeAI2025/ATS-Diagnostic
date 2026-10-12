# Strukturierter Streaming-Abschluss

withBytes(final consumer scope) und finishRecording erlauben deterministisches Finalisieren auch bei früher Rückgabe, Parserfehler oder nicht konsumiertem Körper. Akkumulation und genau-einmal-Finalisierung sind durch einen Lock geschützt. EOF-Einträge werden nicht doppelt gespeichert oder nachträglich zu Teilaufnahmen herabgestuft. Ein Consumer-Fehler wird unverändert zurückgeworfen, nicht als Transportfehler erfunden. Beobachtung endet ohne Task-Cancel.

responseComplete ist eine neue optionale Codable-Eigenschaft. Bei Teilaufnahmen bleiben beobachtete Bytezahl/Vorschau erhalten, der vollständige Hash fehlt. HAR verwendet unbekannte gesamte Körpergröße (-1), responseBytesKnown=false und separate observedResponseBytes. So behauptet der vorhandene App-Importer keine vollständige Größe. Später gelesene Bytes ändern einen abgeschlossenen Scope-Eintrag nicht.

27 kontrollierte Tests bestanden auf iOS (vier opt-in Live-Methoden übersprungen). Der macOS-Gesamtlauf mit Live-Freigabe bestand mit 31 Methoden; erneuter iOS-Live-Lauf bestand mit vier Methoden/sechs HTTPS-Fällen. Keine Fehler/Warnungen. Vier neue Fälle decken frühe Rückgabe vom MainActor, Parserfehler, reguläres EOF ohne Duplikat und nicht gelesenen Körper ab.

Die Low-Level-bytes-API benötigt bei frühem Verlassen weiterhin explizites finishRecording; automatische URLProtocol-Aufzeichnung bleibt offen. Diese SDK-only-Änderung ist nicht in hochgeladenem App-Build 41 enthalten.
