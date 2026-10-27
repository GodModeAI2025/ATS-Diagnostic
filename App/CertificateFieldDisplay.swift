import Foundation

enum CertificateFieldDisplay {
    static func value(_ field: CertificateField, localize: (String) -> String = { NSLocalizedString($0, comment: "") }) -> String {
        if field.id == "signature" || field.id == "key" { return algorithm(X509.algorithmName(field.value), localize: localize) }
        return field.value.components(separatedBy: "\n").map { line in
            switch field.id {
            case "2.5.29.17": return prefixedLine(line, labels: ["Email", "DNS", "URI", "IP"], localize: localize) ?? generalNameLine(line, localize: localize) ?? line
            case "2.5.29.15", "2.5.29.37": return localizeIfKnown(line, labels: usageLabels, localize: localize)
            case "2.5.29.19":
                if let rest = line.stripPrefix("Certificate authority: ") {
                    return "\(localize("Certificate authority")): \(rest == "Yes" || rest == "No" ? localize(rest) : rest)"
                }
                return prefixedLine(line, labels: ["Path length constraint"], localize: localize) ?? line
            case "2.5.29.35": return prefixedLine(line, labels: ["Key identifier", "Certificate issuer", "Certificate serial number"], localize: localize) ?? line
            case "1.3.6.1.5.5.7.1.1": return prefixedLine(line, labels: ["CA issuers"], localize: localize) ?? line
            case "1.3.6.1.4.1.11129.2.4.2": return localizeIfKnown(line, labels: ["Embedded signed certificate timestamps · open Certificate Transparency for details"], localize: localize)
            default: return line
            }
        }.joined(separator: "\n")
    }

    static func publicKeyDetails(_ value: String, localize: (String) -> String = { NSLocalizedString($0, comment: "") }) -> String {
        let parts = value.components(separatedBy: " · ")
        guard parts.count == 2, ["RSA", "Elliptic curve", "Key"].contains(parts[0]) else { return value }
        let measurement = parts[1].split(separator: " ")
        guard measurement.count == 2, measurement[1] == "bits", let bits = Int(measurement[0]) else { return value }
        return "\(localize(parts[0])) · \(bits) \(localize("bits"))"
    }

    private static let algorithmLabels = ["RSA", "Elliptic curve", "Ed25519", "SHA-1 with RSA", "SHA-256 with RSA", "SHA-384 with RSA", "SHA-512 with RSA", "RSA-PSS", "ECDSA with SHA-256", "ECDSA with SHA-384", "ECDSA with SHA-512"]
    private static let usageLabels = ["Digital signature", "Content commitment", "Key encipherment", "Data encipherment", "Key agreement", "Certificate signing", "CRL signing", "Encipher only", "Decipher only", "TLS server authentication", "TLS client authentication", "Code signing", "Email protection", "Timestamping", "OCSP signing"]

    private static func algorithm(_ value: String, localize: (String) -> String) -> String {
        guard let separator = value.range(of: " · ") else { return value }
        let label = String(value[..<separator.lowerBound])
        guard algorithmLabels.contains(label) else { return value }
        return localize(label) + String(value[separator.lowerBound...])
    }

    private static func localizeIfKnown(_ value: String, labels: [String], localize: (String) -> String) -> String {
        labels.contains(value) ? localize(value) : value
    }

    private static func prefixedLine(_ line: String, labels: [String], localize: (String) -> String) -> String? {
        for label in labels where line.hasPrefix(label + ": ") {
            return localize(label) + String(line.dropFirst(label.count))
        }
        return nil
    }

    private static func generalNameLine(_ line: String, localize: (String) -> String) -> String? {
        guard line.hasPrefix("General name "), line.contains(":") else { return nil }
        return localize("General name") + String(line.dropFirst("General name".count))
    }
}

private extension String {
    func stripPrefix(_ prefix: String) -> String? { hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil }
}
