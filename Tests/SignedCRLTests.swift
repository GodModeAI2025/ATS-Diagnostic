import Testing
import Foundation
import Security
@testable import ATSDiagnostic
struct SignedCRLTests {
    private func tlv(_ tag: UInt8,_ value: Data) -> Data {
        let length: [UInt8] = value.count < 128 ? [UInt8(value.count)] : [0x82,UInt8(value.count>>8),UInt8(value.count&255)]
        return Data([tag]+length)+value
    }
    private func fixture(next: String = "300101000000Z",issuer: Data = Data(),delta: Bool = false, point: String? = nil, flags: Data = Data()) throws -> (data:Data,key:SecKey) {
        let key = try #require(SecKeyCreateRandomKey([kSecAttrKeyType:kSecAttrKeyTypeECSECPrimeRandom,kSecAttrKeySizeInBits:256,kSecAttrIsPermanent:false] as CFDictionary,nil))
        let publicKey = try #require(SecKeyCopyPublicKey(key))
        let algorithm = tlv(0x30,Data([0x06,0x08,0x2a,0x86,0x48,0xce,0x3d,0x04,0x03,0x02]))
        let entry = tlv(0x30,tlv(2,Data([1]))+tlv(0x17,Data("250101000000Z".utf8)))
        var fields = tlv(2,Data([1]))+algorithm+tlv(0x30,issuer)+tlv(0x17,Data("250101000000Z".utf8))+tlv(0x17,Data(next.utf8))+tlv(0x30,entry)
        if delta { let ext = tlv(0x30,Data([0x06,0x03,0x55,0x1d,0x1b])+tlv(4,tlv(2,Data([1]))));fields += tlv(0xa0,tlv(0x30,ext)) }
        if let point {
            let info = tlv(0x30,tlv(0xa0,tlv(0xa0,tlv(0x86,Data(point.utf8))))+flags)
            let ext = tlv(0x30,Data([0x06,0x03,0x55,0x1d,0x1c])+tlv(1,Data([0xff]))+tlv(4,info))
            fields += tlv(0xa0,tlv(0x30,ext))
        }
        let tbs = tlv(0x30,fields)
        let signature = try #require(SecKeyCreateSignature(key,.ecdsaSignatureMessageX962SHA256,tbs as CFData,nil)) as Data
        return (tlv(0x30,tbs+algorithm+tlv(3,Data([0])+signature)),publicKey)
    }
    @Test func validatesSignatureAndFindsSerial() throws {
        let value = try fixture()
        let result = try SignedCRL.validate(value.data,issuerKey:value.key,issuerName:Data(),serial:Data([0,1]),distributionPoint:"https://example.test/list")
        #expect(result.revoked);#expect(result.revocationDate != nil)
        let absent = try SignedCRL.validate(value.data,issuerKey:value.key,issuerName:Data(),serial:Data([2]),distributionPoint:"https://example.test/list")
        #expect(!absent.revoked)
    }
    @Test func rejectsTamperedSignature() throws {
        let value = try fixture();var altered = value.data;altered[altered.count-1] ^= 1
        #expect(throws:SignedCRL.ValidationError.self) { try SignedCRL.validate(altered,issuerKey:value.key,issuerName:Data(),serial:Data([1]),distributionPoint:"https://example.test/list") }
    }
    @Test func rejectsStaleList() throws {
        let value = try fixture(next:"250201000000Z")
        #expect(throws:SignedCRL.ValidationError.self) { try SignedCRL.validate(value.data,issuerKey:value.key,issuerName:Data(),serial:Data([1]),distributionPoint:"https://example.test/list") }
    }
    @Test func rejectsWrongIssuer() throws {
        let value = try fixture()
        #expect(throws:SignedCRL.ValidationError.self) { try SignedCRL.validate(value.data,issuerKey:value.key,issuerName:Data([1]),serial:Data([1]),distributionPoint:"https://example.test/list") }
    }
    @Test func rejectsDeltaWithoutBase() throws {
        let value = try fixture(delta:true)
        #expect(throws:SignedCRL.ValidationError.self) { try SignedCRL.validate(value.data,issuerKey:value.key,issuerName:Data(),serial:Data([1]),distributionPoint:"https://example.test/list") }
    }
    @Test func verifiesDistributionPointScope() throws {
        let value = try fixture(point:"http://example.test/list")
        #expect(try SignedCRL.validate(value.data,issuerKey:value.key,issuerName:Data(),serial:Data([1]),distributionPoint:"http://example.test/list").revoked)
        #expect(throws:SignedCRL.ValidationError.self) { try SignedCRL.validate(value.data,issuerKey:value.key,issuerName:Data(),serial:Data([1]),distributionPoint:"http://another.test/list") }
    }
    @Test func rejectsIndirectAndPartialReasonLists() throws {
        for flag in [Data([0x84,1,0xff]),Data([0x83,2,0,0x80]),Data([0x82,1,0xff])] {
            let value = try fixture(point:"http://example.test/list",flags:flag)
            #expect(throws:SignedCRL.ValidationError.self) { try SignedCRL.validate(value.data,issuerKey:value.key,issuerName:Data(),serial:Data([1]),distributionPoint:"http://example.test/list") }
        }
    }

}
