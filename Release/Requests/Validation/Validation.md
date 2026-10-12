# HTTP-Feldvalidierung

Methoden und Header-Namen werden vor URLRequest-Settern als nicht leere HTTP-Tokens geprüft. Header-Werte dürfen keine unzulässigen Steuerzeichen/Zeilenumbrüche enthalten. Der Editor verarbeitet gültige Windows-Zeilenenden, eigene Methoden und UTF-8-Werte. Ungültige Felder erhalten konkrete deutsche Meldungen vor Netzwerkausführung.

Importierte ungültige Anfragefelder bleiben lesbar, deaktivieren jedoch Replay/cURL. Der Formatfehler wird unabhängig von einem fehlenden Anfragekörper erklärt. Vier neue Tests und die volle 118-Methoden-App-Suite bestehen auf dem isolierten iPad ohne Fehler/Warnungen.

Native Files-Picker-/Disabled-Button-Prüfung läuft noch. Diese Änderung ist nicht in hochgeladenem Build42 enthalten.
