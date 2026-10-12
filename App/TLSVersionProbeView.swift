import SwiftUI

struct TLSVersionProbeView: View {
    let host: String
    @State private var probing = false
    @State private var probes: [TLSProbeResult] = []
    @State private var probeError: String?
    var body: some View {
        List {
            Text(host).font(.footnote.monospaced()).textSelection(.enabled)
            Button("Test individual TLS versions", systemImage: "waveform.path") { Task { probing = true; defer { probing = false }; do { probes = try await TLSProbe.allVersions(host); probeError = nil } catch { probeError = error.localizedDescription } } }.disabled(probing || host.isEmpty)
            if probing { ProgressView("Testing TLS handshakes…") }
            if let probeError { Text(probeError).foregroundStyle(.red) }
            ForEach(probes) { probe in
                DisclosureGroup {
                    Text(probe.detail).font(.footnote).foregroundStyle(.secondary)
                    ForEach(probe.certificates) { certificate in NavigationLink(certificate.subject) { CertificateDetailView(certificate: certificate, isLeaf: certificate.id == probe.certificates.first?.id, systemCT: nil, issuerCertificate: probe.certificates.nextIssuer(after:certificate)) } }
                } label: { Label(probe.id + (probe.completed ? " · Supported" : " · Unavailable"), systemImage: probe.completed ? "checkmark.circle" : "exclamationmark.circle") }
            }
            Text("A failed probe can result from client policy, server configuration or network conditions. No HTTP request is sent during these probes.").font(.footnote).foregroundStyle(.secondary)
        }.navigationTitle("TLS-Versionen").navigationBarTitleDisplayMode(.inline)
    }
}
