import Testing
@testable import ATSRecording

@MainActor struct RecordingActivationTests {
    @Test func disabledActivationDoesNotPresentAnything() {
        let activation = RecordingActivation()
        var calls = 0
        activation.handler = { _ in calls += 1 }
        #expect(!activation.activate()); #expect(calls == 0)
    }
    @Test func hostReceivesTheCorrectTriggerAndCanDisableIt() {
        let activation = RecordingActivation()
        var triggers: [RecordingActivationSource] = []
        activation.handler = { triggers.append($0) }
        activation.isEnabled = true
        #expect(activation.activate()); #expect(activation.activate(source: .shake))
        #expect(triggers.count == 2)
        if case .custom = triggers[0] {} else { Issue.record("Expected custom activation") }
        if case .shake = triggers[1] {} else { Issue.record("Expected shake activation") }
        activation.isEnabled = false
        #expect(!activation.activate(source: .shake)); #expect(triggers.count == 2)
    }
    @Test func noHandlerLeavesMotionUnhandled() {
        let activation = RecordingActivation(); activation.isEnabled = true
        #expect(!activation.activate(source: .shake))
    }
}
