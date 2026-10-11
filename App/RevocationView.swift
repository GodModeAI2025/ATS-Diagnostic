import SwiftUI

struct RevocationView: View {
    let record: DiagnosticRecord
    @Binding var assessment: RevocationAssessment?
    @State private var checking = false
    var body: some View {
        Section("Sperrstatus · OCSP / CRL") {
            Text("Systemvertrauen allein ist kein ausdrücklich bestätigter Sperrnachweis. Diese zusätzliche Prüfung kann die im Zertifikat benannte Zertifizierungsstelle kontaktieren.").font(.footnote).foregroundStyle(.secondary)
            if let result = assessment ?? record.revocationAssessment {
                Label(result.status == .good ? "Sperrauskunft bestätigt" : result.status == .revoked ? "Widerruf bestätigt" : "Sperrstatus nicht bestätigt",systemImage:result.status == .good ? "checkmark.shield" : result.status == .revoked ? "exclamationmark.shield" : "questionmark.shield").foregroundStyle(result.status == .revoked ? Color.orange : Color.secondary)
                Text(result.detail).font(.subheadline)
                Text(result.checkedAt,format:.dateTime.day().month().year().hour().minute()).font(.caption).foregroundStyle(.secondary)
                if !result.evidence.isEmpty { DisclosureGroup("Technische Sperrprüfung") { ForEach(Array(result.evidence.enumerated()),id:\.offset) { _, item in Text("\(item.domain) · \(item.code): \(item.message)").font(.footnote).textSelection(.enabled) } } }
            }
            Button("Sperrprüfung durchführen",systemImage:"checkmark.shield") { Task { checking = true;defer { checking = false };assessment = await RevocationAssessment.check(record) } }.disabled(checking || record.certificates.isEmpty)
            if checking { ProgressView("Zertifizierungsstelle prüfen…") }
        }
    }
}
