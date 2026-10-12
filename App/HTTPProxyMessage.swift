import Foundation

struct HTTPHeader: Equatable, Sendable {
    let name: String
    let value: String
}
struct ProxyHTTPRequest: Sendable {
    let method: String
    let target: String
    let version: String
    let url: URL
    let headers: [HTTPHeader]
    let body: Data
    let wireBody: Data
    let consumedBytes: Int
    var isTunnel: Bool { method == "CONNECT" }
    var requestsUpgrade: Bool { headers.contains { $0.name.lowercased() == "upgrade" } && headers.contains { $0.name.lowercased() == "connection" && $0.value.lowercased().split(separator:",").contains { $0.trimmingCharacters(in:.whitespaces) == "upgrade" } } }
    func upstreamHeaderBytes() -> Data {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        let path = (components?.percentEncodedPath.isEmpty == false ? components?.percentEncodedPath : "/") ?? "/"
        let origin = path + (components?.percentEncodedQuery.map { "?" + $0 } ?? "")
        let connectionNames = Set(headers.filter { $0.name.lowercased() == "connection" }.flatMap { $0.value.lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } })
        var blocked = connectionNames.union(["connection", "proxy-connection", "proxy-authorization", "keep-alive", "host", "expect"])
        if requestsUpgrade { blocked.remove("upgrade") }
        var filtered = headers.filter { !blocked.contains($0.name.lowercased()) }
        if headers.contains(where: { $0.name.lowercased() == "content-length" }) {
            filtered.removeAll { $0.name.lowercased() == "content-length" }
            filtered.append(HTTPHeader(name:"Content-Length",value:String(body.count)))
        }
        let host = url.host ?? ""
        let authority = (host.contains(":") && !host.hasPrefix("[") ? "[\(host)]" : host) + (url.port.map { ":\($0)" } ?? "")
        filtered.append(HTTPHeader(name: "Host", value: authority))
        filtered.append(HTTPHeader(name: "Connection", value: requestsUpgrade ? "Upgrade" : "close"))
        var bytes = Data("\(method) \(origin) HTTP/1.1\r\n".utf8)
        for header in filtered { bytes.append(Data("\(header.name): \(header.value)\r\n".utf8)) }
        bytes.append(Data("\r\n".utf8))
        return bytes
    }
    func upstreamBytes() -> Data {
        var bytes = upstreamHeaderBytes()
        bytes.append(wireBody)
        return bytes
    }
}
enum HTTPProxyMessage {
    enum ParseError: Error, Equatable {
        case malformed, ambiguousLength, headerTooLarge, bodyTooLarge, unsupportedTransferCoding
    }
    static let headerLimit = 64 * 1024
    static func parseRequest(_ data: Data, bodyLimit: Int = 16 * 1024 * 1024) throws -> ProxyHTTPRequest? {
        guard let separator = data.range(of: Data("\r\n\r\n".utf8)) else {
            guard data.count <= headerLimit else { throw ParseError.headerTooLarge }
            return nil
        }
        let headerBytes = data.distance(from: data.startIndex, to: separator.upperBound)
        guard headerBytes <= headerLimit else { throw ParseError.headerTooLarge }
        guard let text = String(data: data[..<separator.lowerBound], encoding: .isoLatin1) else { throw ParseError.malformed }
        var lines = text.components(separatedBy: "\r\n")
        guard !lines.isEmpty else { throw ParseError.malformed }
        let startLine = lines.removeFirst().components(separatedBy: " ")
        guard startLine.count == 3, token(startLine[0]), ["HTTP/1.0", "HTTP/1.1"].contains(startLine[2]), !startLine[1].isEmpty else { throw ParseError.malformed }
        let method = startLine[0], target = startLine[1], version = startLine[2]
        let headers = try parseHeaders(lines)
        let connectionOptions = headers.filter { $0.name.lowercased() == "connection" }.flatMap { $0.value.lowercased().split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) } }
        guard connectionOptions.allSatisfy(token), Set(connectionOptions).isDisjoint(with: ["host", "content-length", "transfer-encoding", "trailer"]) else { throw ParseError.ambiguousLength }
        let hostHeaders = headers.filter { $0.name.lowercased() == "host" }
        guard hostHeaders.count <= 1, version != "HTTP/1.1" || hostHeaders.count == 1 else { throw ParseError.malformed }
        let url: URL
        if method == "CONNECT" {
            guard let candidate = URL(string: "https://" + target), candidate.host != nil, let port = candidate.port, (1...65535).contains(port), candidate.user == nil, candidate.password == nil, candidate.path.isEmpty, candidate.query == nil, candidate.fragment == nil else { throw ParseError.malformed }
            url = candidate
        } else {
            let absolute = target.hasPrefix("/") ? "http://" + (hostHeaders.first?.value ?? "") + target : target
            guard let candidate = URL(string: absolute), ["http", "https"].contains(candidate.scheme?.lowercased() ?? ""), let host = candidate.host, !host.isEmpty, candidate.user == nil, candidate.password == nil, candidate.fragment == nil, candidate.port.map({ (1...65535).contains($0) }) ?? true else { throw ParseError.malformed }
            url = candidate
        }
        let lengths = headers.filter { $0.name.lowercased() == "content-length" }.flatMap { $0.value.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) } }
        let transfers = headers.filter { $0.name.lowercased() == "transfer-encoding" }.flatMap { $0.value.lowercased().split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) } }
        guard lengths.isEmpty || transfers.isEmpty else { throw ParseError.ambiguousLength }
        guard transfers.isEmpty || version == "HTTP/1.1" else { throw ParseError.malformed }
        let suffix = Data(data[separator.upperBound...])
        let body: Data, wire: Data, consumed: Int
        if !transfers.isEmpty {
            guard transfers.last == "chunked", transfers.filter({ $0 == "chunked" }).count == 1, transfers.allSatisfy({ !$0.isEmpty }) else { throw ParseError.unsupportedTransferCoding }
            guard let chunks = try decodeChunks(suffix, bodyLimit: bodyLimit) else { return nil }
            body = chunks.body; consumed = chunks.consumed; wire = Data(suffix.prefix(consumed))
        } else {
            var length = 0
            if let first = lengths.first {
                guard !first.isEmpty, first.utf8.allSatisfy({ (48...57).contains($0) }), let parsed = Int(first), lengths.allSatisfy({ $0 == first }) else { throw ParseError.ambiguousLength }
                length = parsed
            }
            guard length <= bodyLimit else { throw ParseError.bodyTooLarge }
            guard suffix.count >= length else { return nil }
            body = Data(suffix.prefix(length)); wire = body; consumed = length
        }
        guard method != "CONNECT" || consumed == 0 else { throw ParseError.malformed }
        return ProxyHTTPRequest(method: method, target: target, version: version, url: url, headers: headers, body: body, wireBody: wire, consumedBytes: headerBytes + consumed)
    }
    static func parseHeaders(_ lines: [String]) throws -> [HTTPHeader] {
        try lines.map { line in
            guard !line.hasPrefix(" "), !line.hasPrefix("\t"), let colon = line.firstIndex(of: ":") else { throw ParseError.malformed }
            let name = String(line[..<colon])
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
            guard token(name), value.unicodeScalars.allSatisfy({ $0.value == 9 || (32...255).contains($0.value) && $0.value != 127 }) else { throw ParseError.malformed }
            return HTTPHeader(name: name, value: value)
        }
    }
    static func token(_ text: String) -> Bool {
        !text.isEmpty && text.utf8.allSatisfy { byte in (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte) || Array("!#$%&'*+-.^_`|~".utf8).contains(byte) }
    }
    static func decodeChunks(_ data: Data, bodyLimit: Int) throws -> (body: Data, consumed: Int)? {
        let bytes = [UInt8](data)
        var index = 0, body = Data()
        func lineEnd(from start: Int) -> Int? {
            guard start + 1 < bytes.count else { return nil }
            for position in start..<(bytes.count - 1) where bytes[position] == 13 && bytes[position + 1] == 10 { return position }
            return nil
        }
        while true {
            guard let end = lineEnd(from: index) else {
                guard bytes.count - index <= headerLimit else { throw ParseError.headerTooLarge }; return nil
            }
            guard end - index <= headerLimit, bytes[index..<end].allSatisfy({ (32...126).contains($0) }) else { throw ParseError.malformed }
            let line = String(decoding: bytes[index..<end], as: UTF8.self)
            let sizeText = String(line.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)[0])
            guard !sizeText.isEmpty, sizeText.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }), let size = Int(sizeText, radix: 16) else { throw ParseError.malformed }
            index = end + 2
            if size == 0 {
                let trailerStart = index
                var trailers: [String] = []
                while true {
                    guard let trailerEnd = lineEnd(from: index) else { guard bytes.count - trailerStart <= headerLimit else { throw ParseError.headerTooLarge }; return nil }
                    guard trailerEnd - trailerStart <= headerLimit else { throw ParseError.headerTooLarge }
                    if trailerEnd == index {
                        let parsed = try parseHeaders(trailers)
                        guard !parsed.contains(where: { ["content-length", "transfer-encoding", "host"].contains($0.name.lowercased()) }) else { throw ParseError.ambiguousLength }
                        return (body, trailerEnd + 2)
                    }
                    trailers.append(String(decoding: bytes[index..<trailerEnd], as: UTF8.self)); index = trailerEnd + 2
                }
            }
            guard size <= bodyLimit - body.count else { throw ParseError.bodyTooLarge }
            guard size <= bytes.count - index, bytes.count - index - size >= 2 else { return nil }
            guard bytes[index + size] == 13, bytes[index + size + 1] == 10 else { throw ParseError.malformed }
            body.append(contentsOf: bytes[index..<index + size]); index += size + 2
        }
    }
}
