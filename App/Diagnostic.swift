import Foundation
import Security
import CryptoKit

struct CertificateRecord: Identifiable, Codable, Sendable {
    let id: String
    let subject: String
    let der: Data
}
struct DiagnosticRecord: Identifiable, Codable, Sendable {
    var id = UUID()
    var date = Date()
    var url: String
    var method: String
    var requestHeaders: [String: String] = [:]
    var requestBody: String = ""
    var status: Int?
    var responseHeaders: [String: String] = [:]
    var responseBody: String = ""
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
    var error: String?
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
    private let bodyLimit = 2 * 1024 * 1024
    private var continuation: CheckedContinuation<DiagnosticRecord, Never>?
    private var session: URLSession?
    init(request: URLRequest) {
        record = DiagnosticRecord(url: request.url?.absoluteString ?? "", method: request.httpMethod ?? "GET", requestHeaders: request.allHTTPHeaderFields ?? [:], requestBody: request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? "")
    }
    func run(_ request: URLRequest) async -> DiagnosticRecord {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 20
            config.timeoutIntervalForResource = 30
            config.urlCache = nil
            let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            self.session = session
            session.dataTask(with: request).resume()
        }
    }
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            var error: CFError?
            let valid = SecTrustEvaluateWithError(trust, &error)
            let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate] ?? []
            let certificates = chain.map { cert in
                let der = SecCertificateCopyData(cert) as Data
                return CertificateRecord(id: SHA256.hash(data: der).map { String(format: "%02x", $0) }.joined(), subject: SecCertificateCopySubjectSummary(cert) as String? ?? "Certificate", der: der)
            }
            lock.withLock {
                record.certificates = certificates
                record.trustValid = valid
                record.trustMessage = error.map { ($0 as Error).localizedDescription }
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
        lock.withLock {
            if let response = response as? HTTPURLResponse {
                record.status = response.statusCode
                record.responseHeaders = Dictionary(uniqueKeysWithValues: response.allHeaderFields.map { (String(describing: $0.key), String(describing: $0.value)) })
            }
        }
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.withLock {
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
        let result = lock.withLock {
            record.error = error?.localizedDescription
            record.responseBody = String(data: buffer, encoding: .utf8) ?? buffer.base64EncodedString()
            return record
        }
        continuation?.resume(returning: result)
        continuation = nil
        session.finishTasksAndInvalidate()
        self.session = nil
    }
}
