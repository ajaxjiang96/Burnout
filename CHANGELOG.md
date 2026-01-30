# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-01-31

### Added
- Automatic update checking via GitHub Releases
- "Launch at Login" option in Settings
- Toggles to enable/disable Claude.ai and Gemini services independently
- Support for Gemini CLI usage tracking (Flash, Pro, Flash-Lite models)
- Buy Me a Coffee link in Settings

### Changed
- Refined menu bar display to prioritize the active service (Gemini vs Claude)
- Improved usage visualization gauges and lists
- Streamlined Settings and Status view layouts
- Refactored Gemini integration for better stability using internal APIs

### Fixed
- Fixed menu bar display logic to correctly show active service
- Fixed Gemini CLI timeout and connection issues
- Fixed "Launch at Login" persistence issues
- Fixed Settings window presentation logic

## [1.0.0] - 2026-01-29

### Added
- Menu bar display showing Claude.ai usage percentage
- Session (5-hour) and weekly (7-day) usage tracking via Claude.ai API
- Configurable menu bar icon style (gauge or flame)
- Configurable usage metric display (highest, session, or weekly)
- Reset countdown timer when usage exceeds 90%
- Settings window for credential entry and display preferences
- Auto-refresh every 60 seconds
- Visual usage gauges with color-coded thresholds
