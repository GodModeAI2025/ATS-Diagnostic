# Systemgestützte Adressauflösung

Neues Werkzeug unter Tools löst Hostname/URL über den Darwin-Systemresolver auf und zeigt numerische IPv4-/IPv6-Adressen, Host, gemessene Dauer und teilbaren Text. Die blockierende Resolverarbeit läuft in einem separaten Task; alle addrinfo-Listen werden freigegeben. Reihenfolge bleibt systembestimmt, doppelte Adressen werden entfernt und maximal64 unterschiedliche Adressen dargestellt. Eingegebener Zieltext wird vor Taskbeginn festgehalten.

Drei neue Tests prüfen reale numerische IPv4-/IPv6-Systemauflösung und frühe Ablehnung von Credentials-/Nicht-Netzwerk-URLs. Die volle121-Methoden-App-Suite besteht ohne Fehler/Warnungen. Native iPhone-Prüfung bestanden: IPv4 127.0.0.1, IPv6 ::1 und example.com mit tatsächlichen zwei IPv4-/zwei IPv6-Adressen in0,059s. Ergebnisse vollständig scrollbar/lesbar, Fertig dismissiert Tastatur, Teilen vorhanden und nicht ausgelöst. Systemresolver-Erklärung sichtbar; Session geschlossen. PNG/AX unter Release/Screenshots/DNS-Lookup-*.

Das ist Systemadressauflösung, keine autoritative DNS-RR/TTL/DNSSEC- oder Reverse-DNS-Analyse. UDP/DNS-Capture, Custom-DNS und volle historische Diagnoseparität bleiben offen. Nicht in hochgeladenem Build43 enthalten.
