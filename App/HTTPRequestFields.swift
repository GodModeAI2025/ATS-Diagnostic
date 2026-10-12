import Foundation

enum HTTPRequestFields {
    enum ValidationError: LocalizedError {
        case method, headerName, headerValue, headerLine
        var errorDescription: String? {
            switch self {
            case .method: "Die HTTP-Methode ist leer oder enthält ungültige Zeichen. Verwende einen Methodennamen ohne Leer- oder Steuerzeichen."
            case .headerName: "Ein HTTP-Header-Name ist leer oder enthält ungültige Zeichen. Verwende einen Namen ohne Leerzeichen oder Doppelpunkt."
            case .headerValue: "Ein HTTP-Header-Wert enthält einen Zeilenumbruch oder ein anderes unzulässiges Steuerzeichen."
            case .headerLine: "Gib jeden Header als Name: Wert in einer eigenen Zeile ein."
            }
        }
    }
    private static let punctuation = Set("!#$%&'*+-.^_`|~".utf8)
    private static func token(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || punctuation.contains($0) }
    }
    static func validate(method: String, headers: [String: String]) throws {
        guard token(method) else { throw ValidationError.method }
        for (name, value) in headers {
            guard token(name) else { throw ValidationError.headerName }
            guard value.utf8.allSatisfy({ $0 == 9 || ($0 >= 32 && $0 != 127) }) else { throw ValidationError.headerValue }
        }
    }
    static func parseHeaders(_ text: String) throws -> [String: String] {
        var fields: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            guard let colon = line.firstIndex(of: ":") else { throw ValidationError.headerLine }
            let name = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            try validate(method: "GET", headers: [name: value])
            fields[name] = value
        }
        return fields
    }
}
