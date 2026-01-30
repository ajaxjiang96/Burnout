# Gemini CLI Integration Report

**Date:** January 30, 2026
**Status:** Implemented & Verified
**Module:** `BurnoutFeature`

## Overview
The Gemini CLI integration has been reimplemented to allow *Burnout* to display usage statistics from the Google Gemini CLI alongside Claude.ai stats. The integration now directly queries the internal Google Cloud Code Private API (`retrieveUserQuota`) using the user's local Gemini CLI credentials, offering a more robust and faster solution than shelling out to the binary.

## Architecture

### 1. Service Layer (`GeminiUsageService.swift`)
- **Protocol:** `GeminiUsageServiceProtocol`
- **Implementation:** `GeminiUsageService`
- **Mechanism:**
  - **Credentials:** Reads OAuth 2.0 credentials directly from `~/.gemini/oauth_creds.json`.
  - **API:** Sends a POST request to `https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota`.
  - **Authentication:** Uses the access token from the local credentials file.
  - **Payload:** Sends a placeholder project ID (`gemini-cli-placeholder`) which allows retrieving user-specific quota without needing a specific GCP project ID (for Pro/Advanced subscriptions).
  - **Dependencies:** Uses `URLSession` for network requests, allowing for easy testing via dependency injection.

### 2. Data Models (`GeminiUsage.swift`)
- **GeminiUsage:**
  - `buckets`: List of `GeminiModelUsage` items.
  - `lastUpdated`: Timestamp of the fetch.
- **GeminiModelUsage:**
  - `modelId`: Identifier (e.g., `gemini-1.5-pro`).
  - `tokenType`: Type of quota (e.g., `requests_per_minute`).
  - `remainingAmount`: String indicating remaining quota units.
  - `remainingFraction`: Double (0.0 - 1.0) indicating remaining percentage.
  - `resetTime`: ISO 8601 timestamp for quota reset.

### 3. State Management (`UsageViewModel.swift`)
- **Credential Detection:** Automatically detects if `~/.gemini/oauth_creds.json` exists via `hasGeminiCredentials`.
- **Logic:** Removed all code related to managing the executable path.
- **Polling:** Fetches usage data concurrently with Claude.ai stats.

### 4. User Interface
- **Settings:**
  - Removed "Gemini Executable Path" input field.
  - Added a status section indicating if credentials are found or missing.
  - Improved help text instructing users to run `gemini auth login` if unauthenticated.
- **Dashboard:**
  - Displays "Gemini CLI Quota" with per-model stats.
  - Shows **remaining** quota (e.g., "45 left") and usage percentage bars.
  - Displays relative reset time (e.g., "in 5h").

## Key Improvements
- **Performance:** Direct API call is significantly faster than spawning a shell process.
- **Reliability:** Eliminates issues with shell environment variations (PATH, zsh vs bash) and TCC permission prompts.
- **UX:** Zero configuration for the user. If they use the CLI, it just works.
- **Security:** No longer executing arbitrary binaries. Only reads the standard credential file.

## Verification
- **Unit Tests:** `GeminiUsageTests.swift` passes. It uses `MockURLProtocol` to verify that the service correctly reads credentials and decodes the API response.
- **Manual Verification:** Verified against real API responses to ensure field mapping is correct.

## Technical Context for Handoff
- **Project Structure:** Swift Package Manager setup in `BurnoutPackage`.
- **Entitlements:** The app is configured with `com.apple.security.files.user-selected.read-only` and `com.apple.security.network.client`. Since the app is currently not sandboxed, it can read `~/.gemini` directly. If sandboxing is enabled, a specific temporary exception or user intent (Open Panel) would be needed for that path.