# Native Streaming-HTTPS-Prüfung

macOS: Der gesamte SDK-Lauf mit Live-Freigabe besteht (27 Testmethoden, keine Fehler). iOS 27.0: vier Live-Testmethoden mit sechs HTTPS-Fällen bestehen auf dem isolierten iPad, ohne Fehler, Überspringen oder Laufzeitwarnungen. Drei Fälle betreffen data(for:), drei die neue Streaming-API.

Streaming example.com liefert HTTP 200 und 577 Bytes; der vollständige Hash entspricht dem unabhängig aus allen gelieferten Bytes berechneten SHA-256. Die gespeicherte Vorschau enthält nur 16 Bytes. Ein MainActor-Konsument wurde verwendet.

expired.badssl.com und wrong.host.badssl.com werden sowohl von der normalen URLSession.bytes-API als auch vom Recorder durch Systemprüfung abgelehnt. Die tatsächlich zurückgegebenen NSURLErrorDomain/-1202-Fehler entsprechen jeweils dem gespeicherten Fehler; Antwortgröße, Status und Hash bleiben unbekannt. Separate Verbindungen werden nur auf Zertifikatsfehlerfamilie verglichen, weil Foundation unterschiedlich einwickeln kann. Keine Trust-Handler/-Ausnahmen installiert.

Dieser Nachweis betrifft Simulator/macOS und die genannten HTTPS-Fälle, keine physische Geräteinstallation oder vollständige historische SDK-Parität. Automatische URLProtocol-Erfassung/Abschlussbeobachtung abgebrochener Konsumenten bleiben offen. App-Build 41 ist unverändert.
