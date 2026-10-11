import Testing
@testable import ATSDiagnostic
struct CURLImportTests {
    @Test func importsQuotedPayload() throws {
        let r = try CURLImport.parse("curl -H 'Content-Type: application/json' --data-raw '{\"name\":\"one two\"}' 'https://example.com?q=1&x=2'")
        #expect(r.method == "POST")
        #expect(r.body == "{\"name\":\"one two\"}")
        #expect(r.url == "https://example.com?q=1&x=2")
    }
    @Test func rejectsShellExecution() { #expect(throws: CURLImport.ImportError.self) { try CURLImport.parse("curl https://example.com; rm -rf x") } }
    @Test func rejectsFileRead() { #expect(throws: CURLImport.ImportError.self) { try CURLImport.parse("curl -d @secret https://example.com") } }
    @Test func roundTripsExport() throws {
        let r = DiagnosticRecord(url: "https://example.com", method: "POST", requestHeaders: ["X-Name": "O'Neil"], requestBody: "a'b")
        let imported = try CURLImport.parse(r.curl)
        #expect(imported.body == r.requestBody)
        #expect(imported.headers == "X-Name: O'Neil")
    }
    @Test func rejectsIncompleteQuotes() { #expect(throws: CURLImport.ImportError.self) { try CURLImport.parse("curl 'https://example.com") } }
}
