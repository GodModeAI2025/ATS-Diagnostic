import SwiftUI
import CryptoKit

struct CertificateDetailView: View {
    let certificate: CertificateRecord
    let isLeaf: Bool
    let systemCT: Bool?
    @State private var showExplanation = false
    @State private var showReminder = false
    @State private var showDataLicense = false
    let issuerCertificate: CertificateRecord?
    @State private var presentation: CertificatePresentation?
    private var fields: [CertificateField] { presentation?.fields ?? [] }
    init(certificate: CertificateRecord, isLeaf: Bool, systemCT: Bool?, issuerCertificate: CertificateRecord? = nil) {
        self.certificate = certificate; self.isLeaf = isLeaf; self.systemCT = systemCT
        self.issuerCertificate = issuerCertificate
    }
    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 14) {
                    SupportingIllustration(kind: .certificate)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(certificate.subject).font(.headline).textSelection(.enabled)
                        Text(isLeaf ? "Server certificate" : "Certificate authority in the chain").font(.subheadline).foregroundStyle(.secondary)
                        if let expiry = presentation?.expiry { Label("Expires \(expiry.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar").font(.caption).foregroundStyle(expiry < Date() ? Color.orange : Color.secondary) }
                    }
                }.padding(.vertical, 6)
                Toggle("Explain certificate fields", isOn: $showExplanation)
            }
            Section("Identity & validity") {
                ForEach(fields.filter { ["subject", "from", "until"].contains($0.id) }) { field in CertificateFieldRow(field: field, explain: showExplanation) }
            }
            if let presentation { CertificateIssuerView(attributes:presentation.issuerAttributes,issuerCertificate:issuerCertificate) } else { ProgressView("Zertifikatsangaben auswerten…") }
            Section("Fingerprints") {
                FingerprintRow(title: "SHA-256", value: RootStoreSnapshot.fingerprint(certificate.der))
                FingerprintRow(title: "SHA-1", value: Insecure.SHA1.hash(data: certificate.der).map { String(format: "%02x", $0) }.joined())
                if showExplanation { Text("Fingerprints identify the exact certificate bytes. SHA-1 is shown for comparison with older tools; it is not used to establish trust.").font(.footnote).foregroundStyle(.secondary) }
            }
            Section("Root-store inclusion") { RootStoreRows(certificate: certificate, showLicense: { showDataLicense = true }) }
            Section("Certificate Transparency") {
                NavigationLink { CertificateTransparencyView(certificate: certificate, systemCT: isLeaf ? systemCT : nil, isLeaf: isLeaf) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: isLeaf && systemCT == true ? "checkmark.seal" : "doc.text.magnifyingglass").foregroundStyle(Color.diagnosticAccent)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(isLeaf && systemCT == true ? "System CT qualified" : "Inspect signed timestamps")
                            Text("Log identities, timestamps and system policy result").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Public key & identifiers") {
                if let key = presentation?.publicKey { Label(key, systemImage: "key").textSelection(.enabled) }
                ForEach(fields.filter { ["key", "2.5.29.14", "2.5.29.35"].contains($0.id) }) { field in CertificateFieldRow(field: field, explain: showExplanation) }
            }
            Section("Metadata") {
                ForEach(fields.filter { ["version", "serial", "signature"].contains($0.id) }) { field in CertificateFieldRow(field: field, explain: showExplanation) }
                VStack(alignment: .leading, spacing: 6) {
                    Label("Certificate source", systemImage: "tray.and.arrow.down").font(.caption).foregroundStyle(.secondary)
                    Text(certificate.source ?? "Not recorded")
                    if showExplanation { Text("System validation may add certificates from its trust store or fetch missing intermediates. This source does not prove the server sent every certificate.").font(.footnote).foregroundStyle(.secondary) }
                }
            }
            Section("Extensions") {
                ForEach(fields.filter { !["subject", "issuer", "from", "until", "key", "version", "serial", "signature", "2.5.29.14", "2.5.29.35", CertificateTransparency.oid].contains($0.id) }) { field in CertificateFieldRow(field: field, explain: showExplanation) }
            }
            if let findings = presentation?.findings, !findings.isEmpty {
                Section("Findings") { ForEach(findings) { finding in VStack(alignment: .leading, spacing: 6) { Label(finding.title, systemImage: "exclamationmark.triangle").foregroundStyle(.orange); Text(finding.detail).font(.subheadline) } } }
            }
            Section("Export & reminders") {
                ShareLink("Export PEM", item: PEMCertificateExport(certificate: certificate), preview: SharePreview(certificate.subject))
                ShareLink("Export DER", item: CertificateExport(certificate: certificate), preview: SharePreview(certificate.subject))
                ShareLink("Export CRT", item: CRTCertificateExport(certificate: certificate), preview: SharePreview(certificate.subject))
                if presentation?.expiry != nil { Button("Expiry reminder", systemImage: "bell") { showReminder = true } }
            }
        }.listStyle(.insetGrouped).navigationTitle("Certificate").navigationBarTitleDisplayMode(.inline)
        .task(id:certificate.id) { presentation = await Task.detached(priority:.userInitiated) { CertificatePresentation.make(certificate) }.value }
        .sheet(isPresented: $showReminder) { CertificateReminderView(certificate: certificate) }
        .sheet(isPresented: $showDataLicense) { DataLicenseView() }
    }
}
private struct CertificateFieldRow: View {
    let field: CertificateField
    let explain: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(field.name).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            Text(field.id == "signature" || field.id == "key" ? X509.algorithmName(field.value) : String(field.value.prefix(800))).lineLimit(8).font(field.id == "serial" || field.id == "2.5.29.14" || field.id == "2.5.29.35" ? .callout.monospaced() : .callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            if field.value.count > 800 { NavigationLink("Vollständigen Wert öffnen") { TextValueView(title:field.name,value:field.value) }.font(.footnote) }
            if explain, let explanation = explanations[field.id] { Text(explanation).font(.footnote).foregroundStyle(.secondary) }
        }.padding(.vertical, 3)
    }
    private var explanations: [String: String] { [
        "subject": "The identity described by this certificate. Hostname matching also considers Subject Alternative Names.",
        "issuer": "The certificate authority that signed this certificate.",
        "from": "The certificate must not be used before this time.",
        "until": "The certificate expires at this time. System trust also checks its signature, hostname and chain.",
        "version": "X.509 versions are displayed as v1, v2 or v3. The encoded version number is zero-based.",
        "serial": "The issuer assigns this number to identify a certificate, including in revocation records.",
        "signature": "The algorithm used by the issuer to sign the certificate, shown as its object identifier.",
        "key": "The algorithm of this certificate’s public key.",
        "2.5.29.14": "Identifies this certificate’s public key.",
        "2.5.29.35": "Helps identify the issuer’s signing key and build the certificate chain.",
        "2.5.29.17": "Names and addresses this certificate can identify.",
        "2.5.29.19": "States whether this certificate can act as a certificate authority and limits subordinate CA depth.",
        "2.5.29.15": "Cryptographic operations this key is permitted to perform.",
        "2.5.29.37": "Application purposes allowed by this certificate.",
        "1.3.6.1.5.5.7.1.1": "Published locations for issuer certificates and OCSP revocation information." ] }
}
struct FingerprintRow: View {
    let title: String
    let value: String
    private var groupedValue: String {
        let characters = Array(value)
        return stride(from: 0, to: characters.count, by: 4).map { String(characters[$0..<min($0 + 4, characters.count)]) }.joined(separator: " ")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary); Spacer(); ShareLink(item: value) { Image(systemName: "square.and.arrow.up").accessibilityLabel("Share \(title)") } }
            Text(groupedValue).font(.callout.monospaced()).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 3)
    }
}
struct RootStoreRows: View {
    let certificate: CertificateRecord
    let showLicense: () -> Void
    var body: some View {
        if let snapshot = RootStoreSnapshot.bundled {
            ForEach(snapshot.stores) { store in
                let root = store.certificates[RootStoreSnapshot.fingerprint(certificate.der)]
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(store.name, systemImage: root == nil ? "minus.circle" : "checkmark.circle").foregroundStyle(root == nil ? Color.secondary : Color.diagnosticAccent)
                        Spacer()
                        Text(root == nil ? "Not listed" : "Included").font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let root, !root.constraints.isEmpty { DisclosureGroup("Published constraints") { Text(root.constraints).font(.footnote.monospaced()).textSelection(.enabled) } }
                }.padding(.vertical, 3)
            }
            Text("Exact SHA-256 match against TLS root lists. Inclusion does not validate this server’s full chain or another browser’s policies. Leaf and intermediate certificates normally are not listed.").font(.footnote).foregroundStyle(.secondary)
            Text("Snapshot: \(String(snapshot.retrievedAt.prefix(10))) · Common CA Database (CCADB)").font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("Data & sources") {
                Link("Root-store reports", destination: URL(string: "https://www.ccadb.org/resources")!)
                Button("Data license", action: showLicense)
            }.font(.footnote)
        } else { Label("Root-store data unavailable", systemImage: "questionmark.circle") }
    }
}
struct CertificateTransparencyView: View {
    let certificate: CertificateRecord
    let systemCT: Bool?
    let isLeaf: Bool
    private let timestamps: [SignedCertificateTimestamp]
    private let parseFailed: Bool
    init(certificate: CertificateRecord, systemCT: Bool?, isLeaf: Bool) {
        self.certificate = certificate; self.systemCT = systemCT; self.isLeaf = isLeaf
        do { timestamps = try CertificateTransparency.embedded(in: certificate.der); parseFailed = false }
        catch { timestamps = []; parseFailed = true }
    }
    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    SupportingIllustration(kind: .certificate)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Certificate Transparency").font(.headline)
                        Text("Public logs help reveal unexpected certificate issuance.").font(.subheadline).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 6)
                Label(systemCT == true ? "System CT qualified" : "System CT result not reported", systemImage: systemCT == true ? "checkmark.seal" : "questionmark.circle").foregroundStyle(systemCT == true ? Color.diagnosticAccent : Color.secondary)
                Text(systemCT == true ? "Apple’s trust engine confirmed that this connection meets its CT policy." : "An absent CT result does not prove a CT failure. Roots and private certificates may not require CT.").font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                if parseFailed { Label("Malformed SCT extension", systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                else if timestamps.isEmpty { Text(isLeaf ? "No embedded SCTs. The server may provide SCTs through TLS or OCSP; those are not exposed by this request capture." : "No embedded SCTs. CT applies to publicly issued server certificates, not normally to CA certificates.").font(.subheadline).foregroundStyle(.secondary) }
                ForEach(timestamps) { timestamp in
                    let log = CTLogSnapshot.bundled?.logs[timestamp.logID]
                    VStack(alignment: .leading, spacing: 8) {
                        Label(log?.name ?? "Unknown log", systemImage: "doc.text").font(.headline)
                        if let log { Text(log.operatorName).font(.subheadline).foregroundStyle(.secondary) }
                        LabeledContent("Timestamp", value: timestamp.timestamp.formatted(date: .abbreviated, time: .standard))
                        LabeledContent("Signature", value: timestamp.signatureAlgorithm)
                        if let log { LabeledContent("Log’s current state", value: log.state.capitalized) }
                        DisclosureGroup("Log ID & signature") {
                            FingerprintRow(title: "Log ID · SHA-256", value: timestamp.logID)
                            Text(timestamp.signature.base64EncodedString()).font(.footnote.monospaced()).textSelection(.enabled)
                        }
                    }.padding(.vertical, 6)
                }
            } header: { Text("Embedded signed timestamps · \(timestamps.count)") } footer: { Text("SCT contents are decoded, not independently signature-verified. The system CT result is separate; an SCT alone does not prove inclusion in a log.") }
            if let snapshot = CTLogSnapshot.bundled { Section("Log directory") { LabeledContent("Version", value: snapshot.version); Text("Google CT log list · \(String(snapshot.date.prefix(10)))").font(.footnote).foregroundStyle(.secondary); Link("View log directory", destination: URL(string: "https://www.gstatic.com/ct/log_list/v3/log_list.json")!) } }
        }.navigationTitle("Transparency").navigationBarTitleDisplayMode(.inline)
    }
}

private struct DataLicenseView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            TextValueView(title: "Data license", value: (Bundle.main.url(forResource: "CCADB-License", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) }) ?? "Unavailable")
                .toolbar { Button("Done") { dismiss() } }
        }
    }
}
