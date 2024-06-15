import Foundation
import Testing
@testable import nest
@testable import NestKit

struct InstallTargetTests {
    @Test
    func testInstallTarget() throws {
        let installTarget = InstallTarget(argument: "artifactBundle.zip")
        switch installTarget {
        case .git(let gitURL):
            fatalError()
        case .artifactBundle(let url):
            #expect(url == URL(string: "artifactBundle.zip"))
        case nil:
            fatalError()
        }
    }
}
