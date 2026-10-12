import Foundation

/// Native transport steps. Imported snapshots are reported evidence, not a new scan.
struct ConnectionMetrics: Codable, Sendable {
    let duration: Double
    let redirectCount: Int
    let transactionCount: Int
    let transactionsTruncated: Bool
    let transactions: [Transaction]
    struct Transaction: Codable, Sendable {
        let url: String?
        let status: Int?
        let protocolName: String?
        let remoteAddress: String?
        let localAddress: String?
        let reusedConnection: Bool
        let proxyConnection: Bool
        let fetchType: Int
        let dnsDuration: Double?
        let connectDuration: Double?
        let tlsDuration: Double?
        let sendDuration: Double?
        let waitDuration: Double?
        let receiveDuration: Double?
        let tlsProtocol: String?
        let tlsCipher: String?
    }
    init(_ metrics: URLSessionTaskMetrics) {
        duration = metrics.taskInterval.duration
        redirectCount = metrics.redirectCount
        transactionCount = metrics.transactionMetrics.count
        transactionsTruncated = transactionCount > 128
        transactions = metrics.transactionMetrics.prefix(128).map { m in
            Transaction(url:m.request.url?.absoluteString,status:(m.response as? HTTPURLResponse)?.statusCode,
                        protocolName:m.networkProtocolName,remoteAddress:m.remoteAddress,localAddress:m.localAddress,
                        reusedConnection:m.isReusedConnection,proxyConnection:m.isProxyConnection,fetchType:m.resourceFetchType.rawValue,
                        dnsDuration:Self.interval(m.domainLookupStartDate,m.domainLookupEndDate),connectDuration:Self.interval(m.connectStartDate,m.connectEndDate),
                        tlsDuration:Self.interval(m.secureConnectionStartDate,m.secureConnectionEndDate),sendDuration:Self.interval(m.requestStartDate,m.requestEndDate),
                        waitDuration:Self.interval(m.requestEndDate,m.responseStartDate),receiveDuration:Self.interval(m.responseStartDate,m.responseEndDate),
                        tlsProtocol:m.negotiatedTLSProtocolVersion.map { String(format:"0x%04x",$0.rawValue) },tlsCipher:m.negotiatedTLSCipherSuite.map { String(format:"0x%04x",$0.rawValue) })
        }
    }
    static func interval(_ start: Date?, _ end: Date?) -> Double? {
        guard let start, let end else { return nil }
        let value = end.timeIntervalSince(start)
        return value >= 0 && value.isFinite ? value : nil
    }
    private enum CodingKeys: String, CodingKey { case duration, redirectCount, transactionCount, transactionsTruncated, transactions }
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy:CodingKeys.self)
        duration = try c.decode(Double.self,forKey:.duration)
        redirectCount = try c.decode(Int.self,forKey:.redirectCount)
        transactionCount = try c.decode(Int.self,forKey:.transactionCount)
        let all = try c.decode([Transaction].self,forKey:.transactions)
        guard duration.isFinite, duration >= 0, redirectCount >= 0, transactionCount >= all.count else {
            throw DecodingError.dataCorruptedError(forKey:.duration,in:c,debugDescription:"Invalid transport metrics")
        }
        transactionsTruncated = (try c.decode(Bool.self,forKey:.transactionsTruncated)) || transactionCount > all.count || all.count > 128
        transactions = Array(all.prefix(128))
    }
}
