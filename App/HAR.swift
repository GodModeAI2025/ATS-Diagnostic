import Foundation
import UniformTypeIdentifiers
import CoreTransferable

struct HARArchive: Codable, Transferable {
    struct Log: Codable { var version = "1.2"; var creator = Creator(); var entries: [Entry] }
    struct Creator: Codable { var name = "ATS Diagnostic"; var version = "2.0" }
    struct Header: Codable { let name: String; let value: String }
    struct PostData: Codable { let mimeType: String; let text: String }
    struct Request: Codable { let method: String; let url: String; let httpVersion: String; let cookies: [String]; let headers: [Header]; let queryString: [Header]; let headersSize: Int; let bodySize: Int; let postData: PostData? }
    struct Content: Codable { let size: Int; let mimeType: String; let text: String }
    struct Response: Codable { let status: Int; let statusText: String; let httpVersion: String; let cookies: [String]; let headers: [Header]; let content: Content; let redirectURL: String; let headersSize: Int; let bodySize: Int }
    struct Timings: Codable { let send: Double; let wait: Double; let receive: Double; let dns: Double; let connect: Double; let ssl: Double }
    struct Entry: Codable { let startedDateTime: String; let time: Double; let request: Request; let response: Response; let cache: [String: String]; let timings: Timings; let serverIPAddress: String? }
    let log: Log
    init(records: [DiagnosticRecord]) {
        log = Log(entries: records.map { record in
            let query = URLComponents(string: record.url)?.queryItems?.map { Header(name: $0.name, value: $0.value ?? "") } ?? []
            let version = record.protocolName ?? ""
            return Entry(startedDateTime: record.date.ISO8601Format(), time: record.duration * 1000,
                request: Request(method: record.method, url: record.url, httpVersion: version, cookies: [], headers: record.requestHeaders.map { Header(name: $0.key, value: $0.value) }, queryString: query, headersSize: -1, bodySize: record.requestBody.utf8.count, postData: record.requestBody.isEmpty ? nil : PostData(mimeType: record.requestHeaders.first { $0.key.lowercased() == "content-type" }?.value ?? "application/octet-stream", text: record.requestBody)),
                response: Response(status: record.status ?? 0, statusText: record.status.map { HTTPURLResponse.localizedString(forStatusCode: $0) } ?? "", httpVersion: version, cookies: [], headers: record.responseHeaders.map { Header(name: $0.key, value: $0.value) }, content: Content(size: record.bytes, mimeType: record.responseHeaders.first { $0.key.lowercased() == "content-type" }?.value ?? "application/octet-stream", text: record.responseBody), redirectURL: record.responseHeaders.first { $0.key.lowercased() == "location" }?.value ?? "", headersSize: -1, bodySize: record.bytes),
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
