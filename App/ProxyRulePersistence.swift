import Foundation

actor ProxyRulePersistence {
    enum Failure: LocalizedError {
        case unsupportedVersion, sizeLimit, countLimit, duplicateIDs
        var errorDescription: String? {
            switch self {
            case .unsupportedVersion: "Die gespeicherten Proxy-Regeln haben ein nicht unterstütztes Format."
            case .sizeLimit: "Die gespeicherten Proxy-Regeln überschreiten das Limit von 64 MiB."
            case .countLimit: "Das Regelprofil enthält mehr als 64 Regeln."
            case .duplicateIDs: "Das Regelprofil enthält doppelte Regelkennungen."
            }
        }
    }
    private struct Profile: Codable { let version: Int; let rules: [ProxyRuleConfiguration] }
    private let file: URL
    private var newestRevision: UInt64 = 0
    private static let byteLimit = 64 * 1024 * 1024
    init(file: URL) { self.file = file }
    func load() throws -> [ProxyRuleConfiguration] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        guard let size = attributes[.size] as? NSNumber, size.int64Value <= Self.byteLimit else { throw Failure.sizeLimit }
        let data = try Data(contentsOf: file)
        guard data.count <= Self.byteLimit else { throw Failure.sizeLimit }
        let profile = try JSONDecoder().decode(Profile.self, from: data)
        guard profile.version == 1 else { throw Failure.unsupportedVersion }
        try Self.validate(profile.rules)
        return profile.rules
    }
    @discardableResult
    func save(_ rules: [ProxyRuleConfiguration], revision: UInt64) throws -> Bool {
        guard revision >= newestRevision else { return false }
        newestRevision = revision
        try Self.validate(rules)
        let data = try JSONEncoder().encode(Profile(version: 1, rules: rules))
        guard data.count <= Self.byteLimit else { throw Failure.sizeLimit }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: file, options: [.atomic, .completeFileProtection])
        return true
    }
    private static func validate(_ rules: [ProxyRuleConfiguration]) throws {
        guard rules.count <= 64 else { throw Failure.countLimit }
        guard Set(rules.map(\.id)).count == rules.count else { throw Failure.duplicateIDs }
        var bytes = 0
        for rule in rules {
            for value in [rule.matchURL, rule.replacementURL, rule.method, rule.headerText, rule.bodyText] {
                let (total, overflow) = bytes.addingReportingOverflow(value.utf8.count)
                guard !overflow, total <= byteLimit else { throw Failure.sizeLimit }
                bytes = total
            }
            _ = try rule.rule()
        }
    }
}
