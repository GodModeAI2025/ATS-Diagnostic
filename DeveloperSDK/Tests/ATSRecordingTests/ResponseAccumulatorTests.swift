import Foundation
import Testing
@testable import ATSRecording
struct ResponseAccumulatorTests {
    @Test func chunksPreserveFullDigestAndBoundedPrefix() {
        var value = RecordingResponseAccumulator(previewLimit: 2)
        value.receive(Data("a".utf8)); value.receive(Data("bc".utf8))
        let result = value.snapshot(transportSucceeded: true)
        #expect(result.preview == Data("ab".utf8)); #expect(result.observedBytes == 3)
        #expect(result.sha256 == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(result.complete)
    }
    @Test func partialFailureKeepsCountWithoutHash() {
        var value = RecordingResponseAccumulator(previewLimit: 0)
        value.receive(Data("abc".utf8))
        let result = value.snapshot(transportSucceeded: false)
        #expect(result.preview.isEmpty); #expect(result.observedBytes == 3)
        #expect(result.sha256 == nil); #expect(!result.complete)
    }
    @Test func emptySuccessHasEmptyDigest() {
        let result = RecordingResponseAccumulator(previewLimit: 64).snapshot(transportSucceeded: true)
        #expect(result.observedBytes == 0)
        #expect(result.sha256 == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }
}
