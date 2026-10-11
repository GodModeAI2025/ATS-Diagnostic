import Foundation
import Testing
@testable import ATSDiagnostic

struct CertificateTransparencyTests {
    private func fixture(version: UInt8 = 0, signature: [UInt8] = [0x30,0x01,0x00]) -> Data {
        let item: [UInt8] = [version] + Array(repeating: 0x11, count: 32) + [0,0,0,0,0,0,3,0xe8] + [0,0,4,3,0,UInt8(signature.count)] + signature
        let list = [UInt8(item.count >> 8),UInt8(item.count & 255)] + item
        return Data([UInt8(list.count >> 8),UInt8(list.count & 255)] + list)
    }
    @Test func decodesLogTimestampAndAlgorithm() throws {
        let items = try CertificateTransparency.parseList(fixture())
        #expect(items.count == 1)
        #expect(items[0].logID == String(repeating: "11", count: 32))
        #expect(items[0].timestamp.timeIntervalSince1970 == 1)
        #expect(items[0].signatureAlgorithm == "SHA-256 · ECDSA")
    }
    @Test func rejectsTruncatedSCT() { #expect(throws: CertificateTransparency.ParseError.self) { try CertificateTransparency.parseList(Data(fixture().dropLast())) } }
    @Test func rejectsUnknownSCTVersion() { #expect(throws: CertificateTransparency.ParseError.self) { try CertificateTransparency.parseList(fixture(version: 1)) } }
    @Test func rejectsEmptySignature() { #expect(throws: CertificateTransparency.ParseError.self) { try CertificateTransparency.parseList(fixture(signature: [])) } }
    @Test func rejectsTrailingDataOutsideList() { #expect(throws: CertificateTransparency.ParseError.self) { try CertificateTransparency.parseList(fixture() + Data([0])) } }
    @Test func bundledDataHasIndependentStoresAndConstraints() throws {
        let snapshot = try #require(RootStoreSnapshot.bundled)
        #expect(Set(snapshot.stores.map(\.name)) == Set(["Apple","Google Chrome","Microsoft","Mozilla"]))
        let isrg = "96bcec06264976f37460779acf28c5a7cfe8a3c0aae11a8ffcee05c0bddf08c6"
        #expect(snapshot.stores.first { $0.name == "Apple" }?.certificates[isrg]?.name == "ISRG Root X1")
        #expect(snapshot.stores.first { $0.name == "Apple" }?.certificates[isrg]?.constraints.isEmpty == false)
        #expect(snapshot.stores.allSatisfy { $0.certificates[String(repeating:"0",count:64)] == nil })
        #expect(CTLogSnapshot.bundled?.logs.isEmpty == false)
    }
    @Test func fingerprintsUseDERBytes() { #expect(RootStoreSnapshot.fingerprint(Data("abc".utf8)) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad") }
    @Test func oldHistoryDecodesWithoutNewMetadata() throws {
        let der = Data("cert".utf8).base64EncodedString()
        let certificate = try JSONDecoder().decode(CertificateRecord.self,from:Data("{\"id\":\"old\",\"subject\":\"old\",\"der\":\"\(der)\"}".utf8))
        #expect(certificate.source == nil)
    }
}
