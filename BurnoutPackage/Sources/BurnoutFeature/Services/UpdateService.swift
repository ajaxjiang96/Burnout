import Foundation

public enum UpdateError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case noReleaseFound
}

public protocol UpdateServiceProtocol: Sendable {
    func checkForUpdates() async throws -> GitHubRelease?
}

public struct GitHubUpdateService: UpdateServiceProtocol {
    private let repoOwner = "ajaxjiang96"
    private let repoName = "Burnout"
    
    public init() {}

    public func checkForUpdates() async throws -> GitHubRelease? {
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else {
            throw UpdateError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        // Add a user agent to avoid GitHub blocking requests with no UA
        request.setValue("Burnout-App", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw UpdateError.noReleaseFound
        }
        
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        
        // Compare versions
        if isNewer(release.tagName) {
            return release
        }
        return nil
    }
    
    private func isNewer(_ tagName: String) -> Bool {
        // Handle "v" prefix
        let cleanTag = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        
        // Get current version from main bundle (the app), not the package bundle
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        
        return cleanTag.compare(currentVersion, options: .numeric) == .orderedDescending
    }
}
