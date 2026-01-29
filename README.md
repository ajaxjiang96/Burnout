<img src="docs/icon.png" width="128" align="center" />

# Burnout

A native macOS menu bar app that shows your Claude.ai usage at a glance — session and weekly utilization percentages, time until reset, and visual warnings when you're close to the limit.

## Features

- **Live usage display** — session (5-hour) and weekly (7-day) utilization from Claude.ai
- **Menu bar percentage** — always-visible usage percentage with configurable icon style (gauge or flame)
- **Reset countdown** — shows time remaining until rate limit resets when usage is high
- **Visual warnings** — icon changes at 50% and 90% thresholds
- **Auto-refresh** — polls every 60 seconds

## Requirements

- macOS 26 (Tahoe) or later
- A Claude.ai account with an active subscription

## Installation

### Download

Download the latest `.dmg` from the [Releases](../../releases) page. Open it and drag Burnout to your Applications folder.

### Build from Source

```bash
git clone https://github.com/ajayyy/Burnout.git
cd Burnout
open Burnout.xcworkspace
```

Build and run the **Burnout** scheme in Xcode 26+.

## Setup

Burnout needs two credentials from your Claude.ai session:

1. Go to [claude.ai/settings](https://claude.ai/settings) and open Developer Tools (`Cmd+Option+I`)
2. Go to **Network** tab and navigate to the Usage page
3. Find the `usage` request — copy the **Organization ID** (UUID in the URL path)
4. Go to **Application > Cookies > claude.ai** — copy the `sessionKey` value
5. Open Burnout's **Settings** (click the menu bar icon, then Settings) and paste both values

> **Note:** Session keys expire periodically. You'll need to update the key when it expires.

## Architecture

The app uses a **workspace + SPM package** structure:

- **`Burnout/`** — minimal app shell (`BurnoutApp.swift`, assets, entitlements)
- **`BurnoutPackage/`** — all business logic as a Swift Package
  - `Models/` — `ClaudeWebUsage` API response model
  - `Services/` — `UsageServiceProtocol` and `ClaudeUsageService`
  - `ViewModels/` — `UsageViewModel` (central state, @MainActor)
  - `ContentView.swift` — menu bar popup UI
  - `SettingsView.swift` — credentials and display preferences

Data flows from the Claude.ai usage API through `ClaudeUsageService` into `UsageViewModel`, which drives the SwiftUI views.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, coding conventions, and how to submit changes.

## License

Burnout is licensed under the [GNU General Public License v3.0](LICENSE).

This means:
- You can use, modify, and distribute this software freely
- Any derivative work must also be released under GPL-3.0
- The GPL-3.0 is incompatible with Apple's App Store DRM, so forks cannot be redistributed via the App Store without a separate license grant from the copyright holder

Copyright (C) 2025 Jiacheng Jiang
