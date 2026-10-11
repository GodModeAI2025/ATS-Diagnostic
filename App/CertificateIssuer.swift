import Foundation

struct CertificateNameAttribute: Identifiable, Sendable, Equatable {
    let id: String
    let oid: String
    let label: String
    let value: String
}
extension X509 {
    static func issuerAttributes(_ data: Data) throws -> [CertificateNameAttribute] {
        guard let root = try ASN1Node.decode(data).first, let certificate = root.children.first else { throw ASN1Node.ParseError.invalid }
        let tbs = certificate.children
        let offset = tbs.first?.tag == 0xa0 ? 1 : 0
        guard tbs.count > offset + 2 else { throw ASN1Node.ParseError.invalid }
        return nameAttributes(tbs[offset+2])
    }
    static func nameAttributes(_ node: ASN1Node) -> [CertificateNameAttribute] {
        let labels = ["2.5.4.3":"Name (CN)","2.5.4.10":"Organisation (O)","2.5.4.11":"Organisationseinheit (OU)","2.5.4.6":"Land (C)","2.5.4.7":"Ort (L)","2.5.4.8":"Region (ST)","2.5.4.5":"Serienkennung", "2.5.4.9":"Straße", "2.5.4.17":"Postleitzahl", "1.2.840.113549.1.9.1":"E-Mail"]
        var attributes: [CertificateNameAttribute] = []
        for pair in node.children.flatMap(\.children) {
            guard let oid = pair.children.first?.oid, let value = pair.children.last else { continue }
            let decoded = value.tag == 0x1e ? String(data:value.value,encoding:.utf16BigEndian) : value.tag == 0x14 ? String(data:value.value,encoding:.isoLatin1) : String(data:value.value,encoding:.utf8)
            attributes.append(.init(id:"\(oid)-\(attributes.count)",oid:oid,label:labels[oid] ?? oid,value:decoded ?? hex(value.value)))
        }
        return attributes
    }
}
extension Array where Element == CertificateRecord {
    func nextIssuer(after certificate: CertificateRecord) -> CertificateRecord? {
        guard let index = firstIndex(where: { $0.id == certificate.id }), index + 1 < count else { return nil }
        return self[index+1]
    }
}
struct CertificatePresentation: Sendable {
    let fields: [CertificateField]
    let issuerAttributes: [CertificateNameAttribute]
    let findings: [CertificateFinding]
    let publicKey: String?
    let expiry: Date?
    static func make(_ certificate: CertificateRecord) -> Self {
        let fields = (try? X509.fields(certificate.der)) ?? []
        let expiry = fields.first { $0.id == "until" }.flatMap { ISO8601DateFormatter().date(from:$0.value) }
        return Self(fields:fields,issuerAttributes:(try? X509.issuerAttributes(certificate.der)) ?? [],findings:CertificateAnalysis.findings(certificate),publicKey:CertificateAnalysis.publicKeyDetails(certificate.der),expiry:expiry)
    }
}
