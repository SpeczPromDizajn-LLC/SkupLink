# Web UI (`web/` directory)

Files: `index.html`, `app.css`, `app.js`, `lang.js`. Served by Indy HTTP from root `/`.

## Startup and session

- Token: `localStorage.skuplink_token` (header `X-Auth-Token`).
- In `<head>` before paint: class `sl-session` / `sl-guest`, sync XHR to `/api/ups` and `/api/settings`.
- `__SL_BOOT.live === true` only if `/api/ups` actually responded. Cache `skuplink_ups_cache` is for last values only, not for an “SNMP OK” status.
- Classes: `sl-data-ready` — show the overview after the snapshot is applied; without it `#panel-overview` is hidden (`visibility`) so empty fields do not flash.

## Connection statuses

- `SNMP OK` — API reachable and `snmp_connected`.
- `нет SNMP` — API reachable, SNMP poll failed.
- `нет связи` — API/server unreachable (including an open tab after the backend is stopped).

## Polling

- UI interval: 5 s (`POLL_MS` / `CHART_POLL_MS` in `app.js`).
- Overview tab: `/api/ups`.
- Charts tab: `/api/ups` (phase counts) + `/api/history`; when the phase count changes, charts redraw immediately.
- Settings tab: background polling is disabled.
- “Find” button → `POST /api/discover` (UDP `'I'` to broadcast of all adapters, ~3 s); clicking a device fills `snmp_host` with its IP.

## Charts and phases

- History: `input_voltages[]`, `output_voltages[]`, `load_percents[]`, `battery_voltage`.
- Number of series on a chart = current phase count from the UPS snapshot (not the max across history): input separately, output/load separately (3φ→1φ scheme: 3 input lines, 1 output line).

## Localization

- All UI strings: `lang.js` → `SLLang.dictionaries`, `SLLang.t(key)`, `SLLang.apply()` / `setLang(code)`.
- Languages: `ru`, `en`. RU/EN switch on the login screen (`.lang-switch`).
- In HTML: `data-i18n`, `data-i18n-placeholder`, `data-i18n-aria`.
- Language: `localStorage.skuplink_lang` (default `ru`). A new language means a new key in `dictionaries`.
- Dynamic fields (`#ups-ident`, statuses) have no `data-i18n`; they use `t()` in `app.js` only.
