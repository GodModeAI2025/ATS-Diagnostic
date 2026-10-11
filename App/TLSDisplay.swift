import Foundation

enum TLSDisplay {
    static func version(_ raw: String?) -> String {
        switch raw?.lowercased() {
        case "0x0304": "TLS 1.3"
        case "0x0303": "TLS 1.2"
        case "0x0302": "TLS 1.1"
        case "0x0301": "TLS 1.0"
        default: raw ?? "Not reported"
        }
    }
    static func cipher(_ raw: String?) -> String {
        guard let raw else { return "Not reported" }
        let names = ["0x1301": "AES-128-GCM · SHA-256", "0x1302": "AES-256-GCM · SHA-384", "0x1303": "ChaCha20-Poly1305 · SHA-256", "0xc02f": "ECDHE-RSA · AES-128-GCM", "0xc030": "ECDHE-RSA · AES-256-GCM", "0xc02b": "ECDHE-ECDSA · AES-128-GCM", "0xc02c": "ECDHE-ECDSA · AES-256-GCM"]
        return names[raw.lowercased()].map { "\($0) (\(raw))" } ?? raw
    }
}
