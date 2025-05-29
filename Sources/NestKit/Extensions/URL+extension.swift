import Foundation
import UniformTypeIdentifiers

extension URL {
    /// `owner/repo` format
    /// `pathComponents[1]` must be specified as owner and `pathComponents[2]` must be specified as repository
    public var reference: String? {
        guard pathComponents.count >= 3 else { return nil }
        let owner = pathComponents[1]
        let repo = pathComponents[2].replacingOccurrences(of: ".\(pathExtension)", with: "")
        return "\(owner)/\(repo)"
    }
    
    public var fileNameWithoutPathExtension: String {
        lastPathComponent.replacingOccurrences(of: ".\(pathExtension)", with: "")
    }

    public var needsUnzip: Bool {
        let utType = UTType(filenameExtension: pathExtension)
        return utType?.conforms(to: .zip) ?? false
    }
}
