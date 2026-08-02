# SkupLink web tests

РўРµСЃС‚С‹ Web UI (`SkupLinkService/web`): `node --test`, СЃРёРЅС‚Р°РєСЃРёСЃ, СЃСЃС‹Р»РєРё, DOM/CSS/i18n Рё СЃРІРµСЂРєР° Service в†” Linux.

API field contracts, С„РёРєСЃС‚СѓСЂС‹ Рё sync Serviceв†”Tray (.pas) вЂ” РІ [`../contracts`](../contracts).

## РЎС‚СЂСѓРєС‚СѓСЂР°

```
tests/
  run-web-tests.bat          # STRICT: HTML_ID/LANG_UNUSED/CSS_UNUSED = fail (cd в†’ web/)
  lib/test-utils.js          # РѕР±С‰РёРµ С…РµР»РїРµСЂС‹
tests/web/
  *.test.js / package.json   # UI suite (npm root)
```

`WEB_ROOT` = `SkupLinkService/web` (РѕС‚РЅРѕСЃРёС‚РµР»СЊРЅРѕ `tests/lib`).

## РљР°Рє Р·Р°РїСѓСЃРєР°С‚СЊ

```powershell
cd D:\GIT-HUB\SkupLink\tests
.\run-web-tests.bat
```

РР»Рё РІСЂСѓС‡РЅСѓСЋ:

```powershell
cd D:\GIT-HUB\SkupLink\tests\web
npm test
```

РџРѕ РїР°РєРµС‚Р°Рј:

```powershell
npm run test:tier0
npm run test:tier1
npm run test:lang
npm run test:dom
npm run test:css
npm run test:sync
```

## Р РµР¶РёРјС‹ env

| РџРµСЂРµРјРµРЅРЅР°СЏ | РџРѕ СѓРјРѕР»С‡Р°РЅРёСЋ | Р’ `run-web-tests.bat` |
|---|---|---|
| `HTML_ID_MODE` | warn | fail |
| `LANG_UNUSED_MODE` | warn | fail |
| `CSS_UNUSED_MODE` | warn | fail |

РџСЂРёРјРµСЂ РјСЏРіРєРѕРіРѕ Р·Р°РїСѓСЃРєР°:

```powershell
$env:LANG_UNUSED_MODE = "warn"
$env:CSS_UNUSED_MODE = "warn"
npm test
```

## Р§С‚Рѕ РїРѕРєСЂС‹С‚Рѕ

**Tier 0:** СЃРёРЅС‚Р°РєСЃРёСЃ JS/HTML/CSS, Р»РѕРєР°Р»СЊРЅС‹Рµ СЃСЃС‹Р»РєРё (css/js/fonts), СѓРЅРёРєР°Р»СЊРЅС‹Рµ HTML id, parity РєР»СЋС‡РµР№ `ru`/`en` + used keys, sync `SkupLinkService/web` в†” `Linux/web`.

**Tier 1:** DOM ids РёР· `app.js`, CSS usedв†’defined (+ unused report), VM unit-С‚РµСЃС‚С‹ `SLLang`.
