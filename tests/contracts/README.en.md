# SkupLink contract tests

API contracts and Service в†” Tray Delphi model sync: `node --test`, JSON fixtures, and `.pas` parsing.

Web UI tests live in [`../web`](../web).

## Layout

```
tests/
  run-contracts-tests.bat    # STRICT: API_CONTRACT_MODE = fail (cd в†’ contracts/)
  lib/test-utils.js          # shared helpers
tests/contracts/
  fixtures/api/              # JSON fixtures for API responses
  *.test.js / package.json   # node --test suite
```

## How to run

```powershell
cd D:\GIT-HUB\SkupLink\tests
.\run-contracts-tests.bat
```

Or manually:

```powershell
cd D:\GIT-HUB\SkupLink\tests\contracts
npm test
```

By package:

```powershell
npm run test:api
npm run test:sync
```

## Env modes

| Variable | Default | In `run-contracts-tests.bat` |
|---|---|---|
| `API_CONTRACT_MODE` | warn | fail |

Soft-run example:

```powershell
$env:API_CONTRACT_MODE = "warn"
npm test
```

## Coverage

- **api-field-contracts:** fixtures cover fields read by `app.js` (`ups` / `history` / `settings` / `tray` / `login` / `discover` / `health`).
- **service-tray-sync:** `HTTP_PORT` and `TApiTrayStatus` match between Service and Tray; writers/readers and tray fixtures stay aligned.
