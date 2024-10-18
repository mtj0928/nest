import Foundation
import HTTPTypes
import HTTPTypesFoundation

public protocol HTTPClient: Sendable {
    func data(for request: HTTPRequest) async throws -> (Data, HTTPResponse)
    func download(for request: HTTPRequest) async throws -> (URL, HTTPResponse)
}

extension URLSession: HTTPClient {
    public func download(for request: HTTPRequest) async throws -> (URL, HTTPResponse) {
        try await download(for: request, delegate: nil)
    }
}
