import Logging
import os

final class TestLogRecorder: Sendable {
    private let lockedMessages = OSAllocatedUnfairLock(initialState: [String]())

    var messages: [String] {
        lockedMessages.withLock { $0 }
    }

    func makeLogger(logLevel: Logging.Logger.Level) -> Logging.Logger {
        var logger = Logging.Logger(label: "Test") { _ in
            Handler(recorder: self)
        }
        logger.logLevel = logLevel
        return logger
    }

    fileprivate func record(_ message: String) {
        lockedMessages.withLock { $0.append(message) }
    }
}

extension TestLogRecorder {
    struct Handler: LogHandler {
        var metadata = Logging.Logger.Metadata()
        var logLevel = Logging.Logger.Level.info
        let recorder: TestLogRecorder

        subscript(metadataKey metadataKey: String) -> Logging.Logger.Metadata.Value? {
            get { metadata[metadataKey] }
            set { metadata[metadataKey] = newValue }
        }

        func log(
            level: Logging.Logger.Level,
            message: Logging.Logger.Message,
            metadata: Logging.Logger.Metadata?,
            source: String,
            file: String,
            function: String,
            line: UInt
        ) {
            recorder.record(message.description)
        }
    }
}
