import Foundation
import Testing
@testable import ATSDiagnostic

struct HTTPRequestFieldsTests {
    @Test func validCustomMethodAndWindowsHeadersAreAccepted() throws {
        let fields = try HTTPRequestFields.parseHeaders("X-One: first\r\nX-Two: second\r\n")
        try HTTPRequestFields.validate(method: "PROPFIND", headers: fields)
        #expect(fields == ["X-One": "first", "X-Two": "second"])
        try HTTPRequestFields.validate(method: "GET", headers: ["X-Token": "a\tb", "X-Text": "Grüße"])
    }
    @Test func controlCharactersCannotReachNativeRequestSetters() {
        #expect(throws: HTTPRequestFields.ValidationError.self) { try HTTPRequestFields.validate(method: "GET\r\nInjected", headers: [:]) }
        #expect(throws: HTTPRequestFields.ValidationError.self) { try HTTPRequestFields.validate(method: "GET", headers: ["Bad Name": "value"]) }
        #expect(throws: HTTPRequestFields.ValidationError.self) { try HTTPRequestFields.validate(method: "GET", headers: ["X-Test": "value\r\nInjected: yes"]) }
        #expect(throws: HTTPRequestFields.ValidationError.self) { try HTTPRequestFields.validate(method: "GET", headers: ["X-Test": "value\u{0}"]) }
    }
    @Test func malformedImportedRequestRemainsReadableButCannotReplay() {
        var record = DiagnosticRecord(url: "https://example.com", method: "GET")
        record.requestHeaders = ["X-Test": "value\nInjected: yes"]
        #expect(!record.canReplay); #expect(record.requestFormatError != nil)
        #expect(record.requestBodyUnavailable != true)
    }
    @MainActor @Test func invalidDirectRequestIsExplainedBeforeNetworkExecution() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let store = DiagnosticStore(historyFile: file)
        await store.execute(url: "https://fixture.invalid", method: "GET BAD")
        #expect(store.error?.contains("HTTP-Methode") == true)
        #expect(store.latest == nil); #expect(store.records.isEmpty); #expect(!store.running)
    }
}
