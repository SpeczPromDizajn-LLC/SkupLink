# Web UI (каталог `web/`)

Файлы: `index.html`, `app.css`, `app.js`, `lang.js`. Раздаются Indy HTTP с корня `/`.

## Старт и сессия

- Токен: `localStorage.skuplink_token` (заголовок `X-Auth-Token`).
- В `<head>` до отрисовки: класс `sl-session` / `sl-guest`, sync XHR `/api/ups` и `/api/settings`.
- `__SL_BOOT.live === true` только если `/api/ups` реально ответил. Кэш `skuplink_ups_cache` — только для последних значений, не для статуса «SNMP OK».
- Классы: `sl-data-ready` — показать обзор после подстановки снимка; без него `#panel-overview` скрыт (`visibility`), чтобы не мигали пустые поля.

## Статусы связи

- `SNMP OK` — API доступен и `snmp_connected`.
- `нет SNMP` — API доступен, опрос SNMP неуспешен.
- `нет связи` — API/сервер недоступен (в т.ч. при открытой вкладке после остановки бэкенда).

## Опрос

- Интервал UI: 5 с (`POLL_MS` / `CHART_POLL_MS` в `app.js`).
- Вкладка «Обзор»: `/api/ups`.
- Вкладка «Графики»: `/api/ups` (число фаз) + `/api/history`; при смене числа фаз графики перерисовываются сразу.
- Вкладка «Настройки»: фоновый опрос отключён.
- Кнопка «Найти» → `POST /api/discover` (UDP `'I'` на broadcast всех адаптеров, ~3 с); клик по устройству подставляет IP в `snmp_host`.

## Графики и фазы

- История: `input_voltages[]`, `output_voltages[]`, `load_percents[]`, `battery_voltage`.
- Число линий на графике = текущее число фаз из снимка UPS (не max по всей истории): вход отдельно, выход/нагрузка отдельно (схема 3ф→1ф: 3 линии на входе, 1 на выходе).

## Локализация

- Все строки UI: `lang.js` → `SLLang.dictionaries`, `SLLang.t(key)`, `SLLang.apply()` / `setLang(code)`.
- Языки: `ru`, `en`. Переключатель RU/EN на экране логина (`.lang-switch`).
- В HTML: `data-i18n`, `data-i18n-placeholder`, `data-i18n-aria`.
- Язык: `localStorage.skuplink_lang` (по умолчанию `ru`). Новый язык — новый ключ в `dictionaries`.
- Динамические поля (`#ups-ident`, статусы) без `data-i18n`, только через `t()` в `app.js`.
