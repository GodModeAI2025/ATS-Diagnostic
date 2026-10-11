import SwiftUI

struct HeaderItem: Identifiable {
    let name: String
    let value: String
    var id: String { name }
    var category: String {
        switch name.lowercased() {
        case "strict-transport-security", "content-security-policy", "content-security-policy-report-only", "x-content-type-options", "x-frame-options", "referrer-policy", "permissions-policy": "Security"
        case "cache-control", "etag", "last-modified", "expires", "age", "vary": "Caching"
        case "set-cookie", "cookie": "Cookies"
        default: "General"
        }
    }
    var explanation: String? {
        switch name.lowercased() {
        case "content-type": "The media type of the response, such as HTML, JSON or an image."
        case "content-length": "The declared body size in bytes. Encoding and transfer framing can affect the received size."
        case "content-encoding": "Compression or other encodings applied to the representation."
        case "strict-transport-security": "Tells supporting browsers to require HTTPS for this host for a specified time."
        case "permissions-policy": "Controls which browser features this page and its embedded frames may use."
        case "content-security-policy": "Restricts what a browser may load or execute for this page."
        case "content-security-policy-report-only": "Reports policy violations without enforcing these restrictions."
        case "cache-control": "Defines how clients and shared caches may store or reuse this response."
        case "etag": "An identifier clients can send to check whether the resource has changed."
        case "set-cookie": "Asks the client to store a cookie. Values may contain credentials; review before sharing."
        case "location": "The target URL for a redirect or a newly created resource."
        case "server": "Server software information volunteered by the endpoint."
        case "vary": "Request headers a cache must consider when selecting a stored response."
        case "x-content-type-options": "The nosniff value asks browsers to respect the declared media type."
        case "x-frame-options": "Controls whether browsers may embed this page in a frame."
        case "referrer-policy": "Controls which referrer information browsers send with requests."
        default: nil
        }
    }
}
struct HeadersView: View {
    private let headers: [HeaderItem]
    @State private var query = ""
    @State private var explain = false
    init(headers: [String: String]) { self.headers = headers.map { HeaderItem(name: $0.key, value: $0.value) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
    var body: some View {
        List {
            Section { Toggle("Explain header fields", isOn: $explain); Text("Headers describe how the response is delivered, secured and cached. Tap a field to read or share its complete value.").font(.footnote).foregroundStyle(.secondary) }
            ForEach(["General", "Security", "Caching", "Cookies"], id: \.self) { category in
                let items = headers.filter { $0.category == category && (query.isEmpty || ($0.name + " " + $0.value).localizedCaseInsensitiveContains(query)) }
                if !items.isEmpty { Section(category) { ForEach(items) { item in NavigationLink { HeaderDetailView(item: item) } label: { HeaderRow(item: item, explain: explain) } } } }
            }
        }.navigationTitle("Response headers").navigationBarTitleDisplayMode(.inline).searchable(text: $query, prompt: "Name or value")
    }
}
struct HeaderRow: View {
    let item: HeaderItem
    var explain = false
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) { Image(systemName: item.category == "Security" ? "shield" : item.category == "Caching" ? "clock.arrow.circlepath" : item.category == "Cookies" ? "key" : "text.alignleft").foregroundStyle(Color.diagnosticAccent); Text(item.name).font(.subheadline.weight(.semibold)) }
            Text(item.value).font(.callout.monospaced()).foregroundStyle(.secondary).lineLimit(3)
            if explain, let explanation = item.explanation { Text(explanation).font(.footnote).foregroundStyle(.secondary) }
        }.padding(.vertical, 5)
    }
}
struct TextValueView: View {
    let title: String
    let value: String
    var body: some View {
        ScrollView { Text(value.isEmpty ? "No body received." : value).font(.callout.monospaced()).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(20) }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline).toolbar { ShareLink(item: value) }
    }
}
struct ConnectionSecuritySummary: View {
    let record: DiagnosticRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(record.trustValid == true ? "System trust passed" : record.trustValid == false ? "System trust failed" : "Trust result unavailable", systemImage: record.trustValid == true ? "checkmark.shield" : "questionmark.shield").foregroundStyle(record.trustValid == true ? Color.diagnosticAccent : Color.secondary).font(.headline)
            if let message = record.trustMessage { Text(message).font(.subheadline) }
            Text("\(record.certificates.count) certificates in the evaluated chain").font(.subheadline).foregroundStyle(.secondary)
            if let leaf = record.certificates.first {
                NavigationLink { CertificateTransparencyView(certificate: leaf, systemCT: record.certificateTransparency, isLeaf: true) } label: {
                    Label(record.certificateTransparency == true ? "Certificate Transparency · qualified" : "Certificate Transparency · inspect", systemImage: "doc.text.magnifyingglass")
                }
            }
        }.padding(.vertical, 4)
    }
}
