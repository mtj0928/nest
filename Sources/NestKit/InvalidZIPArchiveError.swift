import Foundation

package struct InvalidZIPArchiveError: LocalizedError {
    package let errorDescription: String?

    package init(underlyingError: any Error) {
        self.errorDescription = underlyingError.localizedDescription
    }
}
