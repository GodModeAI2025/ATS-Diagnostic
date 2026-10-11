# ATSRecording: erster SDK-Baustein

12. Oktober 2026. Eigenständiges Swift-Paket; noch nicht in Build 38 eingebettet.

Fünf kontrollierte Tests bestanden auf macOS: vollständige Antwort bei leerer Vorschau, ursprünglicher Fehler samt Domain/Code, POST-Körper/Header in der vorhandenen Session, Anzahl/kodierte Journalgröße/Leeren und unveränderte erfolgreiche Antwort bei zu kleinem Journal. Die URLProtocol-Testgegenstelle verwendet Foundations task-basierten Pfad einschließlich Request-Stream-Unterstützung. Dies ist Testinfrastruktur, keine bereits fertiggestellte automatische SDK-Aufzeichnung.

Drei Live-Fälle bestanden: example.com HTTP 200 mit 577 vollständigen Antwortbytes und 16 Vorschau-Bytes; expired.badssl.com sowie wrong.host.badssl.com jeweils derselbe NSURLErrorDomain/-1202 wie die direkt aufgerufene Systemsession. Es wird kein bestimmter Zertifikatsgrund allein aus dem Zielnamen abgeleitet. Fehlerkörper, deren Hash und Teilbytezahl bleiben unbekannt.

Xcode-Build für generic/iOS Simulator erfolgreich. SDK-Laufzeit auf iOS, automatische URLProtocol-Aufzeichnung, Streaming/Uploads/Downloads, HAR/App-Import, Verbindungsmetriken, Ereignisse und Präsentationshooks sind noch offen. Die 99 App-Tests und Build-38-iPad-Prüfungen sind separate Nachweise für die App, keine SDK-Geräteprüfung.
