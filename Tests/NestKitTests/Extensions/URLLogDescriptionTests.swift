import Foundation
import NestKit
import Testing

struct URLLogDescriptionTests {
    @Test(arguments: [
        ("https://example.com/tool.zip", "https://example.com/tool.zip"),
        ("https://user:password@example.com/tool.zip", "https://example.com/tool.zip"),
        ("https://user@example.com/tool.zip", "https://example.com/tool.zip"),
        ("https://example.com/tool.zip?token=secret", "https://example.com/tool.zip"),
        ("https://example.com/tool.zip?custom=secret&download=1", "https://example.com/tool.zip"),
        ("https://example.com/tool.zip?X-Amz-Signature=secret", "https://example.com/tool.zip"),
        ("https://example.com/tool.zip#private", "https://example.com/tool.zip"),
        ("http://user:password@example.com:8080/tool.zip?token=secret#private", "http://example.com:8080/tool.zip"),
        ("HTTPS://example.com:8443/releases/tool.zip?token=secret", "HTTPS://example.com:8443/releases/tool.zip"),
        ("https://us%65r:p%40ss@example.com/releases/tool%20name.zip?token=secret#private", "https://example.com/releases/tool%20name.zip")
    ])
    func removesURLSecretsWithoutChangingTheOriginal(input: String, expected: String) throws {
        let url = try #require(URL(string: input))

        #expect(url.logDescription == expected)
        #expect(url.absoluteString == input)
    }

    @Test(arguments: [
        "tool.zip?token=secret#private",
        "//user:password@example.com/tool.zip?token=secret",
        "https:secret",
        "https:///secret",
        "ftp://user:password@example.com/tool.zip?token=secret",
        "file:///private/secret/tool.zip",
        "data:text/plain,secret"
    ])
    func hidesUnsupportedAndIncompleteURLs(input: String) throws {
        let url = try #require(URL(string: input))

        #expect(url.logDescription == "<URL>")
        #expect(url.absoluteString == input)
    }

    @Test
    func resolvesRelativeURLsWithoutChangingTheirBase() throws {
        let baseURL = try #require(URL(string: "https://user:password@example.com/releases/"))
        let relativeString = "tool.zip?token=secret#private"
        let url = try #require(URL(string: relativeString, relativeTo: baseURL))

        #expect(url.logDescription == "https://example.com/releases/tool.zip")
        #expect(url.relativeString == relativeString)
        #expect(url.baseURL == baseURL)
    }
}
