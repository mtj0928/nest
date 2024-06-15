import Foundation
import Testing
@testable import nest
@testable import NestKit

struct InstallTargetTests {
    @Test
    func testInstallTarget() throws {
        let installTarget = InstallTarget(argument: "artifactBundle.zip")
        guard case .artifactBundle(let url) = installTarget else {
            Issue.record("installTarget needs to be artifactBundle.")
            return
        }
        #expect(url == URL(string: "artifactBundle.zip"))
    }
}
