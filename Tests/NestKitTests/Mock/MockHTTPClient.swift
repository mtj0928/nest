import Foundation
import HTTPTypes
import os
import NestKit

final class MockHTTPClient: HTTPClient {
    let mockFileStorage: MockFileStorage

    private let lockedDummyData = OSAllocatedUnfairLock<[URL: Data]>(initialState: [:])
    var dummyData: [URL: Data] {
        get { lockedDummyData.withLock { $0} }
        set { lockedDummyData.withLock { $0 = newValue } }
    }

    init(mockFileStorage: MockFileStorage) {
        self.mockFileStorage = mockFileStorage
    }

    func data(for request: HTTPRequest) async throws -> (Data, HTTPTypes.HTTPResponse) {
        guard let url = request.url,
            let data = dummyData[url] else {
            return (Data(), HTTPResponse(status: .notFound))
        }
        return (data, HTTPResponse(status: .ok))
    }

    func download(for request: HTTPRequest) async throws -> (URL, HTTPTypes.HTTPResponse) {
        let localFilePath = mockFileStorage.temporaryDirectory.appending(path: UUID().uuidString)
        guard let url = request.url,
              let data = dummyData[url] else {
            return (localFilePath, HTTPResponse(status: .notFound))
        }
        try mockFileStorage.write(data, to: localFilePath)
        return (localFilePath, HTTPResponse(status: .ok))
    }
}
