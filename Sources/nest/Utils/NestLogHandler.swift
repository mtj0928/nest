import Logging
import Rainbow

struct NestLogHandler: LogHandler {
    var logLevel: Logger.Level = .info
    var metadata = Logger.Metadata()

    subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get { metadata[metadataKey] }
        set { metadata[metadataKey] = newValue }
    }

    func log(level: Logger.Level,
             message: Logger.Message,
             metadata: Logger.Metadata?,
             source: String,
             file: String,
             function: String,
             line: UInt) {
        let color: NamedColor?
        if let metadata = metadata,
           let rawColorString = metadata["color"],
           let colorCode = UInt8(rawColorString.description),
           let namedColor = NamedColor(rawValue: colorCode) {
            color = namedColor
        } else {
            color = nil
        }
        if let color = color {
            print(message.description.applyingColor(color))
        } else {
            print(message.description)
        }
    }
}

extension LoggingSystem {
    public static func bootstrap() {
        self.bootstrap { _ in
            NestLogHandler()
        }
    }
}
