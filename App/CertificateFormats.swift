import Foundation
import CoreTransferable
import UniformTypeIdentifiers

extension CertificateRecord {
    var pem: String {
        let encoded = der.base64EncodedString()
        var lines: [String] = []
        var index = encoded.startIndex
        while index < encoded.endIndex {
            let end = encoded.index(index, offsetBy: 64, limitedBy: encoded.endIndex) ?? encoded.endIndex
            lines.append(String(encoded[index..<end]))
            index = end
        }
        return "-----BEGIN CERTIFICATE-----\n" + lines.joined(separator: "\n") + "\n-----END CERTIFICATE-----\n"
    }
    var exportName: String {
        let safe = subject.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || "-_.".unicodeScalars.contains($0) ? String($0) : "_" }.joined()
        let trimmed = safe.trimmingCharacters(in: CharacterSet(charactersIn: "._"))
        return trimmed.isEmpty ? "Certificate-" + String(id.prefix(12)) : String(trimmed.prefix(80))
    }
}
struct PEMCertificateExport: Transferable {
    let certificate: CertificateRecord
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { Data($0.certificate.pem.utf8) }.suggestedFileName { $0.certificate.exportName + ".pem" }
    }
}
struct CRTCertificateExport: Transferable {
    let certificate: CertificateRecord
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .data) { $0.certificate.der }.suggestedFileName { $0.certificate.exportName + ".crt" }
    }
}
struct CertificateChainExport: Transferable {
    let certificates: [CertificateRecord]
    var pem: String { certificates.map(\.pem).joined() }
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { Data($0.pem.utf8) }.suggestedFileName("ATS-Diagnostic-chain.pem")
    }
}
