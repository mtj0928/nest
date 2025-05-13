import NestCLI
import Logging

extension ChecksumOption {
    init(isSkip: Bool = false, expectedChecksum: String?, logger: Logger) {
        guard !isSkip else {
            self = .skip
            return
        }
        guard let expectedChecksum else {
            self = .printActual { checksum in
                logger.info("ℹ️ The checksum is \(checksum). Please add it to the nestfile to verify the downloaded file.")
            }
            return
        }
        self = .needsCheck(expected: expectedChecksum)
    }
}
