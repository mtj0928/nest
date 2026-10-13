import Subprocess

extension Dictionary where Key == String, Value == String {
    var subprocessValues: [Environment.Key: String] {
        [Environment.Key: String](uniqueKeysWithValues: map { (.init(stringLiteral: $0.key), $0.value) })
    }
}
