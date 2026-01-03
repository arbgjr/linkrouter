# LinkRouter - AI Coding Agent Instructions

## Project Overview
LinkRouter is a Windows system-level URL handler that intercepts HTTP/HTTPS links and routes them to specific browsers based on the originating application. It's built with AutoHotkey v2.0 and registers itself as a custom URL protocol handler (`LinkRouterURL://`) in the Windows registry.

## Architecture & Key Components

### Core Components
- **[LinkRouter.ahk](LinkRouter.ahk)**: Main AHK script (365 lines)
  - Receives URL as `A_Args[1]` when invoked by Windows
  - Detects originating process via `WinGetID` + `WinGetPID` + `ProcessGetName`
  - Loads config, applies routing rules, launches target browser
  - Logs all routing decisions to `%TEMP%\linkrouter_debug.log`
  - **Pure AHK v2 JSON parser** (lines 142-365) - no external dependencies

- **[linkrouter.config.json](linkrouter.config.json)**: Routing rules
  ```json
  {
    "default": "edge",
    "logPath": ".\\logs\\linkrouter.log",
    "browsers": { "edge": "C:\\...\\msedge.exe", ... },
    "rules": { "ms-teams.exe": "chrome", ... }
  }
  ```
  - `default`: fallback browser key
  - `logPath`: optional, defaults to `%TEMP%\linkrouter_debug.log` (relative to deploy dir)
  - `browsers`: map of browser keys to executable paths
  - `rules` map: `origin_process.exe` → `browser_key`

- **[build-linkrouter.ps1](build-linkrouter.ps1)**: Build & deployment pipeline
  - Compiles AHK to EXE using `Ahk2Exe.exe`
  - Handles file locking by killing/restarting Explorer.exe
  - Accepts `-InstallPath` parameter to define deploy directory (where EXE/config serão copiados e registrados)
  - Registers the EXE from the deploy directory (not the source directory)
  - Atomic swap: builds to `LinkRouter_new.exe`, backs up old, renames new

## Critical Developer Workflows

### Building & Deploying
```powershell
# Normal build + register (kills Explorer 2x!)
.\build-linkrouter.ps1

# Only re-register existing EXE (faster, no rebuild)
.\build-linkrouter.ps1 -RegisterOnly

# Build without registering
.\build-linkrouter.ps1 -NoRegister

# Test with auto-launch after registration
.\build-linkrouter.ps1 -Test
```

**Important**: Script kills Explorer twice by design:
1. Before EXE swap to release file locks
2. After registry changes to refresh shell associations

### Testing
- After registration, test with: `Start-Process "https://example.com"`
- Check routing log: `type $env:TEMP\linkrouter_debug.log`
- Log format: `timestamp | origin=<proc> | decided=<browser> | exe=<path> | launched_pid=<num> | launched_proc=<proc> | url=<url> [| err=<msg>]`

### Registry Structure
```
HKCU\Software\Classes\LinkRouterURL
  (Default) = "LinkRouter URL"
  URL Protocol = ""
  \shell\open\command
    (Default) = "C:\tools\LinkRouter\LinkRouter.exe" "%1"

HKCU\Software\LinkRouter\Capabilities
  ApplicationName = "LinkRouter"
  \URLAssociations
    http = "LinkRouterURL"
    https = "LinkRouterURL"

HKCU\Software\RegisteredApplications
  LinkRouter = "Software\LinkRouter\Capabilities"
```

## Project-Specific Conventions

### AutoHotkey v2 Patterns
- **Single instance enforcement**: `#SingleInstance Force` prevents duplicate handlers
- **Early exits with logging**: Every error path calls `LogLine()` before `ExitApp`
- **Process detection retry loop**: Polls PID for 2 seconds because process startup is async (lines 61-72)
- **Fallback detection**: If PID lookup fails, verify by `ProcessExist(exeName)` (lines 75-84)

### Error Handling Strategy
- Config errors: prefix messages with structured keys (`config_not_found`, `missing_field`)
- Runtime errors: catch blocks always log then exit cleanly
- All errors captured in log with `err=` field for post-mortem analysis

### File Paths
- Config path in source: `$Root\linkrouter.config.json` (used by build script)
- Install path: Configured via `installPath` in config (where EXE runs from)
- Log path: Configured via `logPath` in config, defaults to `%TEMP%\linkrouter_debug.log`
- Log directory is auto-created if it doesn't exist
- Compiler: `C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe`

## Integration Points

### Windows Shell Integration
- Registered as default handler via "Set Default Apps" in Windows Settings
- Windows invokes: `LinkRouter.exe "https://example.com"` when user clicks link
- Must restart Explorer to apply registry changes (COM cache)

### Browser Launch
- Uses `Run()` with quoted paths to handle spaces: `Run('"' exe '" "' url '"')`
- Returns PID immediately but process name resolution requires polling
- No browser-specific flags - passes raw URL to browser's CLI

## Known Gotchas
1. **Explorer restarts kill taskbar state** - users lose pinned app positions briefly
2. **Config changes require restart** - no hot-reload, script exits after each invocation
3. **Process detection race condition** - 2-second polling is empirically determined, may fail on slow systems
4. **No URI scheme normalization** - passes URL exactly as received (no http→https or path decoding)
5. **AHK v2.0 required** - script won't run on AHK v1.x (breaking syntax changes)

## Debugging Tips
- Check log immediately: `Get-Content $env:TEMP\linkrouter_debug.log -Tail 20`
- Verify registry: `reg query "HKCU\Software\Classes\LinkRouterURL\shell\open\command"`
- Test config parsing in isolation: extract `Json_Parse()` and test in REPL
- For "process not found" errors: increase polling timeout in [LinkRouter.ahk](LinkRouter.ahk#L64)
