import Logging
import Rainbow

extension Logger.MetadataValue {
    public static func color(_ color: NamedColor) -> Self {
        .stringConvertible(color.rawValue)
    }
}

extension Logger.Metadata {
    public static func color(_ color: NamedColor) -> Self { ["color": .color(color)] }
}

extension Logger {
    public func error(_ error: some Error) {
        self.error("💥 \(error.localizedDescription)", metadata: .color(.red))
    }
}
