# Optionale Präsentationsaktivierung

13 kontrollierte SDK-Tests bestanden auf macOS und auf dem isolierten iPhone-Simulator; zwei opt-in Live-Testmethoden wurden in diesen Läufen übersprungen. Drei neue Tests prüfen standardmäßig deaktivierte Aktivierung, korrekten Trigger/erneutes Ausschalten und fehlenden Handler. UIKit-RecordingWindow kompiliert für iOS.

Der eigene UIKit-Beispielhost mit WindowScene, RecordingWindow, eigener Aktion und opt-in Switch baut erfolgreich auf dem isolierten iPad. Die tatsächliche Präsentations- und Simulator-Shake-Prüfung ist noch in Arbeit. Das ist bisher keine Gerätebestätigung des Motion-Delivery-Pfads.

Die integrierende App entscheidet über den präsentierten Inhalt. Eine eingeschaltete Shake-Aktion wird konsumiert; ohne Freigabe/Handler wird UIKit normal aufgerufen. Keine globalen Methodenänderungen. Der Aktivierungscontroller muss vom Host gehalten werden; das Window hält ihn schwach. Dies ersetzt noch keine vollständige SDK-Diagnoseoberfläche und vervollständigt keine automatische Aufzeichnung.

Die hochgeladene App 2.0 (39) bleibt unverändert.
