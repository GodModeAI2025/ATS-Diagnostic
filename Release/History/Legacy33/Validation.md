# Kompatibilität mit Build 33

History-Legacy33.json wurde mit dem eigenen archivierten DiagnosticRecord-/CertificateRecord-Modell aus e77e565 durch dessen JSONEncoder erzeugt. Es ist eine synthetische Schema-Fixture mit absichtlich synthetischen Zertifikatbytes; sie ist kein physischer Gerätebericht und beweist keine Zertifikatsvalidierung.

Der neue iOS-Test lädt die alte Datei über DiagnosticStore/HistoryPersistence, prüft stabile ID/Datum, Header/Körper, Fehler und Zertifikatbytes sowie fehlende neuere optionale Felder und speichert/lädt sie erneut. Alle sechs HistoryPersistenceTests bestehen auf dem isolierten iPad, ohne Fehler/Warnungen.

Nur Test-Fixture/-Code und Dokumentation geändert. Der hochgeladene App-Build 41 bleibt unverändert. Dies beweist Schema-Kompatibilität, keine physische TestFlight-Updateinstallation.
