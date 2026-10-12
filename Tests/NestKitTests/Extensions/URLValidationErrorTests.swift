import Foundation
import Testing
@testable import NestKit

struct URLValidationErrorTests {
    @Test(arguments: [
        ("http://url-user:url-password@example.com/tool.zip?token=url-token#url-fragment", "Insecure URL \"http://example.com/tool.zip\"."),
        ("ftp://url-user:url-password@example.com/tool.zip?token=url-token#url-fragment", "Insecure URL \"<URL>\"."),
        ("https://example.com:invalid/tool.zip?token=url-token", "Invalid URL.")
    ])
    func rejectsURLsWithoutEchoingTheirSecrets(input: String, expectedPrefix: String) throws {
        do {
            _ = try URL.httpsURL(from: input)
            Issue.record("Expected URL validation to fail")
        } catch let error as URLValidationError {
            for secret in ["url-user", "url-password", "url-token", "url-fragment", "token="] {
                #expect(!error.localizedDescription.contains(secret))
            }
            #expect(error.localizedDescription.hasPrefix(expectedPrefix))
            switch error {
            case .invalid(let original):
                #expect(original == input)
                #expect(error.localizedDescription == "Invalid URL.")
            case .insecureScheme(let original):
                #expect(original == input)
                #expect(error.localizedDescription.contains("nest only accepts HTTPS"))
            }
        }
    }
}
