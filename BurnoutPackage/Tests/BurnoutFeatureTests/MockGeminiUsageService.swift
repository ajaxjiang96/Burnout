import Foundation
@testable import BurnoutFeature

final actor MockGeminiUsageService: GeminiUsageServiceProtocol {
    var usageToReturn: GeminiUsage?
    var errorToThrow: Error?
    var refreshCalled = false

    func fetchUsage() async throws -> GeminiUsage {
        if let error = errorToThrow {
            throw error
        }
        return usageToReturn ?? GeminiUsage(buckets: [], lastUpdated: Date())
    }

    func attemptRefresh() async throws {
        refreshCalled = true
    }
}
