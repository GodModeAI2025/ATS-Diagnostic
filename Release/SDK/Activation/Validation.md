# Optionale Präsentationsaktivierung

13 kontrollierte SDK-Tests bestanden auf macOS und auf dem isolierten iPhone-Simulator; zwei opt-in Live-Testmethoden wurden in diesen Läufen übersprungen. Drei neue Tests prüfen standardmäßig deaktivierte Aktivierung, korrekten Trigger/erneutes Ausschalten und fehlenden Handler. UIKit-RecordingWindow kompiliert für iOS.

Der eigene UIKit-Beispielhost mit WindowScene, RecordingWindow, eigener Aktion und opt-in Switch baut erfolgreich auf dem isolierten iPad. Die tatsächliche Custom-Präsentation wurde im iPad-Simulator geprüft: standardmäßig deaktiviert bleibt die Aktion ohne Präsentation; nach Einschalten öffnet sich „Diagnose geöffnet“ mit „Eigene Aktion“. Screenshots und UI-Hierarchie liegen unter Release/Screenshots/SDK-Activation-*. Die echte Shake-Prüfung bleibt unverifiziert: Die gelesenen Device- und Controls-Menüs von Xcode 27 Device Hub boten keinen Shake-Eintrag; der Geräte-MCP stellt keinen dokumentierten Shake-Befehl bereit. Es wurde keine Methoden-Injektion verwendet. Erneutes Abschalten nach der Präsentation konnte wegen einer bereits geschlossenen Gerätesession nicht mehr im UI bestätigt werden; die API-Tests decken das Abschalten ab.

Die integrierende App entscheidet über den präsentierten Inhalt. Eine eingeschaltete Shake-Aktion wird konsumiert; ohne Freigabe/Handler wird UIKit normal aufgerufen. Keine globalen Methodenänderungen. Der Aktivierungscontroller muss vom Host gehalten werden; das Window hält ihn schwach. Dies ersetzt noch keine vollständige SDK-Diagnoseoberfläche und vervollständigt keine automatische Aufzeichnung.

Die hochgeladene App 2.0 (39) bleibt unverändert.
