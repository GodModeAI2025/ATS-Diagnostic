import Testing
@testable import ATSDiagnostic
struct RecordingSettingsTests {
    @Test func excludesRegexMatches() { var settings = RecordingSettings(); settings.excludedURLPatterns = "example\\.com/private"; #expect(!settings.accepts("https://example.com/private/data")); #expect(settings.accepts("https://example.com/public")) }
    @Test func rejectsMalformedPattern() { var settings = RecordingSettings(); settings.excludedURLPatterns = "["; #expect(throws: (any Error).self) { try settings.validate() } }
    @Test func categoriesIgnoreHeaderCase() { let record = DiagnosticRecord(url: "https://example.com", method: "GET", responseHeaders: ["CONTENT-TYPE": "application/problem+json"]); #expect(ResponseCategory.json.matches(record)); #expect(!ResponseCategory.html.matches(record)) }
    @Test func statisticsHaveNoDivideByZero() { #expect(TrafficStatistics([]).averageDuration == 0) }
}
