import Testing
@testable import ATSDiagnostic

struct URLQueryDetailsTests {
    @Test func duplicatesMissingEmptyAndEncodedDelimitersStayDistinct() {
        let query = URLQueryDetails(url: "https://example.com/?a=1&a=2&flag&empty=&q=a+b&name=caf%C3%A9%26x&eq=a%3Db#fragment?ignored=1")
        #expect(query.parameterCount == 7)
        #expect(query.parameters.map(\.rawName) == ["a", "a", "flag", "empty", "q", "name", "eq"])
        #expect(query.parameters[2].rawValue == nil); #expect(query.parameters[3].value == "")
        #expect(query.parameters[4].value == "a+b")
        #expect(query.parameters[5].value == "café&x"); #expect(query.parameters[6].value == "a=b")
    }
    @Test func malformedEscapesArePreservedWithoutNormalization() {
        let query = URLQueryDetails(url: "https://example.com/?bad=%GG&%FF=x&partial=%&once=%2526")
        #expect(query.parameters[0].rawValue == "%GG"); #expect(query.parameters[0].value == nil)
        #expect(query.parameters[1].name == nil); #expect(query.parameters[2].value == nil)
        #expect(query.parameters[3].value == "%26")
    }
    @Test func emptyQueriesAndEmptySegmentsRemainExplicit() {
        #expect(!URLQueryDetails(url: "https://example.com/#?notQuery").hasQuery)
        #expect(URLQueryDetails(url: "https://example.com/?").hasQuery)
        #expect(URLQueryDetails(url: "https://example.com/?").parameters.isEmpty)
        let query = URLQueryDetails(url: "https://example.com/?&=x&&")
        #expect(query.parameterCount == 4); #expect(query.parameters[1].rawName == "")
        #expect(query.parameters[1].value == "x")
        #expect(Set(query.parameters.map(\.id)).count == 4)
        #expect(query.parameters.map(\.id) == URLQueryDetails(url: "https://example.com/?&=x&&").parameters.map(\.id))
    }
    @Test func retainedRowsAndOversizedQueriesAreBoundedExplicitly() {
        let query = URLQueryDetails(url: "https://example.com/?" + Array(repeating: "a=1", count: 300).joined(separator: "&"))
        #expect(query.parameterCount == 300); #expect(query.parameters.count == 256)
        let huge = URLQueryDetails(url: "https://example.com/?" + String(repeating: "x", count: 65_537))
        #expect(huge.oversized); #expect(huge.parameterCount == nil); #expect(huge.parameters.isEmpty)
    }
    @Test func controlsAndBackslashesHaveUnambiguousDisplay() {
        let query = URLQueryDetails(url: "https://example.com/?q=one%0Atwo%5Cn%00%E2%80%AE")
        #expect(query.parameters[0].value == "one\ntwo\\n\u{0}\u{202e}")
        #expect(URLQueryDetails.visibleText(query.parameters[0].value!) == "one\\ntwo\\\\n\\u{0}\\u{202E}")
    }
}
