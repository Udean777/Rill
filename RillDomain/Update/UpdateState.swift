import Foundation

/// Lifecycle state of the in-app update checker and installer.
public enum UpdateState: Equatable, Sendable {
    case idle
    case checking
    case upToDate
    case available(version: String)
    case downloading(progress: Double?)
    case installing
    case readyToQuit(version: String)
    case failed(String)
}

/// GitHub Releases API payload for `/repos/<owner>/<repo>/releases/latest`.
public struct GitHubRelease: Codable, Sendable {
    public let tagName: String
    public let htmlUrl: String
    public let body: String?
    public let assets: [GitHubAsset]

    public enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case body
        case assets
    }
}

/// Asset entry inside a `GitHubRelease`.
public struct GitHubAsset: Codable, Sendable {
    public let name: String
    public let browserDownloadUrl: String
    public let size: Int64?

    public enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}
