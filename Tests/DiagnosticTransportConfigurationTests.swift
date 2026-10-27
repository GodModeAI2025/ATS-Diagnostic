import Foundation
import Testing
@testable import ATSDiagnostic

struct DiagnosticTransportConfigurationTests {
    @Test func diagnosticTransportExceptionsRemainEffective() throws {
        let bundle = Bundle(for: DiagnosticStore.self)
        let ats = try #require(bundle.object(forInfoDictionaryKey: "NSAppTransportSecurity") as? [String: Any])
        #expect(ats["NSAllowsArbitraryLoads"] as? Bool == true)
        // These fine-grained keys would override the global diagnostic exception.
        for key in ["NSAllowsLocalNetworking", "NSAllowsArbitraryLoadsForMedia", "NSAllowsArbitraryLoadsInWebContent"] {
            #expect(ats[key] == nil)
        }
        #expect(!(bundle.object(forInfoDictionaryKey: "NSLocalNetworkUsageDescription") as? String ?? "").isEmpty)
        #expect(bundle.object(forInfoDictionaryKey: "UIBackgroundModes") == nil)
    }
}
