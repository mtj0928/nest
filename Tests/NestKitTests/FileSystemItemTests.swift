import NestKit
import NestTestHelpers
import Testing

struct FileSystemItemTests {
    public enum DummyData {
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

