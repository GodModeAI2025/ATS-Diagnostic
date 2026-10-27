#if targetEnvironment(macCatalyst)
import SwiftUI
import Testing
@testable import ATSDiagnostic

@MainActor struct MacTechnicalTextEditorTests {
    @Test func technicalInputDisablesTextSubstitutions() {
        let view = MacTechnicalTextEditor.Input(accessibilityName: "Request body")
        #expect(view.smartQuotesType == .no)
        #expect(view.smartDashesType == .no)
        #expect(view.smartInsertDeleteType == .no)
        #expect(view.autocorrectionType == .no)
        #expect(view.autocapitalizationType == .none)
        #expect(view.spellCheckingType == .no)
    }

    @Test func editsPreserveLiteralProtocolText() {
        var draft = ""
        let coordinator = MacTechnicalTextEditor.Coordinator(text: Binding(get: { draft }, set: { draft = $0 }))
        let view = MacTechnicalTextEditor.Input(accessibilityName: "Request body")
        let literal = #"{"key":"value--unchanged","quote":"\""}"# + "\nX-Test: two  spaces\tend"
        view.text = literal
        coordinator.textViewDidChange(view)
        #expect(draft == literal)
    }
}
#endif
