# Asynchrones Initialladen

HistoryPersistence liest, dekodiert und begrenzt den gespeicherten Verlauf außerhalb des UI-Actors. DiagnosticStore veröffentlicht den geladenen Stand auf dem MainActor. Import, Diagnose, Löschen und Flush warten auf den Initialload, sodass ein späteres Ladeergebnis keine neue Mutation überschreibt. History zeigt währenddessen einen Ladehinweis im normalen Listenfluss. Kleine Optionen-/Settings-Dateien werden weiterhin synchron geladen.

Zwei neue Regressionstests prüfen sofortigen Import mit vorhandener Historie und sofortiges Clear vor Abschluss des Initialloads. Der endgültige vollständige iPad-Lauf besteht mit 110 Testmethoden, ohne Fehler oder Warnungen. Im ersten Gesamtlauf trat der bekannte intermittierende große CONNECT-Testfehler erneut auf. Neun gezielte Proxyfälle sowie der nachfolgende volle Lauf bestanden. Der Testclient meldet bei weiteren Transportfehlern nun die Phase connect/send/receive und behält Domain/Code/UnderlyingError. Die konkrete Ursache bleibt unbewiesen; Fehler werden nicht unterdrückt.

Native iPhone-Neustart-/Clear-Prüfung läuft noch. Diese Änderung ist noch nicht im hochgeladenen Build 40 enthalten.
