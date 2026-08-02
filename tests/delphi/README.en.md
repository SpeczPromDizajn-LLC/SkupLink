# Delphi / DUnitX tests

Node tests: UI in `../web`, API/.pas contracts in `../contracts`. This folder is a console DUnitX project for pure Delphi helpers (no HTTP / SNMP / Indy / VCL tray).

## Project

| File | Purpose |
|---|---|
| `SkupLinkTests.dpr` / `.dproj` | Console runner (Delphi 12 / ProjectVersion 20.3) |
| `TestDetectTopology.pas` | `TUpsSnapshot.DetectTopology` |
| `TestNormalizeSnmpVersion.pas` | `NormalizeSnmpVersion` |

Only `SkupLinkService\Common.pas` and `uUpsModels.pas` are linked.  
`uPasswordHash` is not included yet (extra deps) — add a separate fixture later if needed.

The project is in `SkupLink_ProjectGroup.groupproj` for IDE convenience.  
It is **not** part of the group `Build` / `Clean` / `Make` targets (those stay service + tray only). Dedicated target: `SkupLinkTests`.

## Run from the IDE

1. Open `SkupLink_ProjectGroup.groupproj` or `tests\delphi\SkupLinkTests.dproj`.
2. Make **SkupLinkTests** active, **Debug** config, **Win32** platform (or **Win64** if DUnitX DCUs are missing for Win32).
3. **Run** (F9) — DUnitX console output.

## Build / run from the command line

From the repo root (requires RAD Studio / `rsvars.bat`):

```bat
tests\run-delphi-tests.bat
```

Or manually:

```bat
call "%ProgramFiles(x86)%\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d tests\delphi
msbuild SkupLinkTests.dproj /t:Build /p:Config=Debug /p:Platform=Win32
Win32\Debug\SkupLinkTests.exe
```

If Win32 fails because DUnitX DCUs are missing, build Win64:

```bat
msbuild SkupLinkTests.dproj /t:Build /p:Config=Debug /p:Platform=Win64
Win64\Debug\SkupLinkTests.exe
```

Optional NUnit XML:

```bat
SkupLinkTests.exe --xml:test-results.xml
```

## Candidates for later fixtures

| Unit | Symbol | Note |
|---|---|---|
| `SkupLinkService/uPasswordHash.pas` | `HashPassword` / `VerifyPassword` | Round-trip; needs `System.Hash` |
