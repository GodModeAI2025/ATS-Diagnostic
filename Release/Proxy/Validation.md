# Lokaler Proxy: Nachweis und verbleibender Umfang

Stand: 12. Oktober 2026. Native App, isolierte iPhone/iPad-Simulatoren mit iOS27.0.

95 aktuelle Tests bestanden ohne Fehler. Reale Loopback-Gegenstellen prüfen HTTP-Weiterleitung, korrigierten Host und entfernte Proxy-Zugangsdaten, normalisierte Content-Length, vollständige POST-Körper,512KiB bidirektionale CONNECT-Daten, Client- und Server-Halbschluss, Upgrade101, abgewiesenes mehrdeutiges Framing, Selbstschleife und Leerlauf-Abbruch.

Drei Live-HTTPS-Anfragen laufen mit einer URLSession über den tatsächlichen lokalen CONNECT-Proxy; Fallback ist deaktiviert und Aufzeichnungen des Tunnels werden zusätzlich verlangt. example.com:HTTP200/Systemvertrauen erfolgreich. expired.badssl.com und wrong.host.badssl.com:Verbindung mit tatsächlichem Ablauf-/Hostnamenbefund abgelehnt. Tunnel-Bytezahlen sind positiv; Inhaltsvorschauen bleiben leer. Es wird keine Zertifikatsprüfung umgangen.

Drei weitere Live-Fälle prüfen direkte HTTPS-Weiterleitung: example.com liefert HTTP 200 mit TLS-Metadaten; abgelaufene und zum Hostnamen unpassende Zertifikate werden mit HTTP 502 und dem tatsächlichen Zertifikatsbefund abgewiesen. Diese Fehler werden unmittelbar gemeldet, statt erst als Leerlauf-Zeitüberschreitung zu erscheinen. Insgesamt sechs Live-Fälle bestanden.

Die Oberfläche wurde auf iPhone und iPad einschließlich Querformat und großer Schrift geprüft. CONNECT-Details kennzeichnen verschlüsselte Inhalte ausdrücklich; eine separate Client-Diagnose zeigt die Zertifikatskette. Beim Hintergrundwechsel wurde der geschlossene Listener durch einen abgewiesenen Verbindungsversuch nachgewiesen.

Der Listener bindet ausschließlich127.0.0.1. Acht gleichzeitige Verbindungen,16MiB Anfragekörper,64KiB Vorschau je Richtung;60s Leerlauf und1h Gesamtzeitlimit. HTTP-Vorschauen enthalten Drahtdaten, gegebenenfalls Komprimierung und Chunk-Rahmen. CONNECT liefert ausschließlich Ziel und Bytezahlen. Aufzeichnungen bleiben innerhalb der App-Sitzung und können als JSON exportiert werden. Export-Encoding wird erst beim Teilen ausgelöst.

Die App stoppt den Proxy beim Wechsel in den Hintergrund. Dies ist noch kein geräteweiter Hintergrund-Capture: VPN/Packet-Tunnel, MITM/CA-Verwaltung, PCAP, vollständige Protokolldekodierung, Regeln und Entwickler-SDK bleiben offen. Plaintext-HTTP nutzt bewusste TCP-Weiterleitung im Proxy; die manuellen Inspect/Requests behalten ATS bei.

Die Aufnahme ist ein tatsächlicher erster Proxy-Pfad. Vollständige Vereinigung der historischen Funktionen wird dadurch nicht behauptet.

Beim CONNECT-Abschluss werden beide abgeschlossenen Schreibrichtungen berücksichtigt, bevor die Verbindungen beendet werden. Nach dieser Korrektur bestanden erneut 95 App-Tests und sechs Live-Fälle. Build 2.0 (37) wurde am 12. Oktober 2026 um 00:19:47 CEST erfolgreich hochgeladen. Verarbeitung und Gruppenzuordnung sind noch nicht im Portal bestätigt; die Browser-Sitzung verlangt eine erneute Anmeldung.
