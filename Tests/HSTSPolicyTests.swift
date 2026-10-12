import Testing
@testable import ATSDiagnostic

struct HSTSPolicyTests {
    @Test func distinguishesMissingInvalidAndZero() {
        #expect(HSTSPolicy.parse(nil) == .missing)
        #expect(HSTSPolicy.parse("") == .invalid)
        #expect(HSTSPolicy.parse("max-age=000") == .policy(.init(maxAgeSeconds: "000", includesSubdomains: false, preloadRequested: false)))
    }
    @Test func acceptsQuotedAgeAndCaseInsensitiveDirectives() {
        #expect(HSTSPolicy.parse("MAX-AGE=\"31536000\"; includeSubDomains; preload") == .policy(.init(maxAgeSeconds: "31536000", includesSubdomains: true, preloadRequested: true)))
    }
    @Test(arguments: ["max-age=-1", "max-age=1; MAX-age=2", "max-age=1;includeSubDomains=true", "max-age=1, max-age=2", "max-age=\"1", "max-age=1;bad name=x", "max-age=1\n"])
    func rejectsMalformedFields(_ field: String) { #expect(HSTSPolicy.parse(field) == .invalid) }
    @Test func unknownExtensionsAndLargeAge() {
        let age = String(repeating: "9", count: 80)
        #expect(HSTSPolicy.parse("max-age=\(age); extension=\"a;b\"") == .policy(.init(maxAgeSeconds: age, includesSubdomains: false, preloadRequested: false)))
    }
}
