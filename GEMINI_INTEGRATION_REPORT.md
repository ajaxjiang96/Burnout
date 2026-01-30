# Gemini CLI Integration Report

**Date:** January 30, 2026
**Status:** Implemented & Verified
**Module:** `BurnoutFeature`

## Overview
The Gemini CLI integration has been implemented to allow *Burnout* to display usage statistics from the Google Gemini CLI alongside Claude.ai stats. This integration functions by executing the `gemini stats session` command locally on the user's machine and parsing the standard output.

## Architecture

### 1. Service Layer (`GeminiUsageService.swift`)
- **Protocol:** `GeminiUsageServiceProtocol`
- **Implementation:** `GeminiUsageService`
- **Mechanism:**
  - Uses `Foundation.Process` to execute shell commands.
  - Wraps execution in `zsh -l -c` to ensure the user's shell environment (specifically `PATH` for Node.js) is loaded.
  - **Path Handling:** Handles escaping of spaces in paths and implicit `node` executable resolution.
  - **Concurrency:** Reads `stdout` and `stderr` asynchronously using `Task` to prevent pipe deadlocks on large outputs.
  - **Timeout:** Defaults to 45 seconds to accommodate slow shell startups.

### 2. Data Models (`GeminiUsage.swift`)
- `GeminiUsage`: Aggregates usage across all models.
- `GeminiModelUsage`: Individual stats for models (e.g., `gemini-2.5-flash-lite`), including request count, percentage, and reset time.

### 3. State Management (`UsageViewModel.swift`)
- Manages `geminiExecutablePath` in `UserDefaults`.
- Polls for updates concurrently with Claude.ai stats.
- Aggregates usage percentages to determine the highest usage for the menu bar icon (Gauge/Flame).
- Error handling specific to Gemini (e.g., timeouts, missing executable).

### 4. User Interface
- **Settings:** New section to input/paste the `gemini` executable path. Includes a help popover with instructions (`which gemini`).
- **Dashboard:** Displays a distinct "Gemini CLI Usage" card with per-model progress bars and reset timers.

## Recent Fixes & Improvements
- **Timeout/Deadlock Fix:** Previously, the service would time out (25s) or hang if the CLI output filled the pipe buffer. This was resolved by:
  1. Increasing timeout to 45s.
  2. Consuming `stdout` and `stderr` streams concurrently via `Task`.
- **Bundle ID Standardization:** Updated all references to `com.ajaxjiang.Burnout` to match the configuration.

## Verification
- **Unit Tests:** `GeminiUsageTests.swift` passes. It verifies that the service can execute a mock script and correctly parse the output table structure.
- **Manual Testing:** Verified that `gemini stats session` output is correctly parsed into the UI models.

## Next Steps / Recommendations
- **Auto-Discovery:** Currently, the user must manually provide the path. Future work could attempt to auto-discover `gemini` in common locations (`/usr/local/bin`, `/opt/homebrew/bin`).
- **Keychain Integration:** If the CLI ever requires an API key passed via stdin/env (currently relies on CLI's internal auth), move storage to Keychain.
- **Sandbox:** The app currently runs unsandboxed. If sandboxing is enabled later, this CLI integration strategy (calling external subprocesses) will need a specific entitlement (`com.apple.security.app-sandbox.read-write` for the executable) or a helper tool.

## Technical Context for Handoff
- **Project Structure:** Swift Package Manager setup in `BurnoutPackage`.
- **Build System:** Xcode Workspace (`Burnout.xcworkspace`).
- **Logging:** Uses `os.Logger` subsystem `com.ajaxjiang.Burnout`.
