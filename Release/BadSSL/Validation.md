# badssl-Prüfung mit ATS Diagnostic

Stand: 11. Oktober 2026. Native App auf isoliertem iPhone-Simulator, iOS 27.0. Die Live-Test-Suite verwendet denselben DiagnosticEngine und dieselben aktivierten Systemvertrauens- und ATS-Regeln wie die Anwendung. Ergebnis: 73 Ziele ausgeführt, Live-Integrationstest erfolgreich. Zusätzlich 79 Unit-Tests ohne Fehler.

44 Verbindungen wurden abgelehnt, 27 lieferten HTTP 200 und 2 HTTP 400 mit tatsächlich angefordertem Client-Zertifikat. Eine empfangene Antwort bedeutet nicht automatisch eine sichere Serverkonfiguration.

Bei revoked.badssl.com ließ die Standard-Systemprüfung HTTP 200 zu. Die zusätzliche Prüfung bestätigte den Widerruf anhand einer aktuellen, passend zugeordneten und kryptografisch verifizierten Aussteller-CRL. Beide Ergebnisse werden getrennt angezeigt. Nicht unterstützte oder nicht belegbare Sperrprüfungen bleiben unbekannt.

Fehlertexte folgen den tatsächlichen Systemfehlern, nicht dem Testnamen. Einige ältere Testzertifikate sind inzwischen abgelaufen. Ein unspezifischer Handshakefehler wird nicht als nachgewiesener Cipher- oder Schlüsselgrößenfehler ausgegeben.

Browser-Mixed-Content, dynamische Skripte, Browser-HSTS-Preload und UI-Täuschung werden nicht vollständig nachgestellt. Die App prüft diese Hauptaufrufe und gegebenenfalls statische HTML-Verweise. Der Katalog enthält auch vier von badssl als nicht mehr aktuell gekennzeichnete Ziele. Cipher-Enumeration und vollständige Schwachstellenprüfung sind dadurch nicht nachgewiesen.

## Beobachtete Ergebnisse

| Ziel | Tatsächlicher Befund |
| --- | --- |
| `badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `expired.badssl.com` | Verbindung abgelehnt Zertifikat abgelaufen |
| `wrong.host.badssl.com` | Verbindung abgelehnt Zertifikat passt nicht zum Hostnamen |
| `self-signed.badssl.com` | Verbindung abgelehnt Zertifikatskette nicht vertrauenswürdig |
| `untrusted-root.badssl.com` | Verbindung abgelehnt Zertifikatskette nicht vertrauenswürdig |
| `revoked.badssl.com` | Antwort empfangen Zertifikat widerrufen |
| `pinning-test.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `no-common-name.badssl.com` | Verbindung abgelehnt Zertifikat abgelaufen |
| `no-subject.badssl.com` | Verbindung abgelehnt Zertifikat abgelaufen |
| `incomplete-chain.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `sha256.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `sha384.badssl.com` | Verbindung abgelehnt Zertifikat abgelaufen |
| `sha512.badssl.com` | Verbindung abgelehnt Zertifikat abgelaufen |
| `1000-sans.badssl.com` | Verbindung abgelehnt Zertifikat abgelaufen |
| `10000-sans.badssl.com` | Verbindung abgelehnt TLS-Parameter nicht akzeptiert |
| `ecc256.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `ecc384.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `rsa2048.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `rsa4096.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `rsa8192.badssl.com` | Verbindung abgelehnt Zertifikat abgelaufen |
| `extended-validation.badssl.com` | Verbindung abgelehnt Zertifikat abgelaufen |
| `client.badssl.com` | HTTP-Ablehnung Client-Zertifikat benötigt |
| `client-cert-missing.badssl.com` | HTTP-Ablehnung Client-Zertifikat benötigt |
| `mixed-script.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `very.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `mixed.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `mixed-favicon.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `mixed-form.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `http.badssl.com` | Verbindung abgelehnt Unverschlüsseltes HTTP durch ATS blockiert |
| `http-textarea.badssl.com` | Verbindung abgelehnt Unverschlüsseltes HTTP durch ATS blockiert |
| `http-password.badssl.com` | Verbindung abgelehnt Unverschlüsseltes HTTP durch ATS blockiert |
| `http-login.badssl.com` | Verbindung abgelehnt Unverschlüsseltes HTTP durch ATS blockiert |
| `http-dynamic-login.badssl.com` | Verbindung abgelehnt Unverschlüsseltes HTTP durch ATS blockiert |
| `http-credit-card.badssl.com` | Verbindung abgelehnt Unverschlüsseltes HTTP durch ATS blockiert |
| `cbc.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `rc4-md5.badssl.com` | Verbindung abgelehnt TLS-Verbindung ohne Abschluss geschlossen |
| `rc4.badssl.com` | Verbindung abgelehnt TLS-Peer meldet Handshakefehler |
| `3des.badssl.com` | Verbindung abgelehnt TLS-Peer meldet Handshakefehler |
| `null.badssl.com` | Verbindung abgelehnt TLS-Peer meldet Handshakefehler |
| `mozilla-old.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `mozilla-intermediate.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `mozilla-modern.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `dh480.badssl.com` | Verbindung abgelehnt TLS-Peer meldet Handshakefehler |
| `dh512.badssl.com` | Verbindung abgelehnt TLS-Peer meldet Handshakefehler |
| `dh1024.badssl.com` | Verbindung abgelehnt TLS-Peer meldet Handshakefehler |
| `dh2048.badssl.com` | Verbindung abgelehnt TLS-Peer meldet Handshakefehler |
| `dh-small-subgroup.badssl.com` | Verbindung abgelehnt TLS-Peer meldet Handshakefehler |
| `dh-composite.badssl.com` | Verbindung abgelehnt TLS-Peer meldet Handshakefehler |
| `static-rsa.badssl.com` | Verbindung abgelehnt TLS-Peer meldet Handshakefehler |
| `tls-v1-0.badssl.com:1010` | Verbindung abgelehnt TLS-Version nicht akzeptiert |
| `tls-v1-1.badssl.com:1011` | Verbindung abgelehnt TLS-Version nicht akzeptiert |
| `tls-v1-2.badssl.com:1012` | Antwort empfangen HTTP 200 empfangen |
| `no-sct.badssl.com` | Verbindung abgelehnt Zertifikat abgelaufen |
| `hsts.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `upgrade.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `preloaded-hsts.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `subdomain.preloaded-hsts.badssl.com` | Verbindung abgelehnt Zertifikat passt nicht zum Hostnamen |
| `https-everywhere.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `spoofed-favicon.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `lock-title.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `long-extended-subdomain-name-containing-many-letters-and-dashes.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `longextendedsubdomainnamewithoutdashesinordertotestwordwrapping.badssl.com` | Antwort empfangen HTTP 200 empfangen |
| `superfish.badssl.com` | Verbindung abgelehnt Zertifikatskette nicht vertrauenswürdig |
| `edellroot.badssl.com` | Verbindung abgelehnt Zertifikatskette nicht vertrauenswürdig |
| `dsdtestprovider.badssl.com` | Verbindung abgelehnt Zertifikatskette nicht vertrauenswürdig |
| `preact-cli.badssl.com` | Verbindung abgelehnt Zertifikatskette nicht vertrauenswürdig |
| `webpack-dev-server.badssl.com` | Verbindung abgelehnt Zertifikatskette nicht vertrauenswürdig |
| `captive-portal.badssl.com` | Verbindung abgelehnt Zertifikat passt nicht zum Hostnamen |
| `mitm-software.badssl.com` | Verbindung abgelehnt Zertifikatskette nicht vertrauenswürdig |
| `sha1-2016.badssl.com` | Verbindung abgelehnt Zertifikatskette nicht vertrauenswürdig |
| `sha1-2017.badssl.com` | Verbindung abgelehnt Zertifikatskette nicht vertrauenswürdig |
| `sha1-intermediate.badssl.com` | Verbindung abgelehnt Zertifikatskette nicht vertrauenswürdig |
| `invalid-expected-sct.badssl.com` | Verbindung abgelehnt Zertifikatskette nicht vertrauenswürdig |
