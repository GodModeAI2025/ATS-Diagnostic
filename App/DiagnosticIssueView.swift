import SwiftUI

struct DiagnosticIssueView: View {
    let record: DiagnosticRecord
    var body: some View {
        if let failure = DiagnosticFailure.explain(record) {
            VStack(alignment: .leading,spacing:14) {
                Label(failure.title,systemImage:"exclamationmark.shield").font(.headline).foregroundStyle(Color.orange)
                Text(failure.meaning).font(.subheadline)
                VStack(alignment:.leading,spacing:6) { Text("Nächster Schritt").font(.caption.weight(.semibold)).foregroundStyle(.secondary);Text(failure.nextStep).font(.subheadline) }
                DisclosureGroup("Technische Details") {
                    if failure.evidence.isEmpty { Text(record.error ?? record.trustMessage ?? "Keine detaillierte Systemmeldung gespeichert.").font(.footnote).textSelection(.enabled) }
                    ForEach(Array(failure.evidence.enumerated()),id:\.offset) { _, evidence in
                        VStack(alignment:.leading,spacing:5) { Text("\(evidence.domain) · \(evidence.code)" + (evidence.sslCode.map { " · SSL \($0)" } ?? "")).font(.caption.monospaced());Text(evidence.message).font(.footnote) }.textSelection(.enabled).padding(.vertical,4)
                    }
                }.font(.footnote)
            }.padding(.vertical,6)
        }
    }
}
