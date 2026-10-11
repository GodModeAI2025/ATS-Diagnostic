import Foundation
import Security

struct SignedCRLResult: Sendable {
    let revoked: Bool
    let validUntil: Date
    let revocationDate: Date?
}
enum SignedCRL {
    enum ValidationError: Error { case malformed, signature, stale, issuer, scope, unsupported }
    static func validate(_ data: Data, issuerKey: SecKey, issuerName: Data, serial: Data, distributionPoint: String, now: Date = Date()) throws -> SignedCRLResult {
        let roots = try ASN1Node.decode(data)
        guard roots.count == 1, let root = roots.first, root.tag == 0x30, root.children.count == 3 else { throw ValidationError.malformed }
        let tbs = root.children[0], signatureAlgorithm = root.children[1], signatureBits = root.children[2]
        guard let signedBytes = tbs.originalEncoding, signatureBits.tag == 3, signatureBits.value.first == 0 else { throw ValidationError.malformed }
        let algorithms: [String:SecKeyAlgorithm] = ["1.2.840.10045.4.3.2":.ecdsaSignatureMessageX962SHA256,"1.2.840.10045.4.3.3":.ecdsaSignatureMessageX962SHA384,"1.2.840.10045.4.3.4":.ecdsaSignatureMessageX962SHA512,"1.2.840.113549.1.1.11":.rsaSignatureMessagePKCS1v15SHA256,"1.2.840.113549.1.1.12":.rsaSignatureMessagePKCS1v15SHA384,"1.2.840.113549.1.1.13":.rsaSignatureMessagePKCS1v15SHA512]
        guard let oid = signatureAlgorithm.children.first?.oid, let algorithm = algorithms[oid], SecKeyIsAlgorithmSupported(issuerKey,.verify,algorithm) else { throw ValidationError.unsupported }
        var error: Unmanaged<CFError>?
        guard SecKeyVerifySignature(issuerKey,algorithm,signedBytes as CFData,Data(signatureBits.value.dropFirst()) as CFData,&error) else { throw ValidationError.signature }
        let nodes = tbs.children, offset = nodes.first?.tag == 2 ? 1 : 0
        guard nodes.count >= offset+4, nodes[offset].value == signatureAlgorithm.value, nodes[offset+1].value == issuerName else { throw ValidationError.issuer }
        guard let issued = X509.date(nodes[offset+2]), let next = X509.date(nodes[offset+3]), issued <= now, next > now else { throw ValidationError.stale }
        for container in nodes where container.tag == 0xa0 {
            for ext in container.children.first?.children ?? [] {
                guard let identifier = ext.children.first?.oid, let encoded = ext.children.last else { throw ValidationError.malformed }
                let critical = ext.children.contains { $0.tag == 1 && $0.value.first != 0 }
                if identifier == "2.5.29.27" { throw ValidationError.unsupported } // Delta lists need their matching base list.
                if identifier == "2.5.29.28" {
                    let content = try ASN1Node.decode(encoded.value)
                    guard let info = content.first else { throw ValidationError.malformed }
                    let urls = uris(content)
                    guard !urls.isEmpty, urls.contains(distributionPoint) else { throw ValidationError.scope }
                    // Partial-reason, indirect, CA-only and attribute-only lists cannot assert this leaf's complete status.
                    for flag in info.children where flag.tag == 0x82 || flag.tag == 0x83 || flag.tag == 0x84 || flag.tag == 0x85 {
                        if flag.tag == 0x83 || flag.value.contains(where: { $0 != 0 }) { throw ValidationError.scope }
                    }
                } else if critical { throw ValidationError.unsupported }
            }
        }
        let entries: [ASN1Node] = nodes.dropFirst(offset+4).first(where: { $0.tag == 0x30 })?.children ?? []
        for entry in entries {
            guard let entrySerial = entry.children.first, entrySerial.tag == 2 else { throw ValidationError.malformed }
            for ext in entry.children.dropFirst(2).flatMap(\.children) {
                let critical = ext.children.contains { $0.tag == 1 && $0.value.first != 0 }
                if critical || ext.children.first?.oid == "2.5.29.29" { throw ValidationError.unsupported }
            }
            if normalizedSerial(entrySerial.value) == normalizedSerial(serial) {
                guard entry.children.count >= 2, let date = X509.date(entry.children[1]), date <= now else { throw ValidationError.malformed }
                for ext in entry.children.dropFirst(2).flatMap(\.children) {
                    let critical = ext.children.contains { $0.tag == 1 && $0.value.first != 0 }
                    if critical { throw ValidationError.unsupported }
                    if ext.children.first?.oid == "2.5.29.21", let octets = ext.children.last, let reason = try ASN1Node.decode(octets.value).first, reason.value.first == 8 { throw ValidationError.unsupported }
                }
                return SignedCRLResult(revoked:true,validUntil:next,revocationDate:date)
            }
        }
        return SignedCRLResult(revoked:false,validUntil:next,revocationDate:nil)
    }
    static func normalizedSerial(_ bytes: Data) -> Data { Data(bytes.drop(while: { $0 == 0 })) }
    static func uris(_ nodes: [ASN1Node]) -> [String] { nodes.flatMap { node in node.tag == 0x86 ? [node.text] : uris(node.children) } }
    static func leafInformation(_ data: Data) throws -> (serial:Data, issuerName:Data, urls:[String]) {
        guard let cert = try ASN1Node.decode(data).first else { throw ValidationError.malformed }
        let nodes = cert.children.first?.children ?? [], offset = nodes.first?.tag == 0xa0 ? 1 : 0
        guard nodes.count > offset+2 else { throw ValidationError.malformed }
        var urls: [String] = []
        for container in nodes where container.tag == 0xa3 { for ext in container.children.first?.children ?? [] where ext.children.first?.oid == "2.5.29.31" { if let encoded = ext.children.last { let points = try ASN1Node.decode(encoded.value).first?.children ?? []
                    for point in points where !point.children.contains(where: { $0.tag == 0x81 || $0.tag == 0xa2 }) { urls += uris(point.children) } } } }
        return (nodes[offset].value,nodes[offset+2].value,urls)
    }
    static func issuerSubject(_ data: Data) throws -> Data {
        let nodes = try ASN1Node.decode(data).first?.children.first?.children ?? [], offset = nodes.first?.tag == 0xa0 ? 1 : 0
        guard nodes.count > offset+4 else { throw ValidationError.malformed }
        return nodes[offset+4].value
    }
}
enum SignedCRLAssessment {
    static func check(_ record: DiagnosticRecord) async -> RevocationAssessment? {
        guard record.trustValid == true, record.certificates.count >= 2,
              let information = try? SignedCRL.leafInformation(record.certificates[0].der),
              let subject = try? SignedCRL.issuerSubject(record.certificates[1].der), subject == information.issuerName,
              let leafFields = try? X509.fields(record.certificates[0].der),
              leafFields.first(where: { $0.id == "2.5.29.19" }).map({ !$0.value.contains("Certificate authority: Yes") }) ?? true else { return nil }
        let issuerDER = record.certificates[1].der
        guard let issuerFields = try? X509.fields(issuerDER),
              issuerFields.first(where: { $0.id == "2.5.29.15" }).map({ $0.value.split(separator:"\n").contains("CRL signing") }) ?? true else { return nil }
        let hostname = URL(string:record.finalURL ?? record.url)?.host
        let currentTrust = await Task.detached(priority:.userInitiated) {
            let objects = record.certificates.compactMap { SecCertificateCreateWithData(nil,$0.der as CFData) }
            guard let hostname else { return false }
            var trust: SecTrust?
            guard SecTrustCreateWithCertificates(objects as CFArray,SecPolicyCreateSSL(true,hostname as CFString),&trust) == errSecSuccess, let trust else { return false }
            return SecTrustEvaluateWithError(trust,nil)
        }.value
        guard currentTrust else { return nil }
        for original in information.urls.prefix(3) {
            guard var components = URLComponents(string:original), ["https","http"].contains(components.scheme?.lowercased() ?? ""), components.user == nil, components.password == nil else { continue }
            components.scheme = "https" // Keep transport validation enabled; unsupported HTTPS leaves the result unconfirmed.
            guard let fetchURL = components.url else { continue }
            let request = URLRequest(url:fetchURL)
            let response = await DiagnosticEngine(request:request).run(request)
            guard response.error == nil, response.status == 200, response.bytes <= 2*1024*1024 else { continue }
            let data = response.responseEncoding == "base64" ? Data(base64Encoded:response.responseBody) : Data(response.responseBody.utf8)
            guard let data, data.count == response.bytes else { continue }
            let assessed: RevocationAssessment? = await Task.detached(priority:.userInitiated) {
                guard let issuer = SecCertificateCreateWithData(nil,issuerDER as CFData), let key = SecCertificateCopyKey(issuer), let result = try? SignedCRL.validate(data,issuerKey:key,issuerName:subject,serial:information.serial,distributionPoint:original) else { return nil }
                let date = Date()
                let detail = result.revoked ? "Die Seriennummer des Server-Zertifikats steht in einer aktuellen, mit dem Schlüssel des vertrauenswürdigen direkten Ausstellers geprüften CRL. Widerrufen am \(result.revocationDate?.ISO8601Format() ?? "nicht angegeben")." : "Die aktuelle, signaturgeprüfte CRL des direkten Ausstellers enthält diese Server-Seriennummer nicht. Dies prüft das Server-Zertifikat, nicht die Sperrlisten aller übrigen Kettenzertifikate."
                return RevocationAssessment(status:result.revoked ? .revoked : .good,checkedAt:date,detail:detail + " CRL gültig bis \(result.validUntil.ISO8601Format()).",evidence:[ErrorEvidence(domain:"ATS Diagnostic · signierte CRL",code:result.revoked ? 1 : 0,message:"Quelle: \(original); Abruf: \(fetchURL.absoluteString); Signatur, Aussteller, Gültigkeit und CRL-Geltungsbereich geprüft.",sslCode:nil)])
            }.value
            if let assessed { return assessed }
        }
        return nil
    }
}
