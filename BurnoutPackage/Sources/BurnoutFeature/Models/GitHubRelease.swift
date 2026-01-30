import Foundation

public struct GitHubRelease: Codable, Equatable {
    public let tagName: String
    public let htmlUrl: String
    public let body: String
    public let publishedAt: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case body
        case publishedAt = "published_at"
    }
}
