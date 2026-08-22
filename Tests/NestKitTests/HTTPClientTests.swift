import Foundation
import Testing
@testable import NestKit

struct HTTPClientTests {
    @Test
    func crossHostRedirectRemovesSensitiveHeaders() throws {
        let sourceURL = try #require(URL(string: "https://ghe.example.com/api/v3/releases"))
        let destinationURL = try #require(URL(string: "https://attacker.example/releases"))
        let response = try #require(HTTPURLResponse(
            url: sourceURL,
            statusCode: 302,
            httpVersion: nil,
            headerFields: nil
        ))
        var request = URLRequest(url: destinationURL)
        request.setValue("Bearer secret", forHTTPHeaderField: "Authorization")
        request.setValue("session=secret", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let redirectedRequest = HTTPRedirectSecurity.redirectedRequest(request, response: response)

        #expect(redirectedRequest.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(redirectedRequest.value(forHTTPHeaderField: "Cookie") == nil)
        #expect(redirectedRequest.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test
    func sameHostRedirectKeepsAuthorization() throws {
        let sourceURL = try #require(URL(string: "https://ghe.example.com/api/v3/releases"))
        let destinationURL = try #require(URL(string: "https://ghe.example.com/api/v3/releases/latest"))
        let response = try #require(HTTPURLResponse(
            url: sourceURL,
            statusCode: 302,
            httpVersion: nil,
            headerFields: nil
        ))
        var request = URLRequest(url: destinationURL)
        request.setValue("Bearer secret", forHTTPHeaderField: "Authorization")

        let redirectedRequest = HTTPRedirectSecurity.redirectedRequest(request, response: response)

        #expect(redirectedRequest.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    }
}
