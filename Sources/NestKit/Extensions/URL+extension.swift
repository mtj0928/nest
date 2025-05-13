import Foundation
import UniformTypeIdentifiers

extension URL {
    /// `owner/repo` format
    public var referenceName: String? {
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
