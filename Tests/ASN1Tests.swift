import Testing
import Foundation
@testable import ATSDiagnostic
struct ASN1Tests {
    @Test func rejectsTruncatedLength() { #expect(throws: ASN1Node.ParseError.self) { try ASN1Node.decode(Data([0x30, 0x82, 0x01])) } }
    @Test func rejectsLengthOverflow() { #expect(throws: ASN1Node.ParseError.self) { try ASN1Node.decode(Data([0x04, 0x84, 0xff, 0xff, 0xff, 0xff])) } }
    @Test func decodesOID() throws { #expect(try ASN1Node.decode(Data([0x06, 0x03, 0x55, 0x1d, 0x11])).first?.oid == "2.5.29.17") }
    @Test func decodesLargeSecondOIDArc() throws { #expect(try ASN1Node.decode(Data([0x06, 0x02, 0x88, 0x37])).first?.oid == "2.999") }
    @Test func readsSequence() throws { #expect(try ASN1Node.decode(Data([0x30, 0x03, 0x02, 0x01, 0x01])).first?.children.first?.value == Data([1])) }
}

struct CertificateFieldTests {
    @Test func utcCenturyBoundary() throws {
        let old = ASN1Node(tag: 0x17, value: Data("500101000000Z".utf8), children: [])
        let recent = ASN1Node(tag: 0x17, value: Data("490101000000Z".utf8), children: [])
        #expect(X509.date(old)?.ISO8601Format().hasPrefix("1950") == true)
        #expect(X509.date(recent)?.ISO8601Format().hasPrefix("2049") == true)
    }
    @Test func decodesKeyUsage() {
        let node = ASN1Node(tag: 3, value: Data([0, 0xa0]), children: [])
        #expect(X509.extensionDescription("2.5.29.15", [node]) == "Digital signature\nKey encipherment")
    }
    @Test func alternativeNamesAreTyped() {
        let root = ASN1Node(tag: 0x30, value: Data(), children: [ASN1Node(tag: 0x82, value: Data("example.com".utf8), children: []), ASN1Node(tag: 0x87, value: Data([127,0,0,1]), children: [])])
        #expect(X509.extensionDescription("2.5.29.17", [root]) == "DNS: example.com\nIP: 127.0.0.1")
    }
}
