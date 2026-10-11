import Foundation

struct ASN1Node: Sendable {
    let tag: UInt8
    let value: Data
    let children: [ASN1Node]
    var originalEncoding: Data? = nil
    static func decode(_ data: Data) throws -> [ASN1Node] {
        let bytes = [UInt8](data)
        return try parse(bytes, depth: 0)
    }
    private static func parse(_ bytes: [UInt8], depth: Int) throws -> [ASN1Node] {
        guard depth < 32 else { throw ParseError.invalid }
        var index = 0
        var nodes: [ASN1Node] = []
        while index < bytes.count {
            let start = index
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
            nodes.append(ASN1Node(tag: tag, value: Data(value), children: tag & 0x20 != 0 ? try parse(value, depth: depth + 1) : [], originalEncoding: Data(bytes[start..<index])))
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
        let version = offset == 1 ? Int(tbs[0].children.first?.value.first ?? 0) + 1 : 1
        add("version", "X.509 version", "v\(version)")
        add("serial", "Serial number", hex(tbs[offset].value))
        add("signature", "Signature algorithm", root.children[1].children.first?.oid ?? "Unknown")
        add("issuer", "Issuer", name(tbs[offset + 2]))
        let validity = tbs[offset + 3].children
        if validity.count == 2 { add("from", "Valid from (UTC)", date(validity[0])?.ISO8601Format() ?? validity[0].text); add("until", "Valid until (UTC)", date(validity[1])?.ISO8601Format() ?? validity[1].text) }
        add("subject", "Subject", name(tbs[offset + 4]))
        let key = tbs[offset + 5].children
        add("key", "Public key algorithm", key.first?.children.first?.oid ?? "Unknown")
        for container in tbs where container.tag == 0xa3 {
            for ext in container.children.first?.children ?? [] {
                guard let oid = ext.children.first?.oid, let value = ext.children.last else { continue }
                let labels = ["2.5.29.17": "Subject alternative names", "2.5.29.15": "Key usage", "2.5.29.37": "Extended key usage", "2.5.29.19": "Basic constraints", "2.5.29.14": "Subject key identifier", "2.5.29.35": "Authority key identifier", "2.5.29.32": "Certificate policies", "1.3.6.1.5.5.7.1.1": "Authority information access", "2.5.29.31": "CRL distribution points"]
                let decoded = try ASN1Node.decode(value.value)
                add(oid, (labels[oid] ?? oid) + (ext.children.contains { $0.tag == 1 && $0.value.first != 0 } ? " · critical" : ""), extensionDescription(oid, decoded))
            }
        }
        return fields
    }
    static func algorithmName(_ oid: String?) -> String {
        guard let oid else { return "Unknown" }
        let names = ["1.2.840.113549.1.1.1": "RSA", "1.2.840.10045.2.1": "Elliptic curve", "1.3.101.112": "Ed25519", "1.2.840.113549.1.1.5": "SHA-1 with RSA", "1.2.840.113549.1.1.11": "SHA-256 with RSA", "1.2.840.113549.1.1.12": "SHA-384 with RSA", "1.2.840.113549.1.1.13": "SHA-512 with RSA", "1.2.840.113549.1.1.10": "RSA-PSS", "1.2.840.10045.4.3.2": "ECDSA with SHA-256", "1.2.840.10045.4.3.3": "ECDSA with SHA-384", "1.2.840.10045.4.3.4": "ECDSA with SHA-512"]
        return names[oid].map { "\($0) · \(oid)" } ?? oid
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

extension X509 {
    static func date(_ node: ASN1Node) -> Date? {
        guard node.tag == 0x17 || node.tag == 0x18 else { return nil }
        let text = node.text
        guard text.hasSuffix("Z") else { return nil }
        let expanded: String
        if node.tag == 0x17 {
            guard text.count == 13, let year = Int(text.prefix(2)) else { return nil }
            expanded = (year >= 50 ? "19" : "20") + text
        } else { guard text.count == 15 else { return nil }; expanded = text }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMddHHmmss'Z'"
        formatter.isLenient = false
        return formatter.date(from: expanded)
    }
    static func extensionDescription(_ oid: String, _ nodes: [ASN1Node]) -> String {
        guard let root = nodes.first else { return "Empty extension" }
        switch oid {
        case "2.5.29.17": return root.children.map { node in
            switch node.tag {
            case 0x81: "Email: " + node.text
            case 0x82: "DNS: " + node.text
            case 0x86: "URI: " + node.text
            case 0x87: "IP: " + ip(node.value)
            default: "General name \(node.tag): \(hex(node.value))"
            }
        }.joined(separator: "\n")
        case "2.5.29.15":
            guard root.tag == 3, root.value.count >= 2 else { return "Invalid key usage" }
            let bits = Array(root.value.dropFirst())
            let labels = ["Digital signature", "Content commitment", "Key encipherment", "Data encipherment", "Key agreement", "Certificate signing", "CRL signing", "Encipher only", "Decipher only"]
            return labels.enumerated().compactMap { index, label in
                index / 8 < bits.count && bits[index / 8] & (0x80 >> (index % 8)) != 0 ? label : nil
            }.joined(separator: "\n")
        case "2.5.29.37":
            let names = ["1.3.6.1.5.5.7.3.1": "TLS server authentication", "1.3.6.1.5.5.7.3.2": "TLS client authentication", "1.3.6.1.5.5.7.3.3": "Code signing", "1.3.6.1.5.5.7.3.4": "Email protection", "1.3.6.1.5.5.7.3.8": "Timestamping", "1.3.6.1.5.5.7.3.9": "OCSP signing"]
            return root.children.map { names[$0.oid ?? ""] ?? $0.oid ?? hex($0.value) }.joined(separator: "\n")
        case "2.5.29.19":
            let ca = root.children.first(where: { $0.tag == 1 })?.value.first.map { $0 != 0 } ?? false
            let path = root.children.first(where: { $0.tag == 2 }).map { hex($0.value) }
            return "Certificate authority: \(ca ? "Yes" : "No")" + (path.map { "\nPath length constraint: \($0)" } ?? "")
        case "2.5.29.14": return hex(root.value)
        case "2.5.29.35": return root.children.map { "\(($0.tag & 0x1f) == 0 ? "Key identifier" : ($0.tag & 0x1f) == 1 ? "Certificate issuer" : "Certificate serial number"): \(hex($0.value))" }.joined(separator: "\n")
        case "1.3.6.1.4.1.11129.2.4.2": return "Embedded signed certificate timestamps · open Certificate Transparency for details"
        case "1.3.6.1.5.5.7.1.1": return root.children.map { pair in
            let method = pair.children.first?.oid ?? ""
            let label = method == "1.3.6.1.5.5.7.48.1" ? "OCSP" : method == "1.3.6.1.5.5.7.48.2" ? "CA issuers" : method
            return "\(label): \(pair.children.last?.text ?? "")"
        }.joined(separator: "\n")
        default: return flatten(nodes)
        }
    }
    static func hex(_ data: Data) -> String { data.map { String(format: "%02X", $0) }.joined(separator: ":") }
    private static func ip(_ data: Data) -> String {
        if data.count == 4 { return data.map(String.init).joined(separator: ".") }
        if data.count == 16 { let bytes = Array(data); return stride(from: 0, to: 16, by: 2).map { String(format: "%x", UInt16(bytes[$0]) << 8 | UInt16(bytes[$0 + 1])) }.joined(separator: ":") }
        return hex(data)
    }
}
