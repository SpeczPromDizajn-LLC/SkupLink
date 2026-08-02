# SkupLink contract tests

РљРѕРЅС‚СЂР°РєС‚С‹ API Рё СЃРІРµСЂРєР° Delphi-РјРѕРґРµР»РµР№ Service в†” Tray: `node --test`, JSON-С„РёРєСЃС‚СѓСЂС‹ Рё СЂР°Р·Р±РѕСЂ `.pas`.

Web UI С‚РµСЃС‚С‹ вЂ” РІ [`../web`](../web).

## РЎС‚СЂСѓРєС‚СѓСЂР°

```
tests/
  run-contracts-tests.bat    # STRICT: API_CONTRACT_MODE = fail (cd в†’ contracts/)
  lib/test-utils.js          # РѕР±С‰РёРµ С…РµР»РїРµСЂС‹
tests/contracts/
  fixtures/api/              # JSON-С„РёРєСЃС‚СѓСЂС‹ РѕС‚РІРµС‚РѕРІ API
  *.test.js / package.json   # node --test suite
```

## РљР°Рє Р·Р°РїСѓСЃРєР°С‚СЊ

```powershell
cd D:\GIT-HUB\SkupLink\tests
.\run-contracts-tests.bat
```

РР»Рё РІСЂСѓС‡РЅСѓСЋ:

```powershell
cd D:\GIT-HUB\SkupLink\tests\contracts
npm test
```

РџРѕ РїР°РєРµС‚Р°Рј:

```powershell
npm run test:api
npm run test:sync
```

## Р РµР¶РёРјС‹ env

| РџРµСЂРµРјРµРЅРЅР°СЏ | РџРѕ СѓРјРѕР»С‡Р°РЅРёСЋ | Р’ `run-contracts-tests.bat` |
|---|---|---|
| `API_CONTRACT_MODE` | warn | fail |

РџСЂРёРјРµСЂ РјСЏРіРєРѕРіРѕ Р·Р°РїСѓСЃРєР°:

```powershell
$env:API_CONTRACT_MODE = "warn"
npm test
```

## Р§С‚Рѕ РїРѕРєСЂС‹С‚Рѕ

- **api-field-contracts:** С„РёРєСЃС‚СѓСЂС‹ РїРѕРєСЂС‹РІР°СЋС‚ РїРѕР»СЏ, РєРѕС‚РѕСЂС‹Рµ С‡РёС‚Р°РµС‚ `app.js` (`ups` / `history` / `settings` / `tray` / `login` / `discover` / `health`).
- **service-tray-sync:** `HTTP_PORT` Рё `TApiTrayStatus` СЃРѕРІРїР°РґР°СЋС‚ РјРµР¶РґСѓ Service Рё Tray; writers/readers Рё tray-С„РёРєСЃС‚СѓСЂС‹ СЃРѕРіР»Р°СЃРѕРІР°РЅС‹.
