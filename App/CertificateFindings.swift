import Foundation
import Security

struct CertificateFinding: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
}
enum CertificateAnalysis {
    static func findings(_ certificate: CertificateRecord, now: Date = Date()) -> [CertificateFinding] {
        var result: [CertificateFinding] = []
        if let fields = try? X509.fields(certificate.der) {
            let values = Dictionary(uniqueKeysWithValues: fields.map { ($0.id, $0.value) })
            let formatter = ISO8601DateFormatter()
            if let end = values["until"].flatMap(formatter.date(from:)), end < now {
                result.append(CertificateFinding(id: "expired", title: String(localized: "Certificate expired"), detail: String(localized: "Validity ended on \(end.formatted()).")))
            }
            if let start = values["from"].flatMap(formatter.date(from:)), start > now {
                result.append(CertificateFinding(id: "future", title: String(localized: "Certificate not yet valid"), detail: String(localized: "Validity begins on \(start.formatted()).")))
            }
            if ["1.2.840.113549.1.1.4", "1.2.840.113549.1.1.5", "1.2.840.10040.4.3", "1.2.840.10045.4.1"].contains(values["signature"] ?? "") {
                result.append(CertificateFinding(id: "signature", title: String(localized: "Weak signature algorithm"), detail: String(localized: "This certificate uses an MD5 or SHA-1 signature. Its role and system trust result should be considered separately.")))
            }
        } else {
            result.append(CertificateFinding(id: "structure", title: String(localized: "Certificate fields could not be read"), detail: String(localized: "The certificate structure is malformed or unsupported. Duplicate extensions are not permitted. The original data remains exportable; this does not change the system trust result.")))
        }
        if let cert = SecCertificateCreateWithData(nil, certificate.der as CFData), let key = SecCertificateCopyKey(cert), let attrs = SecKeyCopyAttributes(key) as? [String: Any], let bits = attrs[kSecAttrKeySizeInBits as String] as? Int {
            let type = attrs[kSecAttrKeyType as String] as? String
            if (type == (kSecAttrKeyTypeRSA as String) && bits < 2048) || (type == (kSecAttrKeyTypeECSECPrimeRandom as String) && bits < 256) {
                result.append(CertificateFinding(id: "key", title: String(localized: "Small public key"), detail: String(localized: "The public key has \(bits) bits.")))
            }
        }
        return result
    }
    static func publicKeyDetails(_ data: Data) -> String? {
        guard let cert = SecCertificateCreateWithData(nil, data as CFData), let key = SecCertificateCopyKey(cert), let attrs = SecKeyCopyAttributes(key) as? [String: Any], let bits = attrs[kSecAttrKeySizeInBits as String] as? Int else { return nil }
        let type = attrs[kSecAttrKeyType as String] as? String
        return "\(type == (kSecAttrKeyTypeRSA as String) ? "RSA" : type == (kSecAttrKeyTypeECSECPrimeRandom as String) ? "Elliptic curve" : "Key") · \(bits) bits"
    }
}
