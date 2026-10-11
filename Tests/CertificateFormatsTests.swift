import Testing
import Foundation
@testable import ATSDiagnostic
struct CertificateFormatsTests {
    @Test func pemRoundTripsCertificateBytes() throws {
        let certificate = CertificateRecord(id: "test", subject: "example.com", der: Data((0..<180).map(UInt8.init)))
        let lines = certificate.pem.split(separator: "\n")
        #expect(lines.first == "-----BEGIN CERTIFICATE-----")
        #expect(lines.last == "-----END CERTIFICATE-----")
        let body = lines.dropFirst().dropLast()
        #expect(body.dropLast().allSatisfy { $0.count == 64 })
        #expect(Data(base64Encoded: body.joined()) == certificate.der)
    }
    @Test func chainPreservesOrder() {
        let first = CertificateRecord(id: "a", subject: "Leaf", der: Data([1,2]))
        let second = CertificateRecord(id: "b", subject: "Issuer", der: Data([3,4]))
        #expect(CertificateChainExport(certificates: [first, second]).pem == first.pem + second.pem)
    }
    @Test func unsafeSubjectCannotBecomeAPath() {
        let certificate = CertificateRecord(id: "abcdef", subject: "../../evil/path", der: Data())
        #expect(!certificate.exportName.contains("/"))
        #expect(!certificate.exportName.hasPrefix("."))
    }
}
