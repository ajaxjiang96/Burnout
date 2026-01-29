# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Burnout is a native macOS status bar app that displays real-time Claude Code (and Gemini) usage statistics. It shows the current usage percentage, rate limits, and time until reset in the menu bar. The app reads from Claude Code's local stats cache and can also fetch live rate limit data via API.

**Current State**: The app structure exists but requires implementation. The GeminiUsageService is a placeholder. The app uses Xcode 26's workspace + SPM package architecture.

## Development Commands

### Building & Running
```bash
# Open in Xcode
open Burnout.xcworkspace

# Build from command line
xcodebuild -workspace Burnout.xcworkspace -scheme Burnout -configuration Debug build

# Run tests
xcodebuild test -workspace Burnout.xcworkspace -scheme Burnout -testPlan Burnout
```

### Testing
The project uses Swift Testing framework (not XCTest) for unit tests in `BurnoutPackage/Tests/BurnoutFeatureTests/`.

## Architecture

### Workspace Structure
- **Burnout.xcworkspace**: Main workspace file (open this)
- **Burnout.xcodeproj**: App shell project
- **BurnoutPackage/**: Swift Package with all business logic

### Code Organization

```
BurnoutPackage/Sources/BurnoutFeature/
├── Models/
│   ├── ClaudeStats.swift        # Stats cache JSON structure
│   └── RateLimitInfo.swift      # API rate limit data model
├── Services/
│   ├── UsageService.swift       # Service protocol & ClaudeUsageService
│   └── GeminiUsageService.swift # Placeholder for Gemini support
├── ViewModels/
│   └── UsageViewModel.swift     # Main app state & business logic
└── ContentView.swift             # StatusView UI (menu bar popup)
```

### Key Architecture Patterns

**MVVM with Services Layer**:
- `UsageViewModel` is the central state holder (@MainActor, ObservableObject)
- Services conform to `UsageServiceProtocol` for provider abstraction
- Two data sources: local stats cache (`~/.claude/stats-cache.json`) and live API rate limits

**MenuBarExtra App**:
- Uses `MenuBarExtra` scene (not `WindowGroup`)
- Status bar shows dynamic icon (flame → flame.fill → warning triangle) and percentage/countdown
- Clicking opens a popup window with detailed stats

**Provider Abstraction**:
- `ProviderType` enum supports Claude and Gemini
- `UsageServiceProtocol` defines interface for both providers
- ViewModel switches service implementation based on selected provider

**Data Flow**:
1. ViewModel calls service methods
2. `ClaudeUsageService` reads `~/.claude/stats-cache.json` for daily/weekly message counts
3. If API key provided, service makes lightweight API call to fetch rate limit headers
4. ViewModel updates @Published properties, UI reacts automatically
5. Auto-refreshes every 60 seconds

### Public API Requirements

All types used by the app target must be `public` since they're in a separate SPM package:
- Views: `public struct StatusView: View { public init(...) { } }`
- ViewModels: `public class UsageViewModel: ObservableObject { }`
- Models: `public struct ClaudeStats: Codable { }`

## Data Sources

### Local Stats Cache
- Location: `~/.claude/stats-cache.json`
- Structure: See `ClaudeStats` model
- Contains: daily message counts, session counts, tool call counts
- Updated by: Claude Code CLI

### API Rate Limits (Optional)
- Endpoint: `https://api.anthropic.com/v1/messages` (HEAD request pattern)
- Headers: `anthropic-ratelimit-*` headers contain limits/remaining/reset times
- Current implementation: Makes minimal POST request to get headers (1 token response)
- Shows: requests remaining, tokens remaining, reset times

## Configuration

### Entitlements
Location: `Config/Burnout.entitlements`

Currently configured:
- App Sandbox: **DISABLED** (`com.apple.security.app-sandbox` = false)
  - Required to read `~/.claude/stats-cache.json` outside sandbox
- Network client: Enabled for API calls
- File access: Read-only user-selected files

**Important**: The sandbox is disabled to access the stats cache file. This is necessary for the app's core functionality.

### Build Settings
XCConfig files in `Config/`:
- `Shared.xcconfig`: Bundle ID, versions, deployment target (macOS 15.4)
- `Debug.xcconfig`: Debug-specific settings
- `Release.xcconfig`: Release-specific settings
- `Tests.xcconfig`: Test target settings

## Implementation Notes

### Status Bar Icon Logic
The menu bar icon changes based on usage percentage:
- 0-50%: `flame` (hollow)
- 50-90%: `flame.fill` (solid)
- 90%+: `exclamationmark.triangle.fill` (warning)

When usage > 90% and rate limit info available, shows countdown timer instead of percentage.

### Rate Limit Display Strategy
- If API key provided: Shows actual rate limit data (requests/tokens remaining)
- If no API key: Shows simple message count vs daily limit
- Usage percentage prioritizes the more restrictive limit (requests vs tokens)

### Error Handling
- Invalid API key → Shows "Invalid API Key" error message
- Missing stats file → Returns zero counts (graceful degradation)
- Network errors → Displays localized error description

### User Settings Persistence
- API key stored in `UserDefaults` with key `"burnout_api_key"`
- Automatically trimmed of whitespace on save
- Daily limit stored in ViewModel (not persisted yet)

## Future Work / Incomplete Features

1. **GeminiUsageService**: Currently returns placeholder data
2. **Persistence**: Daily limit and provider selection not saved to UserDefaults
3. **Stats cache auto-discovery**: Hardcoded path to `~/.claude/stats-cache.json`
4. **Rate limit caching**: Makes API call on every refresh (could cache for ~5 min)
5. **Error recovery**: Could auto-clear API key on persistent auth failures
