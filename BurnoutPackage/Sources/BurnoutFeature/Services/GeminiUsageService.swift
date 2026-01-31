import Foundation
import os

public enum GeminiUsageError: Error, LocalizedError {
    case credentialsNotFound
    case invalidCredentials
    case sessionExpired
    case apiError(Int, String)
    case invalidResponse
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .credentialsNotFound:
            return "Gemini CLI credentials not found. Run 'gemini auth login' in your terminal."
        case .invalidCredentials:
            return "Invalid Gemini CLI credentials. Try running 'gemini auth login' again."
        case .sessionExpired:
            return "Gemini session expired. Run any 'gemini' command to refresh."
        case .apiError(let code, let message):
            return "API Error \(code): \(message)"
        case .invalidResponse:
            return "Could not parse API response."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

public protocol GeminiUsageServiceProtocol: Sendable {
    func fetchUsage() async throws -> GeminiUsage
    func attemptRefresh() async throws
}

public final class GeminiUsageService: GeminiUsageServiceProtocol, Sendable {
    private static let logger = Logger(subsystem: "com.ajaxjiang.Burnout", category: "GeminiUsageService")
    
    // Internal struct for decoding credentials
    private struct OAuthCredentials: Decodable {
        let access_token: String
        let expiry_date: Int64?
        // Other fields ignored
    }
    
    // Internal struct for API response
    private struct GeminiQuotaResponse: Decodable {
        let buckets: [GeminiModelUsage]
    }
    
    private let urlSession: URLSession
    private let credentialsURL: URL
    
    public init(urlSession: URLSession = .shared, credentialsURL: URL? = nil) {
        self.urlSession = urlSession
        if let credentialsURL = credentialsURL {
            self.credentialsURL = credentialsURL
        } else {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            self.credentialsURL = homeDir.appendingPathComponent(".gemini/oauth_creds.json")
        }
    }
    
    public func fetchUsage() async throws -> GeminiUsage {
        try await fetchUsageWithRetry(allowRefresh: true)
    }
    
    private func fetchUsageWithRetry(allowRefresh: Bool) async throws -> GeminiUsage {
        // 1. Locate credentials
        guard FileManager.default.fileExists(atPath: credentialsURL.path) else {
            throw GeminiUsageError.credentialsNotFound
        }
        
        // 2. Read and parse credentials
        let accessToken: String
        do {
            let data = try Data(contentsOf: credentialsURL)
            let creds = try JSONDecoder().decode(OAuthCredentials.self, from: data)
            accessToken = creds.access_token
        } catch {
            Self.logger.error("Failed to parse credentials: \(error)")
            throw GeminiUsageError.invalidCredentials
        }
        
        // 3. Make API Request
        let url = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["project": "gemini-cli-placeholder"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw GeminiUsageError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiUsageError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            if allowRefresh {
                Self.logger.info("Gemini token expired, attempting refresh...")
                do {
                    try await attemptRefresh()
                    return try await fetchUsageWithRetry(allowRefresh: false)
                } catch {
                    Self.logger.error("Auto-refresh failed: \(error)")
                    throw GeminiUsageError.sessionExpired
                }
            } else {
                throw GeminiUsageError.sessionExpired
            }
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            Self.logger.error("API Error: \(httpResponse.statusCode) - \(errorMsg)")
            throw GeminiUsageError.apiError(httpResponse.statusCode, errorMsg)
        }
        
        // 4. Decode Response
        do {
            let quotaResponse = try JSONDecoder().decode(GeminiQuotaResponse.self, from: data)
            return GeminiUsage(buckets: quotaResponse.buckets, lastUpdated: Date())
        } catch {
            Self.logger.error("Failed to decode response: \(error)")
            throw GeminiUsageError.invalidResponse
        }
    }
    
    public func attemptRefresh() async throws {
        // Run a lightweight command to trigger the CLI's refresh logic
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gemini", "models", "list"]
        
        // Suppress output
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw GeminiUsageError.sessionExpired
        }
    }
}