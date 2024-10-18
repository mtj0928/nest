import Foundation
import Testing

enum FileSystemItem: Equatable {
    case directory(children: [String: FileSystemItem])
    case file(data: Data)

    mutating func remove(at components: [String]) {
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

    mutating func update(item: FileSystemItem, at components: [String]) {
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

    func item(components: [String]) -> FileSystemItem? {
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

    func printStructure(indent: Int = 0) {
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
    typealias Key = String
    typealias Value = FileSystemItem

    init(dictionaryLiteral elements: (String, FileSystemItem)...) {
        self = .directory(children: elements.reduce(into: [String: FileSystemItem](), { partialResult, pair in
            partialResult[pair.0] = pair.1
        }))
    }
}

struct FileSystemItemTests {
    enum DummyData {
        static let aTextData = "a.txt".data(using: .utf8)!
        static let bTextData = "b.txt".data(using: .utf8)!
        static let cTextData = "c".data(using: .utf8)!
    }

    let initialItem: FileSystemItem = [
        "a": [
            "b.txt": .file(data: DummyData.bTextData),
            "b": ["c": .file(data: DummyData.cTextData)]
        ],
        "a.txt": .file(data: DummyData.aTextData)
    ]

    @Test
    func item() throws {
        var item = initialItem
        var result = item.item(components: ["a", "b"])
        #expect(result == ["c": .file(data: DummyData.cTextData)])

        item = initialItem
        result = item.item(components: ["a", "b.txt"])
        #expect(result == .file(data: DummyData.bTextData))
    }

    @Test
    func remove() throws {
        var item = initialItem
        item.remove(at: ["a", "b"])
        #expect(item == [
            "a": ["b.txt": .file(data: DummyData.bTextData),],
            "a.txt": .file(data: DummyData.aTextData)
        ])
    }

    @Test
    func update() throws {
        var item = initialItem
        item.update(item: .file(data: DummyData.aTextData), at: ["a", "b", "c-1"])
        item.update(item: .file(data: DummyData.cTextData), at: ["a", "b.txt"])
        #expect(item == [
            "a": [
                "b.txt": .file(data: DummyData.cTextData),
                "b": [
                    "c": .file(data: DummyData.cTextData),
                    "c-1": .file(data: DummyData.aTextData)
                ]
            ],
            "a.txt": .file(data: DummyData.aTextData)
        ])

    }
}

