import Foundation
import HTTPTypes
import os
import NestKit

public final class MockHTTPClient: HTTPClient {
    let mockFileSystem: MockFileSystem

    private let lockedDummyData = OSAllocatedUnfairLock<[URL: Data]>(initialState: [:])
    public var dummyData: [URL: Data] {
        get { lockedDummyData.withLock { $0} }
        set { lockedDummyData.withLock { $0 = newValue } }
    }

    public init(mockFileSystem: MockFileSystem) {
        self.mockFileSystem = mockFileSystem
    }

    public func data(for request: HTTPRequest) async throws -> (Data, HTTPTypes.HTTPResponse) {
        guard let url = request.url,
            let data = dummyData[url] else {
            return (Data(), HTTPResponse(status: .notFound))
        }
        return (data, HTTPResponse(status: .ok))
    }

    public func download(for request: HTTPRequest) async throws -> (URL, HTTPTypes.HTTPResponse) {
        let localFilePath = mockFileSystem.temporaryDirectory.appending(path: UUID().uuidString)
        guard let url = request.url,
              let data = dummyData[url] else {
            return (localFilePath, HTTPResponse(status: .notFound))
        }
        try mockFileSystem.write(data, to: localFilePath)
        return (localFilePath, HTTPResponse(status: .ok))
    }
}
