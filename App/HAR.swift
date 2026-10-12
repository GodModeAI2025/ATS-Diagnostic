import Foundation
import UniformTypeIdentifiers
import CoreTransferable

struct HARArchive: Codable, Transferable {
    struct Log: Codable { var version = "1.2"; var creator = Creator(); var entries: [Entry] }
    struct Creator: Codable { var name = "ATS Diagnostic"; var version = "2.0" }
    struct Header: Codable { let name: String; let value: String }
    struct PostData: Codable { let mimeType: String; let text: String }
    struct Request: Codable { let method: String; let url: String; let httpVersion: String; let cookies: [String]; let headers: [Header]; let queryString: [Header]; let headersSize: Int; let bodySize: Int; let postData: PostData? }
    struct Content: Codable { let size: Int; let mimeType: String; let text: String; let encoding: String? }
    struct Response: Codable { let status: Int; let statusText: String; let httpVersion: String; let cookies: [String]; let headers: [Header]; let content: Content; let redirectURL: String; let headersSize: Int; let bodySize: Int }
    struct Timings: Codable { let send: Double; let wait: Double; let receive: Double; let dns: Double; let connect: Double; let ssl: Double }
    struct Metadata: Codable { let source: String; let responseSHA256: String?; let errorDomain: String?; let errorCode: Int?; let errorDescription: String?; let requestBodyUnavailable: Bool?; let requestBodyPreviewBase64: String?; let responseBytesKnown: Bool?; let responseComplete: Bool?; let observedResponseBytes: Int? }
    struct Entry: Codable { let startedDateTime: String; let time: Double; let request: Request; let response: Response; let cache: [String: String]; let timings: Timings; let serverIPAddress: String?; let _atsDiagnostic: Metadata? }
    let log: Log
    init(records: [DiagnosticRecord]) {
        log = Log(entries: records.map { record in
            let query = URLComponents(string: record.url)?.queryItems?.map { Header(name: $0.name, value: $0.value ?? "") } ?? []
            let version = record.protocolName == "h2" ? "HTTP/2.0" : record.protocolName == "h3" ? "HTTP/3.0" : record.protocolName ?? ""
            return Entry(startedDateTime: record.date.ISO8601Format(), time: record.duration * 1000,
                request: Request(method: record.method, url: record.url, httpVersion: version, cookies: [], headers: record.requestHeaders.map { Header(name: $0.key, value: $0.value) }, queryString: query, headersSize: -1, bodySize: record.requestBodyUnavailable == true ? (record.importedRequestBodyBytes ?? -1) : record.requestBody.utf8.count, postData: record.requestBody.isEmpty ? nil : PostData(mimeType: record.requestHeaders.first { $0.key.lowercased() == "content-type" }?.value ?? "application/octet-stream", text: record.requestBody)),
                response: Response(status: record.status ?? 0, statusText: record.status.map { HTTPURLResponse.localizedString(forStatusCode: $0) } ?? "", httpVersion: version, cookies: [], headers: record.responseHeaders.map { Header(name: $0.key, value: $0.value) }, content: Content(size: record.responseByteCountKnown == false ? -1 : record.bytes, mimeType: record.responseHeaders.first { $0.key.lowercased() == "content-type" }?.value ?? "application/octet-stream", text: record.responseBody, encoding: record.responseEncoding), redirectURL: record.responseHeaders.first { $0.key.lowercased() == "location" }?.value ?? "", headersSize: -1, bodySize: record.responseByteCountKnown == false ? -1 : record.bytes),
                cache: [:], timings: Timings(send: -1, wait: -1, receive: -1, dns: record.dnsDuration.map { $0 * 1000 } ?? -1, connect: record.connectDuration.map { $0 * 1000 } ?? -1, ssl: record.tlsDuration.map { $0 * 1000 } ?? -1), serverIPAddress: record.remoteAddress, _atsDiagnostic: Metadata(source: record.origin == .developerSDK ? "ATSRecording" : "ATS Diagnostic", responseSHA256: record.responseSHA256, errorDomain: record.networkErrors?.first?.domain, errorCode: record.networkErrors?.first?.code, errorDescription: record.error, requestBodyUnavailable: record.requestBodyUnavailable, requestBodyPreviewBase64: record.importedRequestBodyPreview?.base64EncodedString(), responseBytesKnown: record.responseByteCountKnown, responseComplete: record.importedResponseComplete, observedResponseBytes: record.importedObservedResponseBytes))
        })
    }
    func records() throws -> [DiagnosticRecord] { try Self.importRecords(JSONEncoder().encode(self)) }
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { archive in let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; return try encoder.encode(archive) }.suggestedFileName("ATS-Diagnostic.har")
    }
}

extension HARArchive {
    enum ImportError: LocalizedError {
        case malformed
        var errorDescription: String? { "Select a HAR file containing a log.entries array and valid request URLs." }
    }
    static func importRecords(_ data: Data) throws -> [DiagnosticRecord] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], let log = root["log"] as? [String: Any], let entries = log["entries"] as? [[String: Any]], entries.count <= 10000 else { throw ImportError.malformed }
        let date = ISO8601DateFormatter()
        let fractionalDate = ISO8601DateFormatter(); fractionalDate.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        func headers(_ input: Any?) -> [String: String] {
            Dictionary((input as? [[String: Any]] ?? []).compactMap { entry in
                guard let name = entry["name"] as? String, let value = entry["value"] as? String else { return nil }
                return (name, value)
            }, uniquingKeysWith: { _, last in last })
        }
        return try entries.map { entry in
            guard let request = entry["request"] as? [String: Any], let url = request["url"] as? String else { throw ImportError.malformed }
            _ = try Endpoint.parse(url)
            let response = entry["response"] as? [String: Any] ?? [:]
            let content = response["content"] as? [String: Any] ?? [:]
            let post = request["postData"] as? [String: Any] ?? [:]
            let timings = entry["timings"] as? [String: Any] ?? [:]
            let text = content["text"] as? String ?? ""
            let timestamp = entry["startedDateTime"] as? String ?? ""
            let reportedProtocol = response["httpVersion"] as? String
            let protocolName = reportedProtocol?.isEmpty == true ? nil : reportedProtocol
            let status = response["status"] as? Int
            let metadata = entry["_atsDiagnostic"] as? [String: Any] ?? [:]
            let source: DiagnosticRecordOrigin = metadata["source"] as? String == "ATSRecording" ? .developerSDK : .har
            let errorMessage = metadata["errorDescription"] as? String ?? entry["_error"] as? String
            let evidence: [ErrorEvidence]?
            if let domain = metadata["errorDomain"] as? String, let code = metadata["errorCode"] as? Int { evidence = [ErrorEvidence(domain: domain, code: code, message: errorMessage ?? domain, sslCode: nil)] } else { evidence = nil }
            let requestText = post["text"] as? String
            let declaredRequestBytes = request["bodySize"] as? Int
            let missingBody = (declaredRequestBytes ?? 0) > 0 && requestText == nil
            let mismatchedBody = declaredRequestBytes.map { $0 >= 0 && requestText != nil && $0 != requestText!.utf8.count } ?? false
            let bodyEncoding = (post["encoding"] as? String ?? post["_encoding"] as? String ?? "").lowercased()
            let unavailable = (metadata["requestBodyUnavailable"] as? Bool ?? false) || missingBody || mismatchedBody || (!bodyEncoding.isEmpty && bodyEncoding != "utf8" && bodyEncoding != "utf-8")
            let responseComplete = metadata["responseComplete"] as? Bool
            let reportedHash = responseComplete == false ? nil : (try? Integrity.normalizeSHA256(metadata["responseSHA256"] as? String ?? ""))
            let byteCountKnown = responseComplete == false ? false : (metadata["responseBytesKnown"] as? Bool ?? ((content["size"] as? Int).map { $0 >= 0 } ?? false))
            let previewBytes = content["encoding"] as? String == "base64" ? (Data(base64Encoded: text)?.count ?? 0) : text.utf8.count
            let observedBytes = (metadata["observedResponseBytes"] as? Int).flatMap { $0 >= previewBytes && $0 >= 0 ? $0 : nil }
            func phase(_ key: String) -> Double? { guard let duration = timings[key] as? Double, duration >= 0 else { return nil }; return duration / 1000 }
            return DiagnosticRecord(date: fractionalDate.date(from: timestamp) ?? date.date(from: timestamp) ?? Date(), url: url, method: request["method"] as? String ?? "GET", requestHeaders: headers(request["headers"]), requestBody: post["text"] as? String ?? "", status: status == 0 ? nil : status, responseHeaders: headers(response["headers"]), responseBody: text, responseEncoding: content["encoding"] as? String, responseSHA256: reportedHash, bytes: responseComplete == false ? 0 : max(0, content["size"] as? Int ?? text.utf8.count), duration: max(0, (entry["time"] as? Double ?? 0) / 1000), protocolName: protocolName, remoteAddress: entry["serverIPAddress"] as? String, dnsDuration: phase("dns"), connectDuration: phase("connect"), tlsDuration: phase("ssl"), error: errorMessage, networkErrors: evidence, origin: source, requestBodyUnavailable: unavailable, importedRequestBodyPreview: (metadata["requestBodyPreviewBase64"] as? String).flatMap { Data(base64Encoded: $0) }, importedRequestBodyBytes: (request["bodySize"] as? Int).flatMap { $0 >= 0 ? $0 : nil }, responseByteCountKnown: byteCountKnown, importedResponseComplete: responseComplete, importedObservedResponseBytes: observedBytes)
        }
    }
}
struct DiagnosticLogExport: Transferable {
    let records: [DiagnosticRecord]
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { value in
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            var data = Data()
            for record in value.records { data.append(try encoder.encode(record)); data.append(0x0a) }
            return data
        }.suggestedFileName("ATS-Diagnostic.ndjson")
    }
}
