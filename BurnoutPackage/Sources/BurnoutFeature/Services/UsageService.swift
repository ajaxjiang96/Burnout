import Foundation

public enum WebUsageError: Error, LocalizedError {
    case invalidCredentials
    case sessionExpired
    case networkError(Error)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Please enter both Organization ID and Session Key."
        case .sessionExpired:
            return "Session expired. Please update your session key."
        case .networkError(let error):
            return "Unable to connect: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server."
        }
    }
}

public protocol UsageServiceProtocol: Sendable {
    func fetchWebUsage(sessionKey: String, organizationId: String) async throws -> ClaudeWebUsage
}

public final class ClaudeUsageService: UsageServiceProtocol, Sendable {
    public init() {}

    public func fetchWebUsage(sessionKey: String, organizationId: String) async throws -> ClaudeWebUsage {
        guard !sessionKey.isEmpty, !organizationId.isEmpty else {
            throw WebUsageError.invalidCredentials
        }

        guard let url = URL(string: "https://claude.ai/api/organizations/\(organizationId)/usage") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw WebUsageError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebUsageError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw WebUsageError.sessionExpired
        }

        guard httpResponse.statusCode == 200 else {
            throw WebUsageError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }

        do {
            return try decoder.decode(ClaudeWebUsage.self, from: data)
        } catch {
            print("Decoding error: \(error)")
            throw WebUsageError.invalidResponse
        }
    }
}
