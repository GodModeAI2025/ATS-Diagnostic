import Testing
@testable import ATSDiagnostic

struct TLSDisplayTests {
    @Test func distinguishesCleartextFromMissingTLSMetadata() {
        #expect(TLSDisplay.isUnencrypted(DiagnosticRecord(url: "http://example.com", method: "GET")))
        #expect(!TLSDisplay.isUnencrypted(DiagnosticRecord(url: "https://example.com", method: "GET")))
        #expect(!TLSDisplay.isUnencrypted(DiagnosticRecord(url: "invalid", method: "GET")))
    }

    @Test func followsFinalDestinationAcrossRedirects() {
        var record = DiagnosticRecord(url: "http://example.com", method: "GET")
        record.finalURL = "https://example.com"
        #expect(!TLSDisplay.isUnencrypted(record))
        record.url = "https://example.com"
        record.finalURL = "http://example.com"
        #expect(TLSDisplay.isUnencrypted(record))
        record.tlsVersion = "0x0304"
        #expect(!TLSDisplay.isUnencrypted(record))
        #expect(TLSDisplay.version(record.tlsVersion) == "TLS 1.3")
    }
}
