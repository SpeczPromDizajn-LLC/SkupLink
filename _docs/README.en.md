# SkupLink

Service that polls UPS devices over **SNMPv1/v2c** (RFC 1628 / NUT `ietf`), with an **HTTP JSON API** and a **web UI**.

Build modes:

| Config | Windows | Linux |
|---|---|---|
| **Debug** | console application | console application |
| **Release** | service (`TService`) | daemon (systemd `Type=simple`) |

The OS is selected automatically via `{$IFDEF MSWINDOWS}` / Linux. There are no command-line switches for the run mode.

## Features

1. Periodic SNMP GET to the UPS card.
2. Reading standard UPS-MIB OIDs (ident, input/output phases, battery, load, charge %).
3. Automatic topology detection:
   - `single_phase` — 1 input / 1 output
   - `three_phase_in_out` — 3 inputs / 3 outputs
   - `three_phase_in_single_out` — 3 inputs / 1 output
4. HTTP API + web UI on port `8847`.
5. Password authentication and password change.
6. SNMP settings and PC shutdown threshold by remaining battery capacity.
7. SNMP card discovery in the LAN (UDP broadcast `'I'` on port `51847` across all NIC/VPN subnets).
8. Charts of key parameters (in-memory history ~1 hour).
9. Windows tray (`SkupLinkTray`) — UPS status indicator in the notification area.

## Settings storage

The recommended and implemented approach is a **JSON file**:

| OS / build | Path |
|---|---|
| Windows Debug | `<current directory>\config.json` |
| Windows Release | `%ProgramData%\SkupLink\config.json` |
| Linux | `/etc/skuplink/config.json` |
| Fallback (Release) | `<exe directory>\config.json` |

Why this way:

- one format for Windows and Linux;
- easy to change via HTTP POST without a separate UI;
- simpler to back up and deploy via configuration;
- registry / INI do not travel well across platforms.

Example: `SkupLinkService/config.example.json` (for the Linux package also `Linux/config.example.json`).

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

Default password: `admin` (change it in the web UI). The hash is PBKDF2-HMAC-SHA256 with a random salt.

Web UI: the `web/` directory next to the exe (DEBUG — current directory). Open `http://127.0.0.1:8847/`.

All constants (HTTP port, poll interval, SNMP defaults, OIDs, config paths) are in `SkupLinkService/Common.pas`.

## HTTP API

Endpoint scheme: [`api/api-scheme-en.txt`](api/api-scheme-en.txt) (Russian: [`api/api-scheme.txt`](api/api-scheme.txt)).

Summary:

| Method | URL | Description |
|---|---|---|
| `GET` | `/` | Web UI |
| `POST` | `/api/login` | Obtain token |
| `GET` | `/api/ups` | SNMP snapshot (token required) |
| `GET` | `/api/history` | History for charts |
| `GET`/`POST` | `/api/settings` | Settings |
| `POST` | `/api/password` | Change password |
| `GET` | `/api/tray` | Status for tray (no auth) |
| `GET` | `/health` | Liveness (no auth) |

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

Base: `1.3.6.1.2.1.33.1`

| Field | OID |
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

## Build

Requirements: **Delphi 11/12** (or compatible) with **Indy** and **REST**.

### Windows (service)

1. Open `SkupLinkService\SkupLink.dproj`.
2. Configuration **Debug** or **Release**, platform `Win32` / `Win64`.
3. Build → `SkupLinkService\SkupLink.exe` (or `Win32\Release` depending on output settings).

### Windows (tray)

1. Open `SkupLinkTray\SkupLinkTray.dproj`.
2. **Release / Win32**, Build → `SkupLinkTray\Win32\Release\SkupLinkTray.exe`.

### Linux

1. Open `SkupLinkService\SkupLink.dproj`.
2. **Release / Linux64**, Build → `SkupLinkService\Linux64\Release\SkupLink`.
3. Copy into the install package:

```
Linux/
  SkupLink              ← binary
  web/                  ← from SkupLinkService/web
  config.example.json
  skuplink.service
  install.sh
```

Dependencies: `IndySystem`, `IndyCore`, `IndyProtocols`, `RESTComponents`, `Vcl.SvcMgr` (Windows Release only).

## Running

### Windows

Debug — just run the exe from the IDE.

Release:

```bat
SkupLink.exe /install /silent
net start "SkupLink UPS SNMP Agent"
SkupLinkTray.exe
```

The tray polls `GET /api/tray` (no auth): icon offline / on-mains / on-battery, tooltip with %, double-click opens the Web UI.

Installer: `Windows\Setup_SkupLink.nsi` (copies the service, `web/`, tray, tray autostart).

### Linux

Assemble the package under `Linux/` (see above) and on the target host:

```bash
cd Linux
sudo bash install.sh
```

The script installs the binary and `web/` to `/usr/local/bin/`, config to `/etc/skuplink/` (if not already present), the systemd unit, and runs `enable --now skuplink`.

Web UI: `http://127.0.0.1:8847/`.

## Project layout

```
SkupLinkService/       # service (Windows/Linux)
  SkupLink.dpr/.dproj
  Common.pas           # constants
  web/                 # web UI
  config.example.json
  …                    # service modules
SkupLinkTray/          # Windows tray helper
Linux/                 # Linux install package
  install.sh
  skuplink.service
  config.example.json
  SkupLink             # place after build
  web/                 # place after build
_docs/
  README.md
  api/api-scheme.txt
```

## Example `/api/ups` response

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
