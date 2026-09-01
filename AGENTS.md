# StillAir

macOS menu bar app for fanless Macs. Always shows peak temperature. When the machine is under thermal pressure, a 1–5 rank appears beside it (yellow → deep red). An always-on log records when those levels change.

> Product name: **StillAir**. Bundle ID `com.nsd97.StillAir`. Read-only: no fan control, no privileged helper — designed to sit beside fan-control apps.

## Architecture

Single unprivileged process. Reads SMC temperatures via IOKit. Reads thermal pressure via Darwin notify (`com.apple.system.thermalpressurelevel`). No privileged helper, no fan writes.

```
Menu bar (temp + rank) ← ThermalPressureMonitor (notify 0–4)
                       ← FanMonitor (SMC °C, digits only)
Throttle log           ← ThrottleEventLog (edges only)
```

Color and the 1–5 digit come from pressure rank, never from °C. A hot chip at Nominal stays default-colored; a cooler chip at Heavy is orange-red.

## Features

- Always-visible menu-bar temperature (°C / °F)
- Rank 2–5 beside the temp when pressure is Moderate or higher
- Persistent throttle log (timestamp, from → to, peak °C)
- CPU / memory / battery / disk detail views remain in the tree (unwired from the menu)

## Getting started

```bash
brew install xcodegen   # once
xcodegen generate
open ChillMac.xcodeproj # Run (⌘R) — or:
xcodebuild -project ChillMac.xcodeproj -scheme ChillMac -configuration Debug build
```

Debug is enough. There is no helper to notarize.

### Distribution (`scripts/build-dmg.sh`)

```bash
cp .env.example .env   # APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, APPLE_TEAM_ID
brew install create-dmg
./scripts/build-dmg.sh
# Output: build/StillAir.dmg
```

## Build System

Uses **XcodeGen** (`project.yml`).

| Target | Type | Bundle ID |
|--------|------|-----------|
| ChillMac | macOS app | com.idevtim.StillAir |

- Deployment target: macOS 13.0+
- Swift 5.9
- Hardened runtime enabled, sandbox disabled (IOKit SMC reads)

## Project Structure

```
ChillMac/
  App/              Entry, status item, settings, throttle menu, diagnostics
  Views/            SwiftUI settings + unused detail panels
  Fan/              Monitors (temps, CPU, memory, battery) + ThermalPressure
  SMC/              IOKit temperature reads
  Preview/          PreviewSupport factories
ChillMacTests/
scripts/            build-dmg.sh
```

## Key Patterns

- **FanMonitor** polls SMC temperatures (2s with the menu open, 10s idle)
- **ThermalPressureMonitor** uses `notify_register_dispatch` plus a 5s poll
- **ThrottleEventLog** records pressure edges to `~/Library/Application Support/StillAir/`
- Read `ProcessInfo.thermalState` before registering `thermalStateDidChangeNotification`
- Do not map notify 0–4 onto Fair/Serious/Critical names

## Testing

```bash
xcodegen generate && xcodebuild -project ChillMac.xcodeproj -scheme ChillMac -destination 'platform=macOS' test
```

Tag suites with `.unit`, `.thermal`, `.fixtures`. Sample data comes from `PreviewSupport`.
