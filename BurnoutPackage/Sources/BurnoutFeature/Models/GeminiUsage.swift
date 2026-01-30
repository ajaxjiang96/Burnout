import Foundation

public struct GeminiModelUsage: Codable, Sendable, Equatable, Identifiable {
    public let name: String
    public let requests: Int
    public let usagePercentage: Double
    public let resetsIn: String
    
    public var id: String { name }
    
    public init(name: String, requests: Int, usagePercentage: Double, resetsIn: String) {
        self.name = name
        self.requests = requests
        self.usagePercentage = usagePercentage
        self.resetsIn = resetsIn
    }
}

public struct GeminiUsage: Codable, Sendable, Equatable {
    public let models: [GeminiModelUsage]
    public let lastUpdated: Date
    
    public init(models: [GeminiModelUsage], lastUpdated: Date) {
        self.models = models
        self.lastUpdated = lastUpdated
    }
    
    public var maxUsagePercentage: Double {
        models.map(\.usagePercentage).max() ?? 0
    }
}