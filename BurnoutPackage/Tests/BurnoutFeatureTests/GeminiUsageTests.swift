import Testing
import Foundation
@testable import BurnoutFeature

struct GeminiUsageTests {
    @Test func testGeminiCommandExecution() async throws {
        // Since we are now using zsh -l -c to run the command, we can't easily mock the command by just pointing to a script 
        // because zsh will try to source profiles which might not exist or be weird in test env.
        // However, we can create a mock executable and pass it to the service.
        // But the service executes `zsh -l -c "PATH stats session"`.
        // So we need to ensure "PATH" is executable by zsh.
        
        let tempDir = FileManager.default.temporaryDirectory
        let mockGemini = tempDir.appendingPathComponent("gemini-mock.sh")
        
        // Ensure the mock is a valid shell script
        let scriptContent = """
        #!/bin/bash
        # Simply print the expected output regardless of arguments for this test
        echo "│  Model Usage                 Reqs                  Usage left"
        echo "│  ────────────────────────────────────────────────────────────"
        echo "│  gemini-2.5-flash-lite          4   97.7% (Resets in 22h 52m)"
        echo "│  gemini-3-pro-preview           3   78.0% (Resets in 22h 53m)"
        echo "│  gemini-no-requests             -   100.0% (Resets in 23h 00m)"
        """
        
        try scriptContent.write(to: mockGemini, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: mockGemini.path)
        
        defer { try? FileManager.default.removeItem(at: mockGemini) }
        
        let service = GeminiUsageService()
        let usage = try await service.fetchUsage(executablePath: mockGemini.path)
        
        #expect(usage.models.count == 3)
        
        let model1 = usage.models.first(where: { $0.name == "gemini-2.5-flash-lite" })!
        #expect(model1.requests == 4)
        #expect(model1.usagePercentage == 97.7)
        
        let model3 = usage.models.first(where: { $0.name == "gemini-no-requests" })!
        #expect(model3.requests == 0)
    }
}