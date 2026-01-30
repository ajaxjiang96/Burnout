# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Burnout, please report it responsibly by [opening a GitHub issue](../../issues) with the label "security". If the issue is sensitive, please note that in the issue title and avoid including exploit details in the public description — a maintainer will follow up privately.

## Known Limitations

### Credential Storage

Burnout currently stores the Claude.ai session key and organization ID in `UserDefaults`, which is plain text on disk. This is a known limitation.

**Mitigations:**

- The session key is a temporary cookie value that expires periodically
- The app runs unsandboxed, so Keychain access is available — migration to Keychain is planned
- The `UserDefaults` plist is only readable by the current user (standard macOS file permissions)

**Recommendation:** Be aware that anyone with access to your macOS user account can read the stored session key from `~/Library/Preferences/com.ajaxjiang.Burnout.plist`.

## Supported Versions

Only the latest release is supported with security updates.
