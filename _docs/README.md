# SkupLink

Сервис опроса ИБП по **SNMPv1/v2c** (RFC 1628 / NUT `ietf`), **HTTP JSON API** и **веб-интерфейс**.

Режимы сборки:

| Конфиг | Windows | Linux |
|---|---|---|
| **Debug** | консольное приложение | консольное приложение |
| **Release** | служба (`TService`) | демон (systemd `Type=simple`) |

ОС выбирается автоматически через `{$IFDEF MSWINDOWS}` / Linux. Параметров командной строки для режима запуска нет.

## Возможности

1. Периодический SNMP GET к карте ИБП.
2. Чтение стандартных OID UPS-MIB (ident, input/output phases, battery, load, charge %).
3. Автоопределение топологии:
   - `single_phase` — 1 вход / 1 выход
   - `three_phase_in_out` — 3 входа / 3 выхода
   - `three_phase_in_single_out` — 3 входа / 1 выход
4. HTTP API + веб-UI на порту `8847`.
5. Авторизация по паролю, смена пароля.
6. Настройки SNMP и порога выключения ПК по остаточной ёмкости АКБ.
7. Поиск SNMP-карт в LAN (UDP broadcast `'I'` на порт `51847` по всем подсетям NIC/VPN).
8. Графики основных параметров (история в памяти ~1 час).
9. Windows tray (`SkupLinkTray`) — индикатор состояния ИБП в области уведомлений.

## Хранение настроек

Рекомендуемый и реализованный вариант — **JSON-файл**:

| ОС / сборка | Путь |
|---|---|
| Windows Debug | `<текущая директория>\config.json` |
| Windows Release | `%ProgramData%\SkupLink\config.json` |
| Linux | `/etc/skuplink/config.json` |
| Fallback (Release) | `<каталог exe>\config.json` |

Почему так:

- один формат для Windows и Linux;
- удобно менять через HTTP POST без отдельного UI;
- проще бэкапить и выкатывать через конфигурацию;
- registry / INI хуже переносятся между платформами.

Пример: `SkupLinkService/config.example.json` (для Linux-пакета также `Linux/config.example.json`).

```json
{
  "snmp_host": "192.168.1.10",
  "snmp_community": "public",
  "snmp_version": "1",
  "shutdown_battery_percent": 15,
  "shutdown_delay_seconds": 120,
  "password_hash": "pbkdf2-sha256$<iterations>$<salt_hex>$<dk_hex>"
}
```

Пароль по умолчанию: `admin` (смените в веб-UI). Хэш — PBKDF2-HMAC-SHA256 со случайной солью.

Веб-UI: каталог `web/` рядом с exe (DEBUG — текущая директория). Откройте `http://127.0.0.1:8847/`.

Все константы (HTTP-порт, интервал опроса, SNMP defaults, OID, пути config) — в `SkupLinkService/Common.pas`.

## HTTP API

Схема эндпоинтов: [`api/api-scheme.txt`](api/api-scheme.txt).

Кратко:

| Метод | URL | Описание |
|---|---|---|
| `GET` | `/` | Web UI |
| `POST` | `/api/login` | Получить token |
| `GET` | `/api/ups` | Снимок SNMP (нужен token) |
| `GET` | `/api/history` | История для графиков |
| `GET`/`POST` | `/api/settings` | Настройки |
| `POST` | `/api/password` | Смена пароля |
| `GET` | `/api/tray` | Статус для tray (без auth) |
| `GET` | `/health` | Liveness (без auth) |

```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:8847/api/login \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"admin\"}" | jq -r .token)

curl -X POST http://127.0.0.1:8847/api/settings \
  -H "Content-Type: application/json" \
  -H "X-Auth-Token: $TOKEN" \
  -d "{\"snmp_host\":\"10.0.0.50\",\"snmp_community\":\"public\",\"shutdown_battery_percent\":20}"
```

## OID (RFC 1628)

База: `1.3.6.1.2.1.33.1`

| Поле | OID |
|---|---|
| upsIdentManufacturer | `.1.1.0` |
| upsIdentModel | `.1.2.0` |
| upsIdentUPSSoftwareVersion | `.1.3.0` |
| upsIdentName | `.1.5.0` |
| upsIdentAttachedDevices | `.1.6.0` |
| upsBatteryStatus | `.2.1.0` |
| upsSecondsOnBattery | `.2.2.0` |
| upsEstimatedMinutesRemaining | `.2.3.0` |
| upsEstimatedChargeRemaining | `.2.4.0` (%) |
| upsBatteryVoltage | `.2.5.0` (×0.1 V) |
| upsInputNumLines | `.3.2.0` |
| upsInputFrequency / Voltage | `.3.3.1.2.n` / `.3.3.1.3.n` |
| upsOutputFrequency | `.4.2.0` (×0.1 Hz) |
| upsOutputNumLines | `.4.3.0` |
| upsOutputVoltage / Power / PercentLoad | `.4.4.1.2.n` / `.4.4.1.4.n` / `.4.4.1.5.n` |

## Сборка

Требования: **Delphi 11/12** (или совместимая) с **Indy** и **REST**.

### Windows (сервис)

1. Откройте `SkupLinkService\SkupLink.dproj`.
2. Конфигурация **Debug** или **Release**, платформа `Win32` / `Win64`.
3. Build → `SkupLinkService\SkupLink.exe` (или `Win32\Release` в зависимости от настроек вывода).

### Windows (tray)

1. Откройте `SkupLinkTray\SkupLinkTray.dproj`.
2. **Release / Win32**, Build → `SkupLinkTray\Win32\Release\SkupLinkTray.exe`.

### Linux

1. Откройте `SkupLinkService\SkupLink.dproj`.
2. **Release / Linux64**, Build → `SkupLinkService\Linux64\Release\SkupLink`.
3. Скопируйте в пакет установки:

```
Linux/
  SkupLink              ← бинарник
  web/                  ← из SkupLinkService/web
  config.example.json
  skuplink.service
  install.sh
```

Зависимости: `IndySystem`, `IndyCore`, `IndyProtocols`, `RESTComponents`, `Vcl.SvcMgr` (только Windows Release).

## Запуск

### Windows

Debug — просто запуск exe из IDE.

Release:

```bat
SkupLink.exe /install /silent
net start "SkupLink UPS SNMP Agent"
SkupLinkTray.exe
```

Tray опрашивает `GET /api/tray` (без auth): иконка offline / сеть / АКБ, tooltip с %, двойной клик — Web UI.

Установщик: `Windows\Setup_SkupLink.nsi` (копирует сервис, `web/`, tray, автозапуск tray).

### Linux

Соберите пакет в `Linux/` (см. выше) и на целевой машине:

```bash
cd Linux
sudo bash install.sh
```

Скрипт ставит бинарник и `web/` в `/usr/local/bin/`, конфиг в `/etc/skuplink/` (если ещё нет), unit systemd и делает `enable --now skuplink`.

Web UI: `http://127.0.0.1:8847/`.

## Структура проекта

```
SkupLinkService/       # сервис (Windows/Linux)
  SkupLink.dpr/.dproj
  Common.pas           # константы
  web/                 # веб-UI
  config.example.json
  …                    # модули сервиса
SkupLinkTray/          # Windows tray helper
Linux/                 # пакет установки Linux
  install.sh
  skuplink.service
  config.example.json
  SkupLink             # положить после сборки
  web/                 # положить после сборки
_docs/
  README.md
  api/api-scheme.txt
```

## Пример ответа `/api/ups`

```json
{
  "ident": {
    "manufacturer": "Vendor",
    "model": "UPS-3000",
    "software_version": "1.2.3",
    "name": "ups-rack-1",
    "attached_devices": "server-a"
  },
  "topology": "three_phase_in_single_out",
  "input_phase_count": 3,
  "output_phase_count": 1,
  "input": {
    "phases": [
      { "index": 1, "voltage": 230, "frequency": 50 },
      { "index": 2, "voltage": 229, "frequency": 50 },
      { "index": 3, "voltage": 231, "frequency": 50 }
    ]
  },
  "output": {
    "frequency": 50,
    "phases": [
      { "index": 1, "voltage": 230, "frequency": 50, "percent_load": 42, "power_watts": 900 }
    ],
    "total_percent_load": 42,
    "total_power_watts": 900
  },
  "battery": {
    "status": "battery_normal",
    "status_code": 2,
    "voltage": 54.6,
    "estimated_minutes_remaining": 35,
    "estimated_seconds_remaining": 2100,
    "seconds_on_battery": 0
  },
  "snmp_connected": true
}
```
