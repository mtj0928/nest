import Foundation
import UniformTypeIdentifiers

extension URL {
    public var fileNameWithoutPathExtension: String {
        lastPathComponent.replacingOccurrences(of: ".\(pathExtension)", with: "")
    }

    public var needsUnzip: Bool {
        let utType = UTType(filenameExtension: pathExtension)
        return utType?.conforms(to: .zip) ?? false
    }
}
