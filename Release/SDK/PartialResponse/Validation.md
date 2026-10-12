# Teilantwort-Import

Die App übernimmt optionale Vollständigkeit und beobachtete Antwortbytes aus HAR. Eine als unvollständig gemeldete Antwort erzwingt unbekannte Gesamtgröße und verwirft einen behaupteten vollständigen Hash. Beobachtete Counts unterhalb der vorhandenen Vorschau werden nicht übernommen. Reexport bewahrt Vollständigkeit/Beobachtung getrennt von der Gesamtgröße.

Die tatsächliche SDK-Fixture enthält HTTP200, drei beobachtete Bytes und Zwei-Byte-Vorschau. Drei neue Import-/Roundtrip-/Widerspruchstests sowie die volle 114-Methoden-App-Suite bestehen ohne Fehler/Warnungen. Ein vorheriger Lauf lieferte alle CONNECT-Payload-Bytes, meldete jedoch beim Abschluss NWError50. Die Echo-Test-Gegenstelle und der große Testclient schließen jetzt erst nach beobachtetem Proxy-Abschluss. Produktions-Proxy und Vollständigkeitsassertionen sind unverändert; der nachfolgende volle Lauf bestand.

Native iPhone-Files-Picker-Prüfung bestanden: History Teilaufnahme/Größe unbekannt/Failures0, Detail HTTP200/Gesamtgröße unbekannt/Laut Export aufgezeichnet3Bytes mit Erklärung und ohne vollständigen Hash, Trustresult unavailable, Map Gesamtgröße unbekannt. GET-Replay bleibt verfügbar und wurde nicht ausgeführt. Screenshots/AX unter Release/Screenshots/Partial-Response-*. Session geschlossen; Screenshot visuell geprüft.

App-Code ist noch nicht in hochgeladenem Build41 enthalten. Apple-Zuordnung bleibt an fehlender Anmeldung offen. Die separate SDK-Testergänzung erzeugt die Fixture; das SDK wird nicht in die App eingebettet.
