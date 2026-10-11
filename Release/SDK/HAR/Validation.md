# SDK → HAR → App

Die SDK-Dateien unter Tests/Fixtures wurden vom tatsächlich ausgeführten Swift-Paket erzeugt: öffentliche example.com-Antwort, zwei systemseitig abgelehnte badssl-Verbindungen und ein kontrollierter POST mit gekürzter Vorschau.

SDK: sechs kontrollierte Tests und drei Live-Fälle bestanden. Die zurückgegebene TLS-Fehlermeldung und der aufgezeichnete Domain/Code stimmen innerhalb desselben Aufrufs überein. Getrennte Systemverbindungen können unterschiedliche NSError-Verpackungen (-1200/-1202) liefern; daraus wird keine Änderung durch das SDK abgeleitet. Der HAR-Exporter kompiliert für iOS Simulator.

App: vollständiger Lauf mit 103 Tests bestanden. Nach den weiteren Korrekturen zu unbekannter Protokollversion und nicht durch Importmetadaten freigebbarem fehlendem Anfragekörper bestanden acht gezielte HAR-Tests. Tests prüfen tatsächliche SDK-Dateien, Base64-Vorschau, gemeldeten vollständigen Hash, ursprüngliche Fehler, unbekannte Bytezahl, fehlende Systemvertrauensbewertung und unverändert gesperrtes Replay nach App-Reexport.

Importierte Aufzeichnungen haben eine sichtbare Herkunft. Hashwerte gelten als vom Import gemeldet, nicht als neu geprüft. Nicht vollständig wiederholbare Anfragekörper deaktivieren Replay und cURL. Negative/unbekannte HAR-Antwortgrößen bleiben als unbekannt gekennzeichnet.

Die gezielte iPad-Prüfung über den echten Dateiauswahldialog läuft. POST-Import, 13 Originalbytes, Vorschau „com“, Herkunft und deaktiviertes Replay/cURL sind bereits bestätigt. Beispiel-Hash und Zertifikatsfehler-Import bleiben im laufenden UI-Check. Diese Änderungen sind für den Folgebuild nach 38; sie sind nicht im hochgeladenen Build 38 enthalten.

Finaler App-Stand: 105 Tests bestanden, einschließlich Replay-Schutz und Prüfsummen, die aus der Vierergruppen-Darstellung kopiert werden. Die echte iPad-Import-UI bestand POST/Preview/Replay-Sperre, Beispiel-Hash-Herkunft und gespeicherten Zertifikatsfehler ohne neue Vertrauensbewertung. Der abschließende iPad-Sichtcheck bestand: gruppierte SHA-Darstellung ohne Trennstrich, Herkunft/nicht erneut geprüft und Protocol Not reported auch bei einem älteren importierten Eintrag. Alle Testsitzungen geschlossen. Beleg: Screenshots/SDK-HAR-Example-Final.*.
