import Foundation

public enum FileSystemItem: Equatable, Sendable {
    case directory(children: [String: FileSystemItem])
    case file(data: Data)

    public mutating func remove(at components: [String]) {
        switch self {
        case .directory(var children):
            var components = components
            let component = components.removeFirst()
            if components.isEmpty {
                children.removeValue(forKey: component)
            } else {
                var child = children[component]
                child?.remove(at: components)
                children[component] = child
            }
            self = .directory(children: children)
        case .file:
            break
        }

    }

    public mutating func update(item: FileSystemItem, at components: [String]) {
        switch self {
        case .directory(var children):
            var components = components
            let component = components.removeFirst()
            if components.isEmpty {
                children[component] = item
            } else {
                var child = children[component]
                child?.update(item: item, at: components)
                children[component] = child
            }
            self = .directory(children: children)
        case .file:
            break
        }
    }

    public func item(components: [String]) -> FileSystemItem? {
        if components.isEmpty {
            return self
        }
        var components = components
        let component = components.removeFirst()
        switch self {
        case .directory(children: let children):
            return children[component]?.item(components: components)
        case .file:
            return nil
        }
    }

    public func printStructure(indent: Int = 0) {
        let space = String(repeating: " ", count: indent * 4)
        let nextSpace = String(repeating: " ", count: (indent + 1) * 4)
        switch self {
        case .directory(let children):
            print("[")
            for child in children {
                print(nextSpace + child.key + ": ", terminator: "")
                child.value.printStructure(indent: indent + 1)
            }
            print("\(space)]")
        case .file(let data):
            print("\(data.count) bytes")
        }
    }
}

extension FileSystemItem: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = FileSystemItem

    public init(dictionaryLiteral elements: (String, FileSystemItem)...) {
        self = .directory(children: elements.reduce(into: [String: FileSystemItem](), { partialResult, pair in
            partialResult[pair.0] = pair.1
        }))
    }
}
