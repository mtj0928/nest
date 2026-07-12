import ArgumentParser

struct CacheOptions: ParsableArguments {
    @Flag(name: .customLong("enable-user-scope-cache"), help: "Cache downloaded artifact bundle ZIPs in the user cache directory and reuse them across nest paths.")
    var enableUserScopeCache = false
}
