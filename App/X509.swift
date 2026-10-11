import Foundation

struct ASN1Node: Sendable {
    let tag: UInt8
    let value: Data
    let children: [ASN1Node]
    static func decode(_ data: Data) throws -> [ASN1Node] {
        let bytes = [UInt8](data)
        return try parse(bytes, depth: 0)
    }
    private static func parse(_ bytes: [UInt8], depth: Int) throws -> [ASN1Node] {
        guard depth < 32 else { throw ParseError.invalid }
        var index = 0
        var nodes: [ASN1Node] = []
        while index < bytes.count {
            let tag = bytes[index]; index += 1
            guard index < bytes.count else { throw ParseError.invalid }
            let lengthByte = bytes[index]; index += 1
            var length = Int(lengthByte)
            if lengthByte & 0x80 != 0 {
                let count = Int(lengthByte & 0x7f)
                guard count > 0, count <= 4, index + count <= bytes.count else { throw ParseError.invalid }
                length = 0
                for _ in 0..<count { length = (length << 8) | Int(bytes[index]); index += 1 }
            }
            guard length <= bytes.count - index else { throw ParseError.invalid }
            let value = Array(bytes[index..<index + length]); index += length
            nodes.append(ASN1Node(tag: tag, value: Data(value), children: tag & 0x20 != 0 ? try parse(value, depth: depth + 1) : []))
        }
        return nodes
    }
    var oid: String? {
        guard tag == 6, !value.isEmpty else { return nil }
        var parts: [UInt64] = []; var current: UInt64 = 0
        for byte in value {
            guard current <= UInt64.max >> 7 else { return nil }
            current = (current << 7) | UInt64(byte & 0x7f)
            if byte & 0x80 == 0 { parts.append(current); current = 0 }
        }
        guard value.last! & 0x80 == 0, let first = parts.first else { return nil }
        let arc: UInt64 = first < 40 ? 0 : first < 80 ? 1 : 2
        return ([arc, first - arc * 40] + parts.dropFirst()).map(String.init).joined(separator: ".")
    }
    var text: String { String(data: value, encoding: .utf8) ?? value.map { String(format: "%02X", $0) }.joined(separator: ":") }
    enum ParseError: Error { case invalid }
}
struct CertificateField: Identifiable, Sendable {
    let id: String
    let name: String
    let value: String
}
enum X509 {
    static func fields(_ data: Data) throws -> [CertificateField] {
        guard let root = try ASN1Node.decode(data).first, root.tag == 0x30, root.children.count == 3 else { throw ASN1Node.ParseError.invalid }
        let tbs = root.children[0].children
        let offset = tbs.first?.tag == 0xa0 ? 1 : 0
        guard tbs.count >= offset + 6 else { throw ASN1Node.ParseError.invalid }
        var fields: [CertificateField] = []
        func add(_ id: String, _ name: String, _ value: String) { fields.append(CertificateField(id: id, name: name, value: value)) }
        add("serial", "Serial number", tbs[offset].text)
        add("signature", "Signature algorithm", root.children[1].children.first?.oid ?? "Unknown")
        add("issuer", "Issuer", name(tbs[offset + 2]))
        let validity = tbs[offset + 3].children
        if validity.count == 2 { add("from", "Valid from (UTC)", validity[0].text); add("until", "Valid until (UTC)", validity[1].text) }
        add("subject", "Subject", name(tbs[offset + 4]))
        let key = tbs[offset + 5].children
        add("key", "Public key algorithm", key.first?.children.first?.oid ?? "Unknown")
        for container in tbs where container.tag == 0xa3 {
            for ext in container.children.first?.children ?? [] {
                guard let oid = ext.children.first?.oid, let value = ext.children.last else { continue }
                let labels = ["2.5.29.17": "Subject alternative names", "2.5.29.15": "Key usage", "2.5.29.37": "Extended key usage", "2.5.29.19": "Basic constraints", "2.5.29.14": "Subject key identifier", "2.5.29.35": "Authority key identifier", "2.5.29.32": "Certificate policies", "1.3.6.1.5.5.7.1.1": "Authority information access", "2.5.29.31": "CRL distribution points"]
                let decoded = try ASN1Node.decode(value.value)
                add(oid, labels[oid] ?? oid, flatten(decoded))
            }
        }
        return fields
    }
    private static func name(_ node: ASN1Node) -> String {
        node.children.flatMap(\.children).map { pair in
            let labels = ["2.5.4.3": "CN", "2.5.4.6": "C", "2.5.4.7": "L", "2.5.4.8": "ST", "2.5.4.10": "O", "2.5.4.11": "OU"]
            let oid = pair.children.first?.oid ?? ""
            return "\(labels[oid] ?? oid)=\(pair.children.last?.text ?? "")"
        }.joined(separator: ", ")
    }
    private static func flatten(_ nodes: [ASN1Node]) -> String {
        nodes.map { node in
            if !node.children.isEmpty { return flatten(node.children) }
            return node.oid ?? node.text
        }.joined(separator: "\n")
    }
}
