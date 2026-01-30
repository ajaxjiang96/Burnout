import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import BurnoutFeature

class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
}

struct GeminiUsageTests {
    @Test func testGeminiAPIFetch() async throws {
        // 1. Setup Mock URLSession
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        
        // 2. Setup Mock Credentials
        let tempDir = FileManager.default.temporaryDirectory
        let mockCredsURL = tempDir.appendingPathComponent("mock_creds.json")
        let credsJSON = """
        {
          "access_token": "mock_token_123",
          "expiry_date": 1234567890
        }
        """
        try credsJSON.write(to: mockCredsURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: mockCredsURL) }
        
        // 3. Setup Mock API Response
        let responseJSON = """
        {
          "buckets": [
            {
              "remainingAmount": "45",
              "remainingFraction": 0.45,
              "resetTime": "2025-10-30T10:00:00Z",
              "tokenType": "requests_per_minute",
              "modelId": "gemini-1.5-pro"
            },
            {
              "remainingAmount": "100",
              "remainingFraction": 1.0,
              "resetTime": "2025-10-30T10:00:00Z",
              "tokenType": "requests_per_minute",
              "modelId": "gemini-1.5-flash"
            }
          ]
        }
        """
        
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url, url.absoluteString == "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota" else {
                throw URLError(.badURL)
            }
            
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseJSON.data(using: .utf8)!)
        }
        
        // 4. Test Service
        let service = GeminiUsageService(urlSession: session, credentialsURL: mockCredsURL)
        let usage = try await service.fetchUsage()
        
        #expect(usage.buckets.count == 2)
        
        let proModel = usage.buckets.first(where: { $0.modelId == "gemini-1.5-pro" })!
        #expect(proModel.remainingFraction == 0.45)
        #expect(abs(proModel.usagePercentage - 55.0) < 0.0001) // (1.0 - 0.45) * 100
        
        let flashModel = usage.buckets.first(where: { $0.modelId == "gemini-1.5-flash" })!
        #expect(flashModel.remainingFraction == 1.0)
        #expect(flashModel.usagePercentage == 0.0)
    }
}
