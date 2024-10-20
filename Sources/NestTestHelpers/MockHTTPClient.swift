import Foundation
import Logging
import HTTPTypes
import os
import NestKit

public final class MockHTTPClient: HTTPClient {
    let mockFileSystem: MockFileSystem
    let logger: Logging.Logger

    private let lockedDummyData = OSAllocatedUnfairLock<[URL: Data]>(initialState: [:])
    public var dummyData: [URL: Data] {
        get { lockedDummyData.withLock { $0} }
        set { lockedDummyData.withLock { $0 = newValue } }
    }

    public init(mockFileSystem: MockFileSystem, logger: Logging.Logger = Logger(label: "Test")) {
        self.mockFileSystem = mockFileSystem
        self.logger = logger
    }

    public func data(for request: HTTPRequest) async throws -> (Data, HTTPTypes.HTTPResponse) {
        guard let url = request.url,
            let data = dummyData[url] else {
            logger.error("No dummy data for \(request.url!.absoluteString).")
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
