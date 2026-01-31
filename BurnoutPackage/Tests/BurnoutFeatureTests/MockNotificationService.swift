import Foundation
import BurnoutFeature

final actor MockNotificationService: NotificationServiceProtocol {
    func requestPermission() async throws -> Bool {
        return true
    }

    func checkAndNotify(for usage: ClaudeWebUsage?, gemini: GeminiUsage?) async {
        // No-op for tests
    }
}
