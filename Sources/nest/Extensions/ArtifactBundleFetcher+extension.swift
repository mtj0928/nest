import NestCLI
import Logging

extension ChecksumOption {
    init(isSkip: Bool = false, expectedChecksum: String?, logger: Logger) {
        if isSkip {
            self = .skip
            return
        }
        if let expectedChecksum {
            self = .needsCheck(expected: expectedChecksum)
            return
        }
        self = .printActual { checksum in
            logger.info("ℹ️ The checksum is \(checksum). Please add it to the nestfile to verify the downloaded file.")
        }
    }
}
