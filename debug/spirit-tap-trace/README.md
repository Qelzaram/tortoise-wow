# Spirit Tap / Touch of Weakness trace build

This directory exists only on the `debug/spirit-tap-trace` branch.

Goal: reproduce the bug where Spirit Tap procs when Touch of Weakness triggers even though the target survives, without changing normal proc behavior.

## Instrumentation

The build-time patch adds two log records:

- `[TOW_TRACE]` at the Touch of Weakness triggered cast, including aura id, damage spell id, target alive state and HP.
- `[SPIRIT_TAP_TRACE]` from a temporary Spirit Tap AuraScript `OnCheckProc`, including the Spirit Tap DBC `procFlags`, incoming `procFlag`, `procExtra`, proc spell id and victim alive state/HP.

The Spirit Tap trace AuraScript returns `std::nullopt`, so the core continues with its original proc decision.

## Database binding

`spirit_tap_trace.sql` binds ranks 15270, 15335, 15336, 15337 and 15338 to the trace AuraScript. Apply it only to an isolated/debug copy of the world database.

## Windows build

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\debug\spirit-tap-trace\build_windows.ps1
```

The script installs ACE with vcpkg, applies the instrumentation to the working tree, configures an x64 Release build and puts the resulting runtime files in `trace-artifact`.

The GitHub Actions workflow performs the same build and publishes `turtle-wow-spirit-tap-trace-win64` as an artifact.
