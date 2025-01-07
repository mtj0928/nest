import NestKit

struct TestingEnvironmentVariables: EnvironmentVariableStorage {
    private var environmentVariables: [String: String]

    init(environmentVariables: [String : String?]) {
        self.environmentVariables = environmentVariables.compactMapValues { $0 }
    }

    subscript(_ key: String) -> String? {
        environmentVariables[key]
    }

}
