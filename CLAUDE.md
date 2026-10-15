# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

MemPulse is a macOS menu-bar app (SwiftUI `MenuBarExtra`, `LSUIElement`, no Dock icon) that shows system memory pressure as a colored dot, plus swap/RAM figures and the top-5 memory-hungry apps with a "close" button.

## Build & test

The `.xcodeproj` is **generated** from `project.yml` by XcodeGen and is gitignored. `project.yml` is the source of truth — never hand-edit the `pbxproj`. After adding/removing source files or changing build settings, regenerate:

```sh
xcodegen generate
xcodebuild -scheme MemPulse -destination 'platform=macOS' build
xcodebuild test -scheme MemPulse -destination 'platform=macOS'
```

Single test:

```sh
xcodebuild test -scheme MemPulse -destination 'platform=macOS' \
  -only-testing:MemPulseTests/SystemStatsTests/testParseProcLinesSortsByBytesDescendingWithNamesAndPids
```

Exercise the pressure levels at runtime: `sudo memory_pressure -l warn -S -s 15` (yellow), `-l critical` (red).

## Architecture

`PressureMonitor` (`@MainActor` `ObservableObject`) is the single source of truth the UI observes. Two independent update paths feed it:

- **Dot color** — `DispatchSource.makeMemoryPressureSource`. Kernel push notification, no polling; the handler maps `.critical`/`.warning`/`.normal` to `Level` and posts a user notification on entering `.critical`. The source only fires on changes, so `init` seeds the level from `SystemStats.pressureLevel()` (`sysctl kern.memorystatus_vm_pressure_level`).
- **Swap / RAM / top processes** — polled every 5 s by a `Timer`, each `refresh()` runs `SystemStats` calls on a detached task and hops back to `MainActor` to publish.

`SystemStats` is a stateless enum of free functions:
- `swapUsed()` — `sysctl vm.swapusage`
- `memoryStats()` — Mach `host_statistics64` / `HOST_VM_INFO64`
- `topProcesses()` — spawns `/bin/ps -axo pid=,rss=,comm=`, then `parseProcLines` (the pure, testable seam; `rss` is KB, `comm` is a path that may contain spaces). It groups processes by their outermost `.app` and keeps the pid of the main executable (`X.app/Contents/MacOS/…`) so "Cerrar" quits the whole app (⌥ = `forceTerminate`)

`dotImage` renders a non-template `NSImage` so the menu bar keeps the real color instead of tinting it monochrome.

Tests cover only `parseProcLines` (sorting + app grouping) and a swap sanity bound. The Mach/sysctl glue is intentionally untested and verified by hand against Activity Monitor.

## Constraints

- **No App Sandbox** (the app shells out to `/bin/ps`). Hardened runtime is on. Don't add the sandbox entitlement without replacing the `ps` call.
- Deployment target macOS 14.0, Swift 5. `SMAppService` provides launch-at-login.
