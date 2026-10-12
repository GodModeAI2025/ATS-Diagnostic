import Foundation
import Security
import CryptoKit

struct CertificateRecord: Identifiable, Codable, Sendable {
    let id: String
    let subject: String
    let der: Data
    var source: String? = nil
}
enum DiagnosticRecordOrigin: String, Codable, Sendable { case har, developerSDK }
struct DiagnosticRecord: Identifiable, Codable, Sendable {
    var id = UUID()
    var date = Date()
    var url: String
    var finalURL: String?
    var method: String
    var requestHeaders: [String: String] = [:]
    var requestBody: String = ""
    var status: Int?
    var responseHeaders: [String: String] = [:]
    var responseBody: String = ""
    var responseEncoding: String?
    var responseSHA256: String?
    var expectedSHA256: String?
    var integrityMatches: Bool?
    var bytes = 0
    var duration: Double = 0
    var protocolName: String?
    var tlsVersion: String?
    var cipher: String?
    var remoteAddress: String?
    var dnsDuration: Double?
    var connectDuration: Double?
    var tlsDuration: Double?
    var certificates: [CertificateRecord] = []
    var trustValid: Bool?
    var trustMessage: String?
    var certificateTransparency: Bool?
    var error: String?
    var networkErrors: [ErrorEvidence]?
    var trustErrors: [ErrorEvidence]?
    var clientCertificateRequested: Bool?
    var revocationChecked: Bool?
    var revocationAssessment: RevocationAssessment?
    var diagnosticOptions: DiagnosticOptions?
    var origin: DiagnosticRecordOrigin?
    var requestBodyUnavailable: Bool?
    var importedRequestBodyPreview: Data?
    var importedRequestBodyBytes: Int?
    var responseByteCountKnown: Bool?
    var importedResponseComplete: Bool?
    var importedObservedResponseBytes: Int?
    var canReplay: Bool { requestBodyUnavailable != true }
    var curl: String {
        let headers = requestHeaders.sorted { $0.key < $1.key }.map { "-H \(Self.quote("\($0.key): \($0.value)"))" }.joined(separator: " ")
        return "curl -X \(method) \(headers) \(requestBody.isEmpty ? "" : "--data-raw " + Self.quote(requestBody)) \(Self.quote(url))"
    }
    static func quote(_ text: String) -> String { "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'" }
}
enum Endpoint {
    static func parse(_ input: String) throws -> URL {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw URLError(.badURL) }
        let candidate = text.contains("://") ? text : "https://" + text
        guard let url = URL(string: candidate), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { throw URLError(.badURL) }
        return url
    }
}
final class DiagnosticEngine: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var record: DiagnosticRecord
    private var buffer = Data()
    private var hasher = SHA256()
    private let options: DiagnosticOptions
    private var bodyLimit: Int { options.bodyPreviewBytes }
    private var continuation: CheckedContinuation<DiagnosticRecord, Never>?
    private var session: URLSession?
    init(request: URLRequest, expectedSHA256: String? = nil, options: DiagnosticOptions = .standard) {
        self.options = options.validated
        record = DiagnosticRecord(url: request.url?.absoluteString ?? "", method: request.httpMethod ?? "GET", requestHeaders: request.allHTTPHeaderFields ?? [:], requestBody: request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? "")
        record.expectedSHA256 = expectedSHA256
        record.diagnosticOptions = self.options
    }
    func run(_ request: URLRequest, configuration: URLSessionConfiguration? = nil) async -> DiagnosticRecord {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            let config = configuration ?? URLSessionConfiguration.ephemeral
            let configuredRequest = options.configure(config, request: request)
            let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            self.session = session
            session.dataTask(with: configuredRequest).resume()
        }
    }
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            lock.withLock { record.clientCertificateRequested = true }
        }
        if let trust = challenge.protectionSpace.serverTrust { captureTrust(trust) }
        completionHandler(.performDefaultHandling, nil)
    }
    private func captureTrust(_ trust: SecTrust) {
        var error: CFError?
        let valid = SecTrustEvaluateWithError(trust, &error)
        let result = SecTrustCopyResult(trust) as? [String: Any]
        let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate] ?? []
        let certificates = chain.map { cert in
            let der = SecCertificateCopyData(cert) as Data
            return CertificateRecord(id: RootStoreSnapshot.fingerprint(der), subject: SecCertificateCopySubjectSummary(cert) as String? ?? "Certificate", der: der, source: "System-evaluated trust chain")
        }
        lock.withLock {
            record.certificates = certificates; record.trustValid = valid
            record.trustMessage = error.map { ($0 as Error).localizedDescription }
            record.trustErrors = error.map { ErrorEvidence.capture($0 as Error) }
            record.certificateTransparency = result?[kSecTrustCertificateTransparency as String] as? Bool
            record.revocationChecked = result?[kSecTrustRevocationChecked as String] as? Bool
        }
    }
    private func trustFromError(_ error: NSError, depth: Int = 0) -> SecTrust? {
        guard depth < 5 else { return nil }
        if let value = error.userInfo[NSURLErrorFailingURLPeerTrustErrorKey], CFGetTypeID(value as CFTypeRef) == SecTrustGetTypeID() { return (value as! SecTrust) }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError { return trustFromError(underlying, depth: depth + 1) }
        return nil
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
        lock.withLock {
            if let response = response as? HTTPURLResponse {
                record.finalURL = response.url?.absoluteString
                record.status = response.statusCode
                record.responseHeaders = Dictionary(uniqueKeysWithValues: response.allHeaderFields.map { (String(describing: $0.key), String(describing: $0.value)) })
            }
        }
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.withLock {
            hasher.update(data: data)
            record.bytes += data.count
            buffer.append(data.prefix(max(0, bodyLimit - buffer.count)))
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        lock.withLock {
            record.duration = metrics.taskInterval.duration
            if let m = metrics.transactionMetrics.last {
                record.protocolName = m.networkProtocolName
                record.remoteAddress = m.remoteAddress
                record.tlsVersion = m.negotiatedTLSProtocolVersion.map { String(format: "0x%04x", $0.rawValue) }
                record.cipher = m.negotiatedTLSCipherSuite.map { String(format: "0x%04x", $0.rawValue) }
                record.dnsDuration = interval(m.domainLookupStartDate, m.domainLookupEndDate)
                record.connectDuration = interval(m.connectStartDate, m.connectEndDate)
                record.tlsDuration = interval(m.secureConnectionStartDate, m.secureConnectionEndDate)
            }
        }
    }
    private func interval(_ start: Date?, _ end: Date?) -> Double? {
        guard let start, let end else { return nil }; return end.timeIntervalSince(start)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error, let trust = trustFromError(error as NSError) { captureTrust(trust) }
        let result = lock.withLock {
            record.networkErrors = error.map(ErrorEvidence.capture)
            record.error = error?.localizedDescription
            if error == nil {
                record.responseSHA256 = hasher.finalize().map { String(format: "%02x", $0) }.joined()
                record.integrityMatches = record.expectedSHA256.map { $0 == record.responseSHA256 }
            }
            if let text = String(data: buffer, encoding: .utf8) { record.responseBody = text } else { record.responseBody = buffer.base64EncodedString(); record.responseEncoding = "base64" }
            return record
        }
        continuation?.resume(returning: result)
        continuation = nil
        session.finishTasksAndInvalidate()
        self.session = nil
    }
}
