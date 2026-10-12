import Foundation
import HTTPTypes
import HTTPTypesFoundation
import Testing
@testable import NestKit

struct HTTPLogRedactorTests {
    @Test(arguments: [
        "https://user:password@example.com/tool.zip?token=secret#private",
        "https://example.com/tool.zip?custom=secret&X-Amz-Signature=signature"
    ])
    func redactsRequestURLWithoutChangingTheRequest(input: String) throws {
        let url = try #require(URL(string: input))
        var request = HTTPRequest(method: .get, url: url)
        request.headerFields = [.authorization: "Bearer header-secret"]
        let originalRequest = request

        let description = HTTPLogRedactor.redactedDescription(of: request)

        #expect(description == "GET https://example.com/tool.zip, headers: [Authorization: <redacted>]")
        #expect(request == originalRequest)
    }

    @Test
    func redactsSensitiveHeaders() throws {
        let url = try #require(URL(string: "https://example.com/path"))
        var request = HTTPRequest(method: .get, url: url)
        request.headerFields = [
            .authorization: "Bearer secret",
            .cookie: "session=secret",
            .init("X-API-Key")!: "api-key-secret",
            .init("X-GitHub-OTP")!: "one-time-password",
            .accept: "application/json"
        ]

        let description = HTTPLogRedactor.redactedDescription(of: request)

        #expect(!description.contains("Bearer secret"))
        #expect(!description.contains("session=secret"))
        #expect(!description.contains("api-key-secret"))
        #expect(!description.contains("one-time-password"))
        #expect(description.contains("Authorization: <redacted>"))
        #expect(description.contains("Cookie: <redacted>"))
        #expect(description.contains("Accept: application/json"))
    }
}
