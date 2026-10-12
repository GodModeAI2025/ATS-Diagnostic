# Zusammengefasste Verlaufsschreibvorgänge

DiagnosticStore hält einen laufenden Schreibvorgang und höchstens den neuesten ausstehenden Snapshot. Schnelle Import-/Clear-Aufträge erzeugen keine unbeschränkte Schreibwarteschlange. flushHistory wartet auf den aktuellen Worker einschließlich nachgereichter Änderungen. Private Worker-Zustände werden nicht für die SwiftUI-Beobachtung instrumentiert.

Der Worker hält eine benannte UIKit-Hintergrundaufgabe bis zum Abschluss; bei Ablauf wird die gewährte Aufgabe beendet. Der Scene-Hintergrundwechsel fordert den Flush an. Dies nutzt die vom System gewährte Zeit und beweist keinen Abschluss bei erzwungenem Beenden oder abgelaufener Systemfrist.

Der zusätzliche Store-Test importiert 20 Berichte, leert sofort, wartet auf den Flush und lädt den Verlauf neu: leer. Die endgültige volle iPad-Suite besteht mit 108 Testmethoden (109 parametrisierten Ausführungen), ohne Fehler/Warnungen. Im ersten Lauf trat erneut der bestehende Loopback-Fehler Network is down auf; der vollständige Wiederholungslauf bestand. Dieser intermittierende Proxy-Test benötigt weitere Untersuchung.

Die tatsächliche Simulator-Neustart-/Hintergrundprüfung läuft noch. Initiales Laden und Retention bleiben synchron. Dieser neue App-Code ist noch nicht in hochgeladenem Build 39 enthalten.
