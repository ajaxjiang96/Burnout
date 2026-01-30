# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Burnout is a native macOS menu bar app that displays real-time Claude.ai usage statistics. It shows the current usage percentage, rate limits, and time until reset directly in the menu bar. The app fetches data from the Claude.ai web usage API.

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
│   └── ClaudeWebUsage.swift     # Web usage API response model
├── Services/
│   └── UsageService.swift       # Service protocol & ClaudeUsageService
├── ViewModels/
│   └── UsageViewModel.swift     # Main app state & business logic
├── ContentView.swift            # StatusView UI (menu bar popup)
└── SettingsView.swift           # Settings window (credentials, display options)
```

### Key Architecture Patterns

**MVVM with Services Layer**:

- `UsageViewModel` is the central state holder (@MainActor, ObservableObject)
- `ClaudeUsageService` conforms to `UsageServiceProtocol` for testability
- Single data source: Claude.ai web usage API

**MenuBarExtra App**:

- Uses `MenuBarExtra` scene (not `WindowGroup`)
- Status bar shows dynamic icon (gauge or flame, configurable) and percentage/countdown
- Clicking opens a popup window with detailed stats
- Settings window via `Settings` scene

**Data Flow**:

1. ViewModel calls `ClaudeUsageService.fetchWebUsage(sessionKey:organizationId:)`
2. Service fetches from `https://claude.ai/api/organizations/{orgId}/usage`
3. Response decoded into `ClaudeWebUsage` (contains `fiveHour` and `sevenDay` `UsageWindow` structs)
4. ViewModel updates @Published properties, UI reacts automatically
5. Auto-refreshes every 60 seconds

### Public API Requirements

All types used by the app target must be `public` since they're in a separate SPM package:

- Views: `public struct StatusView: View { public init(...) { } }`
- ViewModels: `public class UsageViewModel: ObservableObject { }`
- Models: `public struct ClaudeWebUsage: Codable, Sendable, Equatable { }`

## Configuration

### Entitlements

Location: `Config/Burnout.entitlements`

Currently configured:

- App Sandbox: **DISABLED** (`com.apple.security.app-sandbox` = false)
- Network client: Enabled for API calls
- File access: Read-only user-selected files

**Important**: The sandbox is disabled because sandboxed apps cannot make authenticated requests to claude.ai with cookies.

### Build Settings

XCConfig files in `Config/`:

- `Shared.xcconfig`: Bundle ID (`com.ajaxjiang.Burnout`), versions, deployment target (macOS 26.0)
- `Debug.xcconfig`: Debug-specific settings
- `Release.xcconfig`: Release-specific settings
- `Tests.xcconfig`: Test target settings

## Implementation Notes

### Status Bar Icon Logic

The menu bar icon style is configurable (Gauge or Flame). Each changes based on usage:

- **Gauge**: `gauge.with.dots.needle.bottom.0percent` / `50percent` / `100percent`
- **Flame**: `flame` → `flame.fill` → `exclamationmark.triangle.fill`

Thresholds: 0-50% (low), 50-90% (medium), 90%+ (high).

When usage > 90% and reset time available, shows countdown timer instead of percentage.

### Display Options

Users can choose which usage metric to display:

- **Highest**: Maximum of session and weekly utilization
- **Session (5h)**: Five-hour rolling window
- **Weekly (7d)**: Seven-day rolling window

### Error Handling

- Missing credentials → Shows empty state prompting to open Settings
- Session expired (401/403) → Shows "Session expired" error
- Network errors → Displays localized error description

### User Settings Persistence

All settings stored in `UserDefaults`:

- `burnout_session_key`: Claude.ai session key (cookie value)
- `burnout_org_id`: Organization UUID from Claude.ai
- `burnout_displayed_usage`: Which usage metric to show (Highest/Session/Weekly)
- `burnout_menu_bar_icon`: Icon style (Gauge/Flame)

### Logging

Uses `os.Logger` (not `print()`). Subsystem: `com.ajaxjiang.Burnout`. Categories: `App`, `UsageService`, `UsageViewModel`.

## Future Work

1. **Keychain storage**: Credentials currently in UserDefaults (plain text); migrate to Keychain
2. **Response caching**: Cache API responses to reduce request frequency
3. **Multiple accounts**: Support monitoring multiple Claude.ai organizations
4. **Notifications**: Alert when usage approaches limits
