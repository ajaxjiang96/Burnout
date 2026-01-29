# Contributing to Burnout

Thanks for your interest in contributing to Burnout! This document covers how to set up the project, make changes, and submit them.

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/ajayyy/Burnout.git
   cd Burnout
   ```

2. Open the workspace in Xcode 26+:
   ```bash
   open Burnout.xcworkspace
   ```

3. Build and run the **Burnout** scheme.

All business logic lives in `BurnoutPackage/Sources/BurnoutFeature/`. The `Burnout/` directory is a thin app shell.

## Making Changes

1. Fork the repository and create a branch from `main`.
2. Make your changes in `BurnoutPackage/Sources/BurnoutFeature/`.
3. Add or update tests in `BurnoutPackage/Tests/BurnoutFeatureTests/`.
4. Verify the build and tests pass:
   ```bash
   xcodebuild -workspace Burnout.xcworkspace -scheme Burnout -configuration Debug build
   xcodebuild test -workspace Burnout.xcworkspace -scheme Burnout -testPlan Burnout
   ```
5. Open a pull request against `main`.

## Code Style

- **Logging**: Use `os.Logger` with subsystem `"com.ajax.Burnout"`, not `print()`.
- **Access control**: All types used by the app target must be `public` (they're in a separate SPM package).
- **Testing**: Use Swift Testing framework (`import Testing`, `@Test`, `#expect`), not XCTest.
- **Concurrency**: Follow Swift 6 concurrency conventions. `UsageViewModel` is `@MainActor`.

## Reporting Issues

Open a [GitHub Issue](../../issues) with:
- What you expected to happen
- What actually happened
- macOS version and Burnout version
- Steps to reproduce (if applicable)

## License

By contributing, you agree that your contributions will be licensed under the [GNU General Public License v3.0](LICENSE). All contributions must be your own original work or clearly attributed.
