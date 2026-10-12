import Foundation

extension RecordingClient {
    /// HAR 1.2 with explicit preview/error metadata. Bodies unavailable for exact
    /// replay are marked, rather than exported as if they were complete requests.
    public func harData() throws -> Data {
        let entries: [[String: Any]] = records().map { record in
            func headers(_ values: [String: String]) -> [[String: String]] { values.sorted { $0.key < $1.key }.map { ["name": $0.key, "value": $0.value] } }
            func mime(_ values: [String: String]) -> String { values.first { $0.key.lowercased() == "content-type" }?.value ?? "application/octet-stream" }
            let requestText = String(data: record.requestBodyPreview, encoding: .utf8)
            let requestUnavailable = record.requestPreviewTruncated || (record.requestBodyBytes ?? 0 > 0 && requestText == nil)
            var request: [String: Any] = ["url": record.url, "method": record.method, "httpVersion": "", "headers": headers(record.requestHeaders), "cookies": [], "queryString": URLComponents(string: record.url)?.queryItems?.map { ["name": $0.name, "value": $0.value ?? ""] } ?? [], "headersSize": -1, "bodySize": record.requestBodyBytes ?? -1]
            if !requestUnavailable, let requestText, !requestText.isEmpty { request["postData"] = ["mimeType": mime(record.requestHeaders), "text": requestText] }
            let completeSize = record.responseComplete == false ? -1 : (record.responseBytes ?? -1)
            var metadata: [String: Any] = ["source": "ATSRecording", "requestBodyUnavailable": requestUnavailable, "responseBytesKnown": record.responseBytes != nil && record.responseComplete != false]
            if requestUnavailable { metadata["requestBodyPreviewBase64"] = record.requestBodyPreview.base64EncodedString() }
            if let complete = record.responseComplete { metadata["responseComplete"] = complete }
            if record.responseComplete == false, let observed = record.responseBytes { metadata["observedResponseBytes"] = observed }
            if let hash = record.responseSHA256 { metadata["responseSHA256"] = hash }
            if let domain = record.errorDomain { metadata["errorDomain"] = domain }
            if let code = record.errorCode { metadata["errorCode"] = code }
            if let message = record.errorDescription { metadata["errorDescription"] = message }
            return ["startedDateTime": record.date.ISO8601Format(), "time": record.duration * 1000, "request": request, "response": ["status": record.status ?? 0, "statusText": record.status.map { HTTPURLResponse.localizedString(forStatusCode: $0) } ?? "", "httpVersion": "", "headers": headers(record.responseHeaders), "cookies": [], "content": ["size": completeSize, "mimeType": mime(record.responseHeaders), "text": record.responseBodyPreview.base64EncodedString(), "encoding": "base64"], "headersSize": -1, "bodySize": completeSize, "redirectURL": ""], "cache": [:], "timings": ["send": -1, "wait": -1, "receive": -1, "dns": -1, "connect": -1, "ssl": -1], "_atsDiagnostic": metadata]
        }
        return try JSONSerialization.data(withJSONObject: ["log": ["version": "1.2", "creator": ["name": "ATSRecording", "version": "0.1"], "entries": entries]], options: [.sortedKeys])
    }
}
