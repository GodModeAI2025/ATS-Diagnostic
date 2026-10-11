# Verlauf und Speichergrenze

Für den Folgebuild nach 37: Die gefilterte Verlaufsliste beobachtet die Identitäten der Einträge. Ein neuer Eintrag aktualisiert die Liste auch dann, wenn die Gesamtzahl durch gleichzeitiges Entfernen eines alten Eintrags unverändert bleibt.

Die gespeicherte JSON-Historie ist auf 64 MiB und die gewählte Anzahl begrenzt. Die Berechnung umfasst vollständige JSON-Darstellung, Escape-Zeichen, Base64-Zertifikate, Array-Klammern und Kommas. Der neueste passende Präfix wird erhalten. Die Grenze gilt bei neuen Diagnosen, HAR-Import und Laden. Ein einzelner Eintrag über der Gesamtgrenze wird nicht dauerhaft gespeichert; die aktuelle Diagnose bleibt separat sichtbar. Persistenz erfolgt weiterhin synchron; asynchrone Speicherung bleibt offen.

99 Tests bestanden am 12. Oktober 2026 auf dem isolierten iPhone-Simulator. Vier neue Tests prüfen Anzahl, tatsächliche kodierte Körper-/Zertifikatsgröße, die exakte Array-Grenze und einen zu großen neuesten Eintrag. Die gezielte iPad-UI-Prüfung läuft noch. Diese Änderungen sind nicht im bereits hochgeladenen Build 37 enthalten.
