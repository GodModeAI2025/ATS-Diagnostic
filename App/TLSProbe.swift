import Foundation
import Network
import Security
import CryptoKit

struct TLSProbeResult: Identifiable, Sendable {
    let id: String
    let completed: Bool
    let trustValid: Bool?
    let detail: String
    let certificates: [CertificateRecord]
}
final class TLSProbe: @unchecked Sendable {
    private let queue = DispatchQueue(label: "ATS Diagnostic TLS probe")
    private var connection: NWConnection?
    private var continuation: CheckedContinuation<TLSProbeResult, Never>?
    private var certificates: [CertificateRecord] = []
    private var trustValid: Bool?
    private var trustError: String?
    private let title: String
    init(title: String) { self.title = title }
    func run(host: String, port: UInt16, version: tls_protocol_version_t) async -> TLSProbeResult {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                self.continuation = continuation
                let options = NWProtocolTLS.Options()
                sec_protocol_options_set_min_tls_protocol_version(options.securityProtocolOptions, version)
                sec_protocol_options_set_max_tls_protocol_version(options.securityProtocolOptions, version)
                sec_protocol_options_set_tls_server_name(options.securityProtocolOptions, host)
                sec_protocol_options_set_verify_block(options.securityProtocolOptions, { [self] _, trust, complete in
                    let reference = sec_trust_copy_ref(trust).takeRetainedValue()
                    SecTrustSetPolicies(reference, SecPolicyCreateSSL(true, host as CFString))
                    var error: CFError?
                    trustValid = SecTrustEvaluateWithError(reference, &error)
                    trustError = error.map { ($0 as Error).localizedDescription }
                    certificates = (SecTrustCopyCertificateChain(reference) as? [SecCertificate] ?? []).map { certificate in
                        let der = SecCertificateCopyData(certificate) as Data
                        return CertificateRecord(id: SHA256.hash(data: der).map { String(format: "%02x", $0) }.joined(), subject: SecCertificateCopySubjectSummary(certificate) as String? ?? "Certificate", der: der)
                    }
                    complete(trustValid == true)
                }, queue)
                let parameters = NWParameters(tls: options, tcp: NWProtocolTCP.Options())
                let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port) ?? .https, using: parameters)
                self.connection = connection
                connection.stateUpdateHandler = { [self] state in
                    switch state {
                    case .ready:
                        let metadata = connection.metadata(definition: NWProtocolTLS.definition) as? NWProtocolTLS.Metadata
                        let negotiated = metadata.map { sec_protocol_metadata_get_negotiated_tls_protocol_version($0.securityProtocolMetadata) }
                        let reported = negotiated.map { String(format: "0x%04x", $0.rawValue) } ?? "not reported"
                        finish(completed: negotiated == version, detail: "Negotiated TLS: \(reported). System trust validation succeeded." )
                    case .failed(let error): finish(completed: false, detail: trustError ?? error.localizedDescription)
                    case .waiting(let error): finish(completed: false, detail: error.localizedDescription)
                    default: break
                    }
                }
                connection.start(queue: queue)
                queue.asyncAfter(deadline: .now() + 10) { [self] in finish(completed: false, detail: "Handshake timed out.") }
            }
        }
    }
    private func finish(completed: Bool, detail: String) {
        guard let continuation else { return }
        self.continuation = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        continuation.resume(returning: TLSProbeResult(id: title, completed: completed, trustValid: trustValid, detail: detail, certificates: certificates))
    }
    static func allVersions(_ input: String) async throws -> [TLSProbeResult] {
        let url = try Endpoint.parse(input)
        guard let host = url.host, let port = UInt16(exactly: url.port ?? 443), port > 0 else { throw URLError(.badURL) }
        let versions: [(String, tls_protocol_version_t)] = [("TLS 1.0", .TLSv10), ("TLS 1.1", .TLSv11), ("TLS 1.2", .TLSv12), ("TLS 1.3", .TLSv13)]
        var results: [TLSProbeResult] = []
        for (name, version) in versions { results.append(await TLSProbe(title: name).run(host: host, port: port, version: version)) }
        return results
    }
}
