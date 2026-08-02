# SkupLink web tests

Web UI tests (`SkupLinkService/web`): `node --test`, syntax, links, DOM/CSS/i18n, and Service в†” Linux parity.

API field contracts, fixtures, and Serviceв†”Tray (.pas) sync live in [`../contracts`](../contracts).

## Layout

```
tests/
  run-web-tests.bat          # STRICT: HTML_ID/LANG_UNUSED/CSS_UNUSED = fail (cd в†’ web/)
  lib/test-utils.js          # shared helpers
tests/web/
  *.test.js / package.json   # UI suite (npm root)
```

`WEB_ROOT` = `SkupLinkService/web` (relative to `tests/lib`).

## How to run

```powershell
cd D:\GIT-HUB\SkupLink\tests
.\run-web-tests.bat
```

Or manually:

```powershell
cd D:\GIT-HUB\SkupLink\tests\web
npm test
```

By package:

```powershell
npm run test:tier0
npm run test:tier1
npm run test:lang
npm run test:dom
npm run test:css
npm run test:sync
```

## Env modes

| Variable | Default | In `run-web-tests.bat` |
|---|---|---|
| `HTML_ID_MODE` | warn | fail |
| `LANG_UNUSED_MODE` | warn | fail |
| `CSS_UNUSED_MODE` | warn | fail |

Soft-run example:

```powershell
$env:LANG_UNUSED_MODE = "warn"
$env:CSS_UNUSED_MODE = "warn"
npm test
```

## Coverage

**Tier 0:** JS/HTML/CSS syntax, local links (css/js/fonts), unique HTML ids, `ru`/`en` key parity + used keys, sync `SkupLinkService/web` в†” `Linux/web`.

**Tier 1:** DOM ids from `app.js`, CSS usedв†’defined (+ unused report), VM unit tests for `SLLang`.
