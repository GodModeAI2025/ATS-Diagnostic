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
    struct Entry: Codable { let startedDateTime: String; let time: Double; let request: Request; let response: Response; let cache: [String: String]; let timings: Timings; let serverIPAddress: String? }
    let log: Log
    init(records: [DiagnosticRecord]) {
        log = Log(entries: records.map { record in
            let query = URLComponents(string: record.url)?.queryItems?.map { Header(name: $0.name, value: $0.value ?? "") } ?? []
            let version = record.protocolName == "h2" ? "HTTP/2.0" : record.protocolName == "h3" ? "HTTP/3.0" : record.protocolName ?? "HTTP/1.1"
            return Entry(startedDateTime: record.date.ISO8601Format(), time: record.duration * 1000,
                request: Request(method: record.method, url: record.url, httpVersion: version, cookies: [], headers: record.requestHeaders.map { Header(name: $0.key, value: $0.value) }, queryString: query, headersSize: -1, bodySize: record.requestBody.utf8.count, postData: record.requestBody.isEmpty ? nil : PostData(mimeType: record.requestHeaders.first { $0.key.lowercased() == "content-type" }?.value ?? "application/octet-stream", text: record.requestBody)),
                response: Response(status: record.status ?? 0, statusText: record.status.map { HTTPURLResponse.localizedString(forStatusCode: $0) } ?? "", httpVersion: version, cookies: [], headers: record.responseHeaders.map { Header(name: $0.key, value: $0.value) }, content: Content(size: record.bytes, mimeType: record.responseHeaders.first { $0.key.lowercased() == "content-type" }?.value ?? "application/octet-stream", text: record.responseBody, encoding: record.responseEncoding), redirectURL: record.responseHeaders.first { $0.key.lowercased() == "location" }?.value ?? "", headersSize: -1, bodySize: record.bytes),
                cache: [:], timings: Timings(send: -1, wait: -1, receive: -1, dns: record.dnsDuration.map { $0 * 1000 } ?? -1, connect: record.connectDuration.map { $0 * 1000 } ?? -1, ssl: record.tlsDuration.map { $0 * 1000 } ?? -1), serverIPAddress: record.remoteAddress)
        })
    }
    func records() -> [DiagnosticRecord] {
        log.entries.map { entry in
            DiagnosticRecord(date: ISO8601DateFormatter().date(from: entry.startedDateTime) ?? Date(), url: entry.request.url, method: entry.request.method, requestHeaders: Dictionary(entry.request.headers.map { ($0.name, $0.value) }, uniquingKeysWith: { _, last in last }), requestBody: entry.request.postData?.text ?? "", status: entry.response.status, responseHeaders: Dictionary(entry.response.headers.map { ($0.name, $0.value) }, uniquingKeysWith: { _, last in last }), responseBody: entry.response.content.text, bytes: entry.response.content.size, duration: entry.time / 1000, protocolName: entry.response.httpVersion, remoteAddress: entry.serverIPAddress)
        }
    }
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
            let status = response["status"] as? Int
            func phase(_ key: String) -> Double? { guard let duration = timings[key] as? Double, duration >= 0 else { return nil }; return duration / 1000 }
            return DiagnosticRecord(date: fractionalDate.date(from: timestamp) ?? date.date(from: timestamp) ?? Date(), url: url, method: request["method"] as? String ?? "GET", requestHeaders: headers(request["headers"]), requestBody: post["text"] as? String ?? "", status: status == 0 ? nil : status, responseHeaders: headers(response["headers"]), responseBody: text, responseEncoding: content["encoding"] as? String, bytes: content["size"] as? Int ?? text.utf8.count, duration: max(0, (entry["time"] as? Double ?? 0) / 1000), protocolName: response["httpVersion"] as? String, remoteAddress: entry["serverIPAddress"] as? String, dnsDuration: phase("dns"), connectDuration: phase("connect"), tlsDuration: phase("ssl"))
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
