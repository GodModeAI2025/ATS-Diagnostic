import Foundation
import Darwin
import Testing
@testable import ATSDiagnostic

struct ReverseDNSLookupTests {
    @Test func acceptsOnlyNumericIPv4AndIPv6() throws {
        #expect(try SystemReverseDNSLookup.numericAddress(" 127.0.0.1 ") == "127.0.0.1")
        #expect(try SystemReverseDNSLookup.numericAddress("[2001:db8::1]") == "2001:db8::1")
        #expect(try SystemReverseDNSLookup.numericAddress("::1") == "::1")
        #expect(try SystemReverseDNSLookup.numericAddress("fe80::1%en0") == "fe80::1%en0")
    }
    @Test(arguments: ["example.com", "https://127.0.0.1", "127.0.0.1:443", "999.1.1.1", "", "127.0.0.1\nexample.com"])
    func rejectsNonNumericAndAmbiguousInputs(_ value: String) {
        #expect(throws: URLError.self) { try SystemReverseDNSLookup.numericAddress(value) }
    }
    @Test func missingNameExplainsTrustIsSeparate() {
        let error = SystemReverseDNSLookup.Failure(code: EAI_NONAME)
        #expect(error.localizedDescription.contains("kein TLS- oder Zertifikatsfehler"))
    }
}
