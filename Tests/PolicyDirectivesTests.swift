import Testing
@testable import ATSDiagnostic
struct PolicyDirectivesTests {
    @Test func cspKeepsValuesTogether() {
        let directives = PolicyDirectives.parse(name: "Content-Security-Policy", value: "default-src 'self'; img-src https: data:; upgrade-insecure-requests")
        #expect(directives.map(\.name) == ["default-src","img-src","upgrade-insecure-requests"])
        #expect(directives[1].value == "https: data:")
    }
    @Test func permissionsKeepQuotedCommas() {
        let directives = PolicyDirectives.parse(name: "Permissions-Policy", value: "camera=(), fullscreen=(self \"https://example.com/a,b\"), geolocation=*")
        #expect(directives.count == 3)
        #expect(directives[1].value == "(self \"https://example.com/a,b\")")
        #expect(directives[2].name == "geolocation")
    }
    @Test func otherHeadersAreNotInterpretedAsPolicies() { #expect(PolicyDirectives.parse(name: "Set-Cookie", value: "name=value; Secure").isEmpty) }
}
