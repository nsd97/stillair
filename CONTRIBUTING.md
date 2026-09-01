# Contributing to StillAir

Thanks for wanting to help. Here's how to get started.

## Setup

```bash
git clone https://github.com/YOUR_USERNAME/chillmac.git
cd chillmac
brew install xcodegen
xcodegen generate
```

Open `ChillMac.xcodeproj` in Xcode or build from the command line:

```bash
xcodebuild -project ChillMac.xcodeproj -scheme ChillMac build
```

No helper, no Developer ID required for local Debug runs.

## Making Changes

1. Fork the repo and create a branch from `main`
2. Make your changes
3. Make sure it builds: `xcodegen generate && xcodebuild -scheme ChillMac build`
4. Run unit tests: `xcodebuild -project ChillMac.xcodeproj -scheme ChillMac -destination 'platform=macOS' test`
5. Open a PR

## Project Overview

- **`project.yml`** — XcodeGen config. Don't edit the `.xcodeproj` directly.
- **`ChillMac/`** — Menu bar app (SMC temperature reads, thermal pressure, SwiftUI settings)
- **`ChillMacTests/`** — Swift Testing

## Guidelines

- Keep PRs focused — one feature or fix per PR
- Match the existing code style
- New monitors/data models go in `ChillMac/Fan/`
- Use `PreviewSupport` for sample data; add in-file `#Preview` (no live SMC in canvas)
- Zero external dependencies (Swift Testing only)
- Color the menu bar from `ThermalPressure`, never from °C

## Questions?

Open an issue — happy to help.
