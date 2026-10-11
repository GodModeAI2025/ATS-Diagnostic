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
