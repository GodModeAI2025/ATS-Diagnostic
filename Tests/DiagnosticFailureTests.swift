import Testing
import Foundation
import Security
@testable import ATSDiagnostic
struct DiagnosticFailureTests {
    private func record(_ code: Int,domain: String = NSURLErrorDomain,ssl: Int? = nil) -> DiagnosticRecord {
        var value = DiagnosticRecord(url:"https://expired.badssl.com",method:"GET")
        value.error = "Generic failure";value.networkErrors = [.init(domain:domain,code:code,message:"Generic failure",sslCode:ssl)]
        return value
    }
    @Test func noDiagnosisFromHostname() { #expect(DiagnosticFailure.explain(record(URLError.timedOut.rawValue))?.cause == .timeout) }
    @Test func specificTrustErrorWinsOverGenericTLSFailure() {
        var value = record(URLError.secureConnectionFailed.rawValue,ssl:Int(errSSLFatalAlert));value.trustValid = false;value.trustErrors = [.init(domain:NSOSStatusErrorDomain,code:Int(errSecHostNameMismatch),message:"Mismatch",sslCode:nil)]
        #expect(DiagnosticFailure.explain(value)?.cause == .hostname)
    }
    @Test func recordedATSFailureRemainsDistinctFromCertificateFailure() {
        #expect(DiagnosticFailure.explain(record(URLError.appTransportSecurityRequiresSecureConnection.rawValue))?.cause == .cleartext)
    }
    @Test func expiryUsesSystemEvidence() { #expect(DiagnosticFailure.explain(record(Int(errSecCertificateExpired),domain:NSOSStatusErrorDomain))?.cause == .expired) }
    @Test func tlsVersionUsesActualPeerAlert() { #expect(DiagnosticFailure.explain(record(URLError.secureConnectionFailed.rawValue,ssl:Int(errSSLPeerProtocolVersion)))?.cause == .tlsVersion) }
    @Test func genericHandshakeDoesNotGuessCipher() { #expect(DiagnosticFailure.explain(record(URLError.secureConnectionFailed.rawValue,ssl:Int(errSSLPeerHandshakeFail)))?.cause == .tlsHandshake) }
    @Test func httpAndClientCertificateAreSeparate() {
        var value = DiagnosticRecord(url:"https://client.badssl.com",method:"GET");value.status = 400;value.trustValid = true
        #expect(DiagnosticFailure.explain(value)?.cause == .http)
        value.clientCertificateRequested = true
        #expect(DiagnosticFailure.explain(value)?.cause == .clientCertificate)
    }
    @Test func failedExtraRevocationDoesNotRewriteSuccessfulTransport() {
        var value = DiagnosticRecord(url:"https://example.com",method:"GET");value.status = 200;value.trustValid = true
        value.revocationAssessment = .init(status:.inconclusive,checkedAt:Date(),detail:"Unknown",evidence:[.init(domain:NSOSStatusErrorDomain,code:Int(errSecCertificateExpired),message:"Extra policy",sslCode:nil)])
        #expect(DiagnosticFailure.explain(value) == nil)
        value.revocationAssessment = .init(status:.revoked,checkedAt:Date(),detail:"Revoked",evidence:[])
        #expect(DiagnosticFailure.explain(value)?.cause == .revoked)
        #expect(DiagnosticFailure.explain(value)?.meaning.contains("zusätzliche") == true)
    }
    @Test func evidenceCapturesNestedSSLCode() {
        let inner = NSError(domain:"kCFErrorDomainCFNetwork",code:-1200,userInfo:["_kCFStreamErrorDomainKey":3,"_kCFStreamErrorCodeKey":-9836])
        let outer = NSError(domain:NSURLErrorDomain,code:-1200,userInfo:[NSUnderlyingErrorKey:inner])
        let traces = ErrorEvidence.capture(outer)
        #expect(traces.count == 2);#expect(traces.last?.sslCode == -9836)
    }
    @Test func oldRecordKeepsRawUnknownFailure() {
        var value = DiagnosticRecord(url:"https://self-signed.badssl.com",method:"GET");value.error = "Old failure"
        #expect(DiagnosticFailure.explain(value)?.cause == .unknown)
    }
}
