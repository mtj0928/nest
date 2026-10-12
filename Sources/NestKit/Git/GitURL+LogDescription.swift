extension GitURL {
    /// Formats a repository URL for logs without credentials, query, or fragment.
    ///
    /// SSH references keep the host and repository path without the user name.
    package var logDescription: String {
        switch self {
        case .url(let url):
            url.logDescription
        case .ssh(let sshURL):
            "\(sshURL.host):\(sshURL.path)"
        }
    }
}
