# macOS Store copy — draft for build 58

**Status:** Draft pending final UI QA and Mac screenshots. Universal Mac Catalyst build 58 (source `f7951f5`) was archived, uploaded successfully, processed, and assigned to Mark – Intern TestFlight; it is **Im Test** with only `mark_zimmermann@mac.com` invited. The 161 Mac tests and 8 iOS SignedCRL tests passed (`work/Mac58-Tests-Final.log`, `work/Mac58-iOS-CRL.log`). The English/German macOS 2.0.1 metadata and ATS/sandbox explanations are saved in App Store Connect for the existing app record **1297164068** / bundle **com.mobilebox.atsdiagnostic**, with build 58 selected. The version has **not** been submitted to the Store. Visual QA and Mac screenshots remain outstanding; the current CUA `getApp` call is hanging and another XcodeRun attempt is in progress. Historical feature parity was explicitly closed by the user. iOS 2.0.1 (56) is **Ready for Distribution** according to the portal; this does not verify installation on a device.

## Description (DE)

Untersuche HTTP-, TLS- und Zertifikatsverbindungen auf dem Mac. Wähle einen Server im Internet oder im lokalen Netzwerk aus und sieh Zertifikatsaussteller, Zertifikatskette, Gültigkeit, Fingerabdrücke und die Ergebnisse der Apple-Systemvertrauensprüfung. Verständliche Erläuterungen ergänzen die ursprünglichen Verbindungsfehler.

- Vergleiche TLS-Versionsprüfungen mit der ausgehandelten Verbindung.
- Prüfe HTTP-Header, HSTS, Weiterleitungen und Verbindungszeiten.
- Erstelle Anfragen und untersuche URL-Abfrageparameter.
- Speichere den Prüfverlauf lokal und exportiere ausgewählte Berichte als HAR oder JSON.
- Nutze IPv4-/IPv6-Vorwärts- und Rückwärtssuche sowie SHA-256-Prüfsummen für Downloads.
- Untersuche Certificate-Transparency-Zeitstempel und datierte Root-Store-Verzeichnisse.

HTTP und ältere TLS-Konfigurationen lassen sich zu Diagnosezwecken prüfen. HTTPS-Zertifikate werden weiterhin bewertet; ungültige Zertifikate werden als Fehler angezeigt. Die Ergebnisse beschreiben die beobachtete Verbindung und bestätigen nicht pauschal die Einhaltung aller ATS-Anforderungen. Ein Eintrag im Root Store ist nicht gleichbedeutend mit Systemvertrauen. SCT-Signaturen und Log-Inklusion werden nicht unabhängig verifiziert.

Die App benötigt kein Konto. Der Verlauf bleibt auf deinem Mac. Dateien werden nur über eine vom Nutzer gewählte Datei geöffnet oder exportiert. Die App erfasst keinen Netzwerkverkehr anderer Apps und installiert weder VPN noch Root-Zertifikat. Für ausgehende Verbindungen gelten die macOS-App-Sandbox und die ausgewiesenen ATS-Diagnoseausnahmen; ein Proxy ist nicht enthalten.

## Description (EN)

Inspect HTTP, TLS and certificate connections on your Mac. Choose a server on the Internet or your local network and review certificate issuers, chains, validity, fingerprints and Apple system-trust results. Clear explanations accompany the original connection errors.

- Compare TLS-version probes with the negotiated connection.
- Examine HTTP headers, HSTS, redirects and connection timings.
- Build requests and inspect URL query parameters.
- Keep inspection history locally and export selected reports as HAR or JSON.
- Use IPv4/IPv6 forward and reverse lookup and SHA-256 download checks.
- Explore Certificate Transparency timestamps and dated root-store directories.

HTTP and legacy TLS configurations can be tested for diagnosis. HTTPS certificates are still evaluated; invalid certificates are reported as failures. Results describe the observed connection and do not certify every ATS requirement. Root-store membership is separate from platform trust. SCT signatures and log inclusion are not independently verified.

No account is required. History stays on your Mac. Files are opened or exported only through user-selected file access. The app does not capture traffic from other apps and does not install a VPN or root certificate. Outbound connections use the macOS App Sandbox and the stated ATS diagnostic exceptions; no proxy is included.

## What's New (DE)

ATS Diagnostic ist jetzt auch für macOS verfügbar. Die Mac-Catalyst-Version bringt HTTP-/TLS- und Zertifikatsdiagnosen in ein Mac-Fenster. Dateien werden gezielt vom Nutzer ausgewählt; ein Proxy ist nicht enthalten.

## What's New (EN)

ATS Diagnostic is now available for macOS. The Mac Catalyst version brings HTTP/TLS and certificate diagnostics to a Mac window. File access is user-selected; no proxy is included.

## App Review Notes (DE)

ATS Diagnostic ist ein nutzergesteuertes HTTP-, TLS- und Zertifikatsdiagnosewerkzeug in einer Mac-Catalyst-App. Diese Version verwendet die macOS-App-Sandbox mit ausgehendem Netzwerkzugriff. Dateizugriff erfolgt nur auf vom Nutzer ausgewählte Dateien. Es gibt keinen Proxy, Listener für andere Geräte, VPN, TLS-Abfangfunktion oder installierte Root-CA.

**ATS-Ausnahme:** `NSAllowsArbitraryLoads` wird für die Diagnose beliebiger, vom Nutzer ausgewählter HTTP-Endpunkte und älterer TLS-Konfigurationen benötigt. Ziele können lokale Geräte oder Server Dritter sein und lassen sich nicht vorab in `NSExceptionDomains` auflisten. Die Ausnahme dient der Messung; sie besagt nicht, dass ein Ziel sicher ist oder eine andere App ATS-konform arbeitet. Die standardmäßige HTTPS-Zertifikatsprüfung einschließlich Kette, Hostname und Gültigkeit bleibt aktiv. Ungültige Zertifikate werden mit Fehler und Originaldetails angezeigt.

**Lokales Netzwerk:** Der Nutzer kann einen lokalen Host oder eine IP-Adresse zur Prüfung eingeben. Der Systemdialog erläutert den Zugriff auf vom Nutzer ausgewählte lokale Geräte und Server. Es gibt keine Bonjour-Suche oder Multicast-Erkennung. Kein Network-Extension-Entitlement wird verwendet.

**Prüfschritte:** `http://example.com` in „Inspect“ eingeben und ausführen, um eine HTTP-Verbindung zu prüfen. `https://expired.badssl.com` eingeben, um einen abgelaufenen Zertifikatsfehler zu sehen. Ein Ergebnis öffnen, um Aussteller, Kette, Header und TLS-Versuchsdetails anzuzeigen. Für den lokalen Netzwerkzugriff einen erreichbaren lokalen Hostnamen oder eine IP-Adresse verwenden. Verfügbarkeit und ausgehandelte TLS-Version hängen von Systemunterstützung und Server ab; Fehler bleiben sichtbar.

## App Review Notes (EN)

ATS Diagnostic is a user-directed HTTP, TLS and certificate diagnostic utility in a Mac Catalyst app. This version uses the macOS App Sandbox with outbound network access. Files are accessed only when selected by the user. There is no proxy, listener for other devices, VPN, TLS interception or installed root CA.

**ATS exception:** `NSAllowsArbitraryLoads` is required to diagnose arbitrary user-selected HTTP endpoints and legacy TLS configurations. Targets may be local devices or third-party servers and cannot be pre-enumerated in `NSExceptionDomains`. The exception enables measurement; it does not say a target is secure or that another app complies with ATS. Default HTTPS certificate evaluation, including chain, hostname and validity checks, remains enabled. Invalid certificates are shown with an error and original details.

**Local network:** The user can enter a local host or IP address to inspect it. The system prompt explains access to user-selected local devices and servers. The app performs no Bonjour browsing or multicast discovery. No Network Extension entitlement is used.

**Review steps:** Enter and run `http://example.com` in Inspect to test an HTTP connection. Enter `https://expired.badssl.com` to see an expired-certificate failure. Open a result to review issuer, chain, headers and TLS-probe details. To exercise local-network access, enter a reachable local hostname or IP address. Availability and negotiated TLS versions depend on system support and the server; failures remain visible.
