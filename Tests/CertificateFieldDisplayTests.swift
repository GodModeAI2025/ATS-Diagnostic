import Testing
import Foundation
@testable import ATSDiagnostic

struct CertificateFieldDisplayTests {
    private static func german(_ key: String) -> String {
        Bundle.main.path(forResource: "de", ofType: "lproj").flatMap { Bundle(path: $0) }?.localizedString(forKey: key, value: nil, table: nil) ?? "Missing German resources"
    }

    @Test func localizesGeneratedLabelsButKeepsRawIdentifiersAndEndpoints() {
        let san = CertificateField(id: "2.5.29.17", name: "Subject alternative names", value: "DNS: api.example.test\nURI: https://api.example.test/path")
        #expect(CertificateFieldDisplay.value(san, localize: Self.german) == san.value)
        #expect(CertificateFieldDisplay.value(san, localize: { $0 }) == san.value)

        let signature = CertificateField(id: "signature", name: "Signature algorithm", value: "1.2.840.113549.1.1.11")
        #expect(CertificateFieldDisplay.value(signature, localize: Self.german) == "SHA-256 mit RSA · 1.2.840.113549.1.1.11")
        let unknownName = CertificateField(id: "2.5.29.17", name: "Subject alternative names", value: "General name 161: 01:02")
        #expect(CertificateFieldDisplay.value(unknownName, localize: Self.german) == "Allgemeiner Name 161: 01:02")
        let raw = CertificateField(id: "subject", name: "Subject", value: "CN=Digital signature, O=Unknown")
        #expect(CertificateFieldDisplay.value(raw, localize: Self.german) == raw.value)
    }

    @Test func translatesBasicConstraintsOnlyForDisplayAndRetainsCAAssertion() {
        let raw = "Certificate authority: Yes\nPath length constraint: 01"
        let field = CertificateField(id: "2.5.29.19", name: "Basic constraints", value: raw)
        #expect(CertificateFieldDisplay.value(field, localize: Self.german) == "Zertifizierungsstelle: Ja\nPfadlängenbeschränkung: 01")
        #expect(CertificateFieldDisplay.value(field, localize: { $0 }) == raw)
        #expect(field.value == raw && field.value.contains("Certificate authority: Yes"))
    }

    @Test func translatesKnownKeyUsageAndKeySizeLabels() {
        let usage = CertificateField(id: "2.5.29.15", name: "Key usage", value: "Digital signature\nKey encipherment")
        #expect(CertificateFieldDisplay.value(usage, localize: Self.german) == "Digitale Signatur\nSchlüsselverschlüsselung")
        #expect(CertificateFieldDisplay.publicKeyDetails("Elliptic curve · 256 bits", localize: Self.german) == "Elliptische Kurve · 256 Bit")
        #expect(CertificateFieldDisplay.publicKeyDetails("Elliptic curve · 256 bits", localize: { $0 }) == "Elliptic curve · 256 bits")
    }
}
