import Foundation

final class ThreadSafe<Value: Sendable>: @unchecked Sendable {
    var value: Value {
        get { lock.withLock { _value} }
        set { lock.withLock { _value = newValue }}
    }
    private var _value: Value
    private let lock = NSLock()

    init(value: Value) {
        self._value = value
    }
}
