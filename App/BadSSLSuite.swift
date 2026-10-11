import Foundation
import Observation

struct BadSSLCase: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let url: String
    let category: String
    static let catalog: [Self] = Bundle.main.url(forResource: "BadSSLCatalog", withExtension: "json").flatMap { try? JSONDecoder().decode([Self].self,from: Data(contentsOf: $0)) } ?? []
    var scopeNote: String {
        if category == "Mixed Content" { return "Die App prüft den Hauptaufruf und HTTP-Verweise im empfangenen HTML. Sie führt keine Skripte aus und bildet keine Browser-Seite nach. Dynamisch erzeugte Inhalte und Browser-Blocking sind damit nicht vollständig geprüft." }
        if category == "HTTP" { return "HTTP ist unverschlüsselt. Apples ATS-Richtlinie bleibt aktiviert; eine Blockierung ist der beobachtete Schutz der App." }
        if category == "UI" { return "Die App zeigt den aufgerufenen Host statt eines vom Server gewählten Browser-Titels oder Favicons. Browser-Täuschung wird nicht nachgestellt." }
        if category == "Upgrade" { return "HSTS-Header und die tatsächliche Ziel-URL können beobachtet werden. Browser-Preload-Listen, HTTPS-Everywhere und Browser-Upgrades sind dadurch nicht vollständig geprüft." }
        if category == "Defunct" { return "badssl kennzeichnet dieses Ziel als nicht mehr aktuell. Ein heutiger Fehler kann von der früher vorgesehenen Testursache abweichen." }
        if id == "pinning-test.badssl.com" { return "Diese App verwendet die Systemprüfung, aber für diesen Host keine festgelegten Zertifikat-Pins. Ein erfolgreicher Aufruf belegt deshalb keine Pinning-Prüfung." }
        if id == "revoked.badssl.com" { return "Systemvertrauen und eine ausdrücklich bestätigte Sperrprüfung werden getrennt dargestellt. Eine erreichbare Antwort ohne Sperrnachweis ist kein Nachweis, dass das Zertifikat nicht widerrufen ist." }
        if id == "incomplete-chain.badssl.com" { return "Das System kann fehlende Zwischenzertifikate nachladen. Eine erfolgreiche Systemprüfung beweist nicht, dass der Server eine vollständige Kette gesendet hat." }
        if id == "no-common-name.badssl.com" || id == "no-subject.badssl.com" { return "Fehlende Subject-Angaben allein beweisen keinen Hostnamenfehler. Die Systemprüfung berücksichtigt auch die Subject Alternative Names." }
        if category == "Cipher Suite" || category == "Key Exchange" || category == "Protocol" { return "Dieser Durchlauf beobachtet den Verbindungsversuch unseres iOS-Clients. Ein einzelner Handshake ist keine vollständige Aufzählung aller Server-Protokolle, Cipher Suites oder Schwachstellen." }
        if category == "Client Certificate" { return "Der Durchlauf richtet keine Client-Identität ein. Eine Client-Zertifikatsanforderung oder HTTP-Ablehnung wird getrennt vom Vertrauen in den Server ausgewiesen." }
        if category == "Certificate Transparency" { return "Apples CT-Ergebnis und eingebettete SCTs sind eigene Befunde. Kein gemeldetes CT-Ergebnis beweist nicht automatisch einen CT-Fehler." }
        return "Testabsicht und beobachteter Fehler werden getrennt: Der Name des badssl-Ziels wird nicht als Beweis für die tatsächliche Fehlerursache verwendet." 
    }
}
struct BadSSLResult: Codable, Identifiable, Sendable {
    var id: String { test.id }
    let test: BadSSLCase
    let record: DiagnosticRecord
    var summary: String { DiagnosticFailure.explain(record)?.title ?? "HTTP \(record.status.map(String.init) ?? "ohne Status") empfangen" }
    var verdict: String { record.error != nil ? "Verbindung abgelehnt" : (record.status ?? 0) >= 400 ? "HTTP-Ablehnung" : "Antwort empfangen" }
    var observations: [String] {
        var notes = [test.scopeNote]
        if test.id == "revoked.badssl.com" {
            if let assessment = record.revocationAssessment { notes.append("Zusätzliche Sperrprüfung: " + assessment.detail) }
            notes.append(record.revocationChecked == true ? "System bestätigt eine erfolgreiche Sperrprüfung ohne gemeldeten Widerruf." : record.revocationChecked == false ? "System konnte keine aktuelle Sperrauskunft bestätigen." : "System hat für diese Anfrage keinen positiven Sperrprüfungsnachweis gemeldet.")
        }
        if test.category == "Mixed Content", !record.responseBody.isEmpty {
            let count = insecureReferences(in: record.responseBody).count
            notes.append(count == 0 ? "Im erfassten HTML wurden mit der statischen Suche keine direkten HTTP-Ressourcenverweise gefunden; dynamische Inhalte bleiben offen." : "Im erfassten HTML wurden \(count) direkte HTTP-Ressourcenverweise gefunden. Diese Subressourcen wurden nicht geladen.")
        }
        return notes
    }
    private func insecureReferences(in html: String) -> [String] {
        let pattern = #"(?is)<(?:script|img|iframe|link|video|audio|source|form)\b[^>]*\b(?:src|href|action)\s*=\s*[\"'](http://[^\"']*)[\"']"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = html as NSString
        return regex.matches(in: html,range:NSRange(location:0,length:ns.length)).map { ns.substring(with:$0.range(at:1)) }
    }
}
@MainActor @Observable final class BadSSLSuite {
    var results: [BadSSLResult] = []
    var running = false
    var cancelled = false
    var started: Date?
    var finished: Date?
    var current = ""
    func run(cases: [BadSSLCase] = BadSSLCase.catalog) async {
        guard !running else { return }
        running = true; cancelled = false; results = []; started = Date(); finished = nil
        defer { running = false; current = ""; finished = Date() }
        // Three independent app-engine requests at a time; no trust override or browser execution.
        for offset in stride(from: 0,to:cases.count,by:3) {
            guard !cancelled, !Task.isCancelled else { break }
            let batch = Array(cases[offset..<min(offset+3,cases.count)])
            current = batch.map(\.name).joined(separator: ", ")
            let completed = await withTaskGroup(of: BadSSLResult.self, returning: [BadSSLResult].self) { group in
                for test in batch { group.addTask {
                    let request = URLRequest(url: URL(string:test.url)!)
                    var record = await DiagnosticEngine(request:request).run(request)
                    if test.id == "revoked.badssl.com" { record.revocationAssessment = await RevocationAssessment.check(record) }
                    return BadSSLResult(test:test,record:record)
                } }
                var rows: [BadSSLResult] = []
                for await result in group { rows.append(result) }
                return rows
            }
            results.append(contentsOf:completed)
            let order = Dictionary(uniqueKeysWithValues: cases.enumerated().map { ($0.element.id,$0.offset) })
            results.sort { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
            saveRun()
        }
    }
    private var savedRunURL: URL { URL.documentsDirectory.appendingPathComponent("BadSSL-Live/results.json") }
    func loadLastRun() {
        guard !running, results.isEmpty, let data = try? Data(contentsOf:savedRunURL) else { return }
        let decoder = JSONDecoder();decoder.dateDecodingStrategy = .iso8601
        if let saved = try? decoder.decode([BadSSLResult].self,from:data) { results = saved;finished = saved.map(\.record.date).max() }
    }
    private func saveRun() {
        let encoder = JSONEncoder();encoder.outputFormatting = [.prettyPrinted,.sortedKeys];encoder.dateEncodingStrategy = .iso8601
        do { try FileManager.default.createDirectory(at:savedRunURL.deletingLastPathComponent(),withIntermediateDirectories:true);try encoder.encode(results).write(to:savedRunURL,options:[.atomic,.completeFileProtection]) } catch { /* The live results remain available for explicit sharing. */ }
    }
    var report: String {
        var lines = ["ATS Diagnostic · badssl","Katalog: https://badssl.com/ · 2026-10-11","Ergebnisse: \(results.count)/\(BadSSLCase.catalog.count)","Plattform: iOS URLSession / Systemvertrauen; keine Prüfung aller Browserfunktionen.", ""]
        for result in results {
            let record = result.record
            lines += [result.test.name + " · " + result.test.category,result.test.url,"Ergebnis: " + result.verdict,"Befund: " + result.summary]
            if let failure = DiagnosticFailure.explain(record) { lines += ["Bedeutung: " + failure.meaning,"Nächster Schritt: " + failure.nextStep]; for evidence in failure.evidence { lines.append("Technik: \(evidence.domain) / \(evidence.code) / SSL \(evidence.sslCode.map(String.init) ?? "—"): \(evidence.message)") } }
            lines += ["HTTP: \(record.status.map(String.init) ?? "—") · TLS: \(TLSDisplay.version(record.tlsVersion)) · Cipher: \(TLSDisplay.cipher(record.cipher))","Systemvertrauen: \(record.trustValid.map(String.init) ?? "nicht gemeldet") · CT: \(record.certificateTransparency.map(String.init) ?? "nicht gemeldet")"]
            for certificate in record.certificates {
                lines.append("Zertifikat: \(certificate.subject) · SHA-256 \(certificate.id)")
                for attribute in (try? X509.issuerAttributes(certificate.der)) ?? [] { lines.append("Aussteller \(attribute.label): \(attribute.value)") }
            }
            lines += result.observations.map { "Einordnung: " + $0 }; lines.append("")
        }
        return lines.joined(separator:"\n")
    }
}
