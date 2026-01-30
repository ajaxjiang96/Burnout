import Foundation

public struct GeminiModelUsage: Codable, Sendable, Equatable, Identifiable {
    public let modelId: String
    public let tokenType: String
    public let remainingAmount: String?
    public let remainingFraction: Double
    public let resetTime: String
    
    public var id: String { "\(modelId)-\(tokenType)" }
    
    public var usagePercentage: Double {
        (1.0 - remainingFraction) * 100.0
    }
    
    public init(modelId: String, tokenType: String, remainingAmount: String?, remainingFraction: Double, resetTime: String) {
        self.modelId = modelId
        self.tokenType = tokenType
        self.remainingAmount = remainingAmount
        self.remainingFraction = remainingFraction
        self.resetTime = resetTime
    }
}

public struct GeminiUsage: Codable, Sendable, Equatable {
    public let buckets: [GeminiModelUsage]
    public let lastUpdated: Date
    
    public init(buckets: [GeminiModelUsage], lastUpdated: Date) {
        self.buckets = buckets
        self.lastUpdated = lastUpdated
    }
    
    public var maxUsagePercentage: Double {
        buckets.map(\.usagePercentage).max() ?? 0
    }
}