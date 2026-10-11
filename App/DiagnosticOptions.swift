import Foundation

struct DiagnosticOptions: Codable, Equatable, Sendable {
    var requestTimeout: Double = 20
    var resourceTimeout: Double = 30
    var bodyPreviewBytes: Int = 2 * 1024 * 1024
    static let standard = Self()

    func validate() throws {
        guard requestTimeout.isFinite, (1...300).contains(requestTimeout) else { throw ValidationError.requestTimeout }
        guard resourceTimeout.isFinite, (1...3600).contains(resourceTimeout) else { throw ValidationError.resourceTimeout }
        guard (0...16 * 1024 * 1024).contains(bodyPreviewBytes) else { throw ValidationError.preview }
    }
    var validated: Self { (try? validate()) != nil ? self : .standard }
    func configure(_ configuration: URLSessionConfiguration, request: URLRequest) -> URLRequest {
        let value = validated
        configuration.timeoutIntervalForRequest = value.requestTimeout
        configuration.timeoutIntervalForResource = value.resourceTimeout
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        var request = request
        request.timeoutInterval = value.requestTimeout
        return request
    }
    enum ValidationError: LocalizedError {
        case requestTimeout, resourceTimeout, preview
        var errorDescription: String? {
            switch self {
            case .requestTimeout: "Das Wartezeitlimit muss zwischen 1 und 300 Sekunden liegen."
            case .resourceTimeout: "Das Gesamtzeitlimit muss zwischen 1 und 3.600 Sekunden liegen."
            case .preview: "Die Antwortvorschau muss zwischen 0 und 16 MiB liegen."
            }
        }
    }
}
