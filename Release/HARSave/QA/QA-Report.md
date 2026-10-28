# Direkter HAR-Speicherexport – native Mac-QA

Datum: 2026-10-28. Frischer Start des regulären Debug-Builds am bekannten Xcode-DerivedData-Pfad; native App-Inventur zeigte vorher keine laufende ATS-Instanz. Keine parallelen Builds/Tests. Ausschließlich echte native UI-Aktionen; keine synthetisch erzeugten HAR-Dateien.

## Ergebnisse

| Fall | Ergebnis | Nachweis |
|---|---|---|
| Normalfenster → HAR speichern unter | Bestanden: Sichern aktiv, direkt echte ATS-Normal.har geschrieben | 02-/03-AX, 03-Normal-Save.jpg, ATS-Normal.har |
| Vollbild → direkt speichern | Bestanden: Sichern aktiv, echte Datei geschrieben | 04-Fullscreen-Saved.jpg/AX; 06-Fullscreen-Mode-AX.txt bestätigt Vollbildmodus aus |
| Unicode-Dateiname | Bestanden: ATS-Vollbild-Prüfung-äöü-東京.har; macOS-Dateiname in kanonisch zerlegter Unicode-Form | echte Datei im selben Ordner |
| Vollbild Abbrechen / Wiederöffnen | Bestanden: Name Darf-nicht-entstehen vergeben, Abbrechen; keine solche Datei vorhanden; anschließend wieder aktiver Dialog | Aktionsprotokoll der CUA-Sitzung |
| Bestehende Datei: Abbrechen | Bestanden: native Ersetzen-Frage; Abbrechen lässt Bytes UND mtime unverändert | 05-Replace-Confirmation.jpg/AX |
| Bestehende Datei: Ersetzen | Bestanden: erneut Sichern/Ersetzen; mtime erhöht, resultierende Datei weiterhin valides HAR mit101 Einträgen | ATS-Normal.har; direkte Dateistat-Prüfung |
| Rückkehr Normalfenster / Wiederöffnen / Abbrechen | Bestanden: aktiver Dialog, kontrolliert abgebrochen | 07-Normal-Reopen-AX.txt,08-Final-History-AX.txt |
| Historie unverändert | 101 Einträge und19 Fehler vorher und nachher | 01-Baseline-AX.txt,04-Fullscreen-Saved-AX.txt,08-Final-History-AX.txt |

## Dateiinhalt

Beide Exporte: HAR1.2,101 Einträge,371157 Byte. Vollbilddatei byteidentisch zur Normaldatei. SHA256: 763e6d018f956b0dd7e195ca216ebc8d446e6be2136c6976da2973a14c2286ef. Dateiendung korrekt .har, kein .json-Anhang. Ersetzen der eigenen QA-Datei war bewusst Teil des Tests; keine vorhandenen Nutzerdateien ersetzt oder Historie gelöscht.

## Unabhängige Layout-Beobachtung

Im Vollbild-Verlauf bricht „Fehlgeschlagen“ in der schmalen Statusspalte stark um (04-Fullscreen-Saved.jpg). Bestehendes Layoutthema, unabhängig vom funktional bestandenen HAR-Speicherexport; hier nicht verändert.

## Automationshinweis

Beim abschließenden normalen Abbruch änderten neu angelegte AX-Evidenzdateien die Zeilenindizes des Dateidialogs. Ein veralteter Index öffnete daher einmal das Ansichtsmenü. Menü mit Escape geschlossen, frischen AX-Zustand gelesen und den tatsächlichen Abbrechen-Button geklickt. Keine Datei gespeichert oder Ansicht geändert; kein Produktdefekt.

## Grenzen

Nur HAR-Speicherpfad dieser lokalen Mac-App geprüft; keine neuen Store-Aktionen, kein erneuter Import (vorheriger separater Mac61-HAR-Rundlauf bereits dokumentiert).
