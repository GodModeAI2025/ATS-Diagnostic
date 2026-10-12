import SwiftUI

struct ConnectionMapView: View {
    let record: DiagnosticRecord
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TreeNode(title: URL(string: record.finalURL ?? record.url)?.host ?? record.url, subtitle: record.finalURL ?? record.url, symbol: "globe", root: true)
                if let finalURL = record.finalURL, finalURL != record.url { Text("Requested URL: \(record.url)").font(.caption).foregroundStyle(.secondary).padding(.top, 8) }
                TreeBranch {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(record.certificates) { certificate in
                                NavigationLink { CertificateDetailView(certificate: certificate, isLeaf: certificate.id == record.certificates.first?.id, systemCT: record.certificateTransparency, issuerCertificate: record.certificates.nextIssuer(after:certificate)) } label: { TreeNode(title: certificate.subject, subtitle: certificate.id == record.certificates.first?.id ? "Server certificate" : "Certificate authority", symbol: "checkmark.seal") }
                            }
                            if let leaf = record.certificates.first { NavigationLink { CertificateTransparencyView(certificate: leaf, systemCT: record.certificateTransparency, isLeaf: true) } label: { TreeNode(title: "Certificate Transparency", subtitle: record.certificateTransparency == true ? "System CT qualified" : "Inspect log timestamps", symbol: "doc.text.magnifyingglass") } }
                        }.padding(.top, 12)
                    } label: { TreeNode(title: "TLS & trust", subtitle: "\(TLSDisplay.version(record.tlsVersion)) · \(record.trustValid == true ? "System trust passed" : "Inspect trust result")", symbol: "lock.shield") }
                }
                TreeBranch {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 12) {
                            NavigationLink { HeadersView(headers: record.responseHeaders) } label: { TreeNode(title: "Headers", subtitle: "\(record.responseHeaders.count) fields · delivery, security & caching", symbol: "list.bullet.rectangle") }
                            NavigationLink { TextValueView(title: "Response body", value: record.responseBody) } label: { TreeNode(title: "Body", subtitle: record.responseByteCountKnown == false ? "Gesamtgröße unbekannt" : record.bytes.formatted(.byteCount(style: .file)), symbol: "doc.text") }
                        }.padding(.top, 12)
                    } label: { TreeNode(title: "HTTP response", subtitle: "\(record.method) · \(record.status.map(String.init) ?? "Failed") · \(record.protocolName ?? "Protocol not reported")", symbol: "arrow.down.doc") }
                }
                TreeBranch { VStack(alignment: .leading, spacing: 12) { TreeNode(title: "Measured timings", subtitle: record.duration.formatted(.number.precision(.fractionLength(3))) + " s total", symbol: "timer"); ConnectionTimingChart(record: record) } }
                Text("Tap a branch to expand it. Certificate order follows the system-evaluated chain; this diagram does not prove every certificate was sent by the server.").font(.footnote).foregroundStyle(.secondary).padding(.top, 24)
            }.padding(20).frame(maxWidth: 780, alignment: .leading).frame(maxWidth: .infinity)
        }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("Connection map").navigationBarTitleDisplayMode(.inline)
    }
}
private struct TreeBranch<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 8, bottomTrailingRadius: 0, topTrailingRadius: 0).stroke(Color.diagnosticAccent.opacity(0.3),lineWidth: 2).frame(width: 14).padding(.bottom, 16).accessibilityHidden(true)
            content().padding(14).frame(maxWidth: .infinity, alignment: .leading).background(.background, in: RoundedRectangle(cornerRadius: 16))
        }.padding(.leading, 16).padding(.top, 14)
    }
}
private struct TreeNode: View {
    let title: String
    let subtitle: String
    let symbol: String
    var root = false
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.title3).foregroundStyle(Color.diagnosticAccent).frame(width: 34,height: 34).background(Color.diagnosticTint,in: RoundedRectangle(cornerRadius: 10)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) { Text(title).font(root ? .headline : .subheadline.weight(.semibold)).foregroundStyle(Color(uiColor: .label)); Text(subtitle).font(.caption).foregroundStyle(Color(uiColor: .secondaryLabel)).lineLimit(3) }
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }
}
struct HeaderDetailView: View {
    let item: HeaderItem
    private let directives: [PolicyDirective]
    init(item: HeaderItem) { self.item = item; directives = PolicyDirectives.parse(name: item.name, value: item.value) }
    var body: some View {
        if directives.isEmpty { TextValueView(title: item.name, value: item.value) }
        else {
            List {
                Section { Label(item.name,systemImage: "shield").font(.headline); Text(item.explanation ?? "Browser security policy directives.").font(.subheadline).foregroundStyle(.secondary) }
                Section("Policy directives · \(directives.count)") {
                    ForEach(directives) { directive in
                        DisclosureGroup {
                            Text(directive.value).font(.callout.monospaced()).textSelection(.enabled).padding(.vertical, 5)
                        } label: { Label(directive.name,systemImage: "point.3.connected.trianglepath.dotted").font(.subheadline.monospaced()) }
                    }
                }
                Section { NavigationLink("Complete raw value") { TextValueView(title: item.name,value: item.value) } }
            }.navigationTitle("Security policy").navigationBarTitleDisplayMode(.inline).toolbar { ShareLink(item: item.value) }
        }
    }
}
