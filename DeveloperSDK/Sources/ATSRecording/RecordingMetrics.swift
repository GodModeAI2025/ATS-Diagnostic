import Foundation

/// Foundation transport metrics, distinct from application body-consumption time.
public struct RecordedTaskMetrics: Codable, Sendable {
    public let duration: Double
    public let redirectCount: Int
    public let transactionCount: Int
    public let transactionsTruncated: Bool
    public let transactions: [Transaction]
    public struct Transaction: Codable, Sendable {
        public let url: String?
        public let status: Int?
        public let protocolName: String?
        public let remoteAddress: String?
        public let localAddress: String?
        public let reusedConnection: Bool
        public let proxyConnection: Bool
        public let fetchType: Int
        public let dnsDuration: Double?
        public let connectDuration: Double?
        public let tlsDuration: Double?
        public let sendDuration: Double?
        public let waitDuration: Double?
        public let receiveDuration: Double?
        public let tlsProtocol: String?
        public let tlsCipher: String?
    }
    init(_ metrics: URLSessionTaskMetrics) {
        duration = metrics.taskInterval.duration
        redirectCount = metrics.redirectCount
        transactionCount = metrics.transactionMetrics.count
        transactionsTruncated = transactionCount > 128
        transactions = metrics.transactionMetrics.prefix(128).map { m in
            Transaction(url: m.request.url?.absoluteString, status: (m.response as? HTTPURLResponse)?.statusCode,
                        protocolName: m.networkProtocolName, remoteAddress: m.remoteAddress, localAddress: m.localAddress,
                        reusedConnection: m.isReusedConnection, proxyConnection: m.isProxyConnection, fetchType: m.resourceFetchType.rawValue,
                        dnsDuration: Self.interval(m.domainLookupStartDate,m.domainLookupEndDate),
                        connectDuration: Self.interval(m.connectStartDate,m.connectEndDate),
                        tlsDuration: Self.interval(m.secureConnectionStartDate,m.secureConnectionEndDate),
                        sendDuration: Self.interval(m.requestStartDate,m.requestEndDate),
                        waitDuration: Self.interval(m.requestEndDate,m.responseStartDate),
                        receiveDuration: Self.interval(m.responseStartDate,m.responseEndDate),
                        tlsProtocol: m.negotiatedTLSProtocolVersion.map { String(format:"0x%04x",$0.rawValue) },
                        tlsCipher: m.negotiatedTLSCipherSuite.map { String(format:"0x%04x",$0.rawValue) })
        }
    }
    static func interval(_ start: Date?, _ end: Date?) -> Double? {
        guard let start, let end else { return nil }
        let result = end.timeIntervalSince(start)
        return result >= 0 && result.isFinite ? result : nil
    }
}

/// Other Objective-C delegate callbacks retain the host's implementation, including
/// authentication and redirects. Only the metrics callback is observed and forwarded.
final class RecordingMetricsDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let target: (any URLSessionTaskDelegate)?
    private let lock = NSLock()
    private var captured: RecordedTaskMetrics?
    init(target: (any URLSessionTaskDelegate)?) { self.target = target; super.init() }
    func snapshot() -> RecordedTaskMetrics? { lock.withLock { captured } }
    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || target?.responds(to: selector) == true
    }
    override func forwardingTarget(for selector: Selector!) -> Any? {
        if target?.responds(to: selector) == true { return target }
        return super.forwardingTarget(for: selector)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        let value = RecordedTaskMetrics(metrics)
        lock.withLock { captured = value }
        target?.urlSession?(session, task: task, didFinishCollecting: metrics)
    }
}
