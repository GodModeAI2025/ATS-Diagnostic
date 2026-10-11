import Foundation

struct ImportedRequest: Equatable, Sendable {
    var url: String
    var method: String
    var headers: String
    var body: String
}
enum CURLImport {
    enum ImportError: LocalizedError {
        case invalid(String)
        var errorDescription: String? { switch self { case .invalid(let reason): reason } }
    }
    static func parse(_ command: String) throws -> ImportedRequest {
        let tokens = try tokenize(command)
        guard tokens.first == "curl" else { throw ImportError.invalid("Start with curl.") }
        var url: String?
        var method: String?
        var headers: [String] = []
        var bodies: [String] = []
        var index = 1
        while index < tokens.count {
            let token = tokens[index]
            func argument() throws -> String {
                index += 1
                guard index < tokens.count else { throw ImportError.invalid("Missing value for \(token).") }
                return tokens[index]
            }
            switch token {
            case "-X", "--request": method = try argument()
            case "-H", "--header":
                let header = try argument()
                guard header.contains(":"), !header.contains("\n"), !header.contains("\r") else { throw ImportError.invalid("Enter headers as Name: Value.") }
                headers.append(header)
            case "-d", "--data", "--data-raw", "--data-binary":
                let value = try argument()
                guard token == "--data-raw" || !value.hasPrefix("@") else { throw ImportError.invalid("File uploads must be selected explicitly in the app.") }
                bodies.append(value)
            case "--url": url = try argument()
            case "-I", "--head": method = "HEAD"
            case "-L", "--location", "--compressed", "-s", "--silent", "-S", "--show-error": break
            default:
                guard !token.hasPrefix("-") else { throw ImportError.invalid("Unsupported option: \(token). Import a single request without shell execution or external files.") }
                guard url == nil else { throw ImportError.invalid("Import one URL at a time.") }
                url = token
            }
            index += 1
        }
        guard let url else { throw ImportError.invalid("Include a request URL.") }
        let endpoint = try Endpoint.parse(url)
        let selectedMethod = method ?? (bodies.isEmpty ? "GET" : "POST")
        guard !selectedMethod.isEmpty, selectedMethod.utf8.allSatisfy({ ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122) || $0 == 45 }) else { throw ImportError.invalid("Enter a valid HTTP method.") }
        return ImportedRequest(url: endpoint.absoluteString, method: selectedMethod.uppercased(), headers: headers.joined(separator: "\n"), body: bodies.joined(separator: "&"))
    }
    static func tokenize(_ command: String) throws -> [String] {
        var result: [String] = [], current = ""
        var quote: Character?, escape = false, active = false
        for character in command {
            if escape { if character != "\n" { current.append(character); active = true }; escape = false; continue }
            if character == "\\", quote != "'" { escape = true; active = true; continue }
            if let mode = quote {
                if character == mode { quote = nil } else { current.append(character) }
                active = true; continue
            }
            if character == "'" || character == "\"" { quote = character; active = true; continue }
            if character.isWhitespace {
                if active { result.append(current); current = ""; active = false }
            } else {
                guard !";|&<>`".contains(character), character != "$" else { throw ImportError.invalid("Shell operators and substitutions are not supported.") }
                current.append(character); active = true
            }
        }
        guard quote == nil, !escape else { throw ImportError.invalid("Close quotes and escaped characters.") }
        if active { result.append(current) }
        return result
    }
}
