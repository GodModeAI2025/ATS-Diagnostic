import Testing
@testable import ATSDiagnostic
struct IntegrityTests {
    @Test func acceptsColonSeparatedDigest() throws {
        let hex = String(repeating: "AB:", count: 31) + "AB"
        #expect(try Integrity.normalizeSHA256(hex) == String(repeating: "ab", count: 32))
    }
    @Test func rejectsTruncatedChecksum() { #expect(throws: Integrity.ValidationError.self) { try Integrity.normalizeSHA256("abcd") } }
    @Test func rejectsNonHexadecimal() { #expect(throws: Integrity.ValidationError.self) { try Integrity.normalizeSHA256(String(repeating: "z", count: 64)) } }
    @Test func emptyMeansNoExpectedChecksum() throws { #expect(try Integrity.normalizeSHA256("  ") == nil) }
    @Test func copiedGroupedChecksumCanBeUsedAsExpectedDigest() throws {
        let raw = String(repeating: "ab", count: 32)
        let shown = Integrity.groupedDigest(raw)
        #expect(shown.split(separator: " ").count == 16)
        #expect(!shown.contains("-"))
        #expect(try Integrity.normalizeSHA256(shown.replacingOccurrences(of: " ", with: "\n")) == raw)
    }

}
