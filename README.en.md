# SkupLink — SNMP UPS Monitor

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-lightgrey.svg)](#)
[![Delphi](https://img.shields.io/badge/Delphi-11%2F12-red.svg)](#)

**Language:** [English](README.en.md) | [Русский](README.md)

Windows / Linux service that polls UPS SNMP cards using **RFC 1628 (UPS-MIB)**, with an HTTP API and web UI.  
Built with **Delphi** (Indy SNMP + embedded HTTP server).

## Features

- UPS polling over **SNMPv1 / SNMPv2c** (standard UPS-MIB OIDs)
- Web UI: status, phases, battery, charts (~1 hour of in-memory history)
- HTTP JSON API with password authentication
- LAN SNMP card discovery (UDP) — **SKUP series cards only**, made by [SpecPromDesign LLC](https://spd.net.ru) (ООО «СпецПромДизайн»)
- Delayed PC shutdown on low battery (Windows / Linux system shutdown)
- Windows: service + tray indicator; Linux: systemd unit
- Lightweight background service, JSON configuration

## Quick start

1. Build the service (see below) or use a prepared package.
2. Place the `web/` folder next to the executable.
3. Start the service and open `http://127.0.0.1:8847/`.
4. Sign in with the default password: **`admin`** (change it immediately in Settings).

Config example: `SkupLinkService/config.example.json`.

| OS / build | `config.json` path |
|---|---|
| Windows Debug | `<current directory>\config.json` |
| Windows Release | `%ProgramData%\SkupLink\config.json` |
| Linux | `/etc/skuplink/config.json` |

## Build

Requirements: **Delphi 11/12** (or compatible) with **Indy** and **REST** packages.

### Windows — service

1. Open `SkupLinkService/SkupLink.dproj`.
2. Configuration **Debug** (console) or **Release** (Windows service), platform `Win32` / `Win64`.
3. Build → `SkupLink.exe`.

Install the service (Release):

```bat
SkupLink.exe /install /silent
net start "SkupLink UPS SNMP Agent"
```

### Windows — tray

1. Open `SkupLinkTray/SkupLinkTray.dproj`.
2. **Release / Win32** → `SkupLinkTray/Win32/Release/SkupLinkTray.exe`.

NSIS installer: `Windows/Setup_SkupLink.nsi`.

### Linux

1. Build `SkupLinkService` as **Release / Linux64**.
2. Refresh the `Linux/` package (binary, `web/`, `config.example.json`) — see `Linux/update.bat` / `install.sh`.
3. On the target host:

```bash
cd Linux
sudo bash install.sh
```

## Repository layout

```
SkupLinkService/   # service (Windows/Linux), web UI, config.example.json
SkupLinkTray/      # Windows tray app
Windows/           # NSIS installer and helper scripts
Linux/             # systemd install package
_docs/             # documentation
```

API outline: `_docs/api/api-scheme.txt`.

## Licensing

**Source code of this edition is released under the [GNU GPL v3](LICENSE).**  
You may use, modify, and redistribute it provided that derivative works remain under GPL v3.

### Commercial use and branding

If you need to:

- use the software inside your company **without** publishing your modifications;
- rebrand the name, logo, and web UI;
- embed the software in a closed commercial product;

— you need a **separate commercial license** (agreement with the copyright holder).  
Contact: **info@spd.net.ru** · [spd.net.ru](https://spd.net.ru)

Copyright holder of the open-source and commercial lines: **SpecPromDesign LLC** (ООО «СпецПромДизайн»).

## Contributing

Please read [CONTRIBUTING.en.md](CONTRIBUTING.en.md) before opening a Pull Request  
(including the Contributor License Agreement — CLA).  
Russian version: [CONTRIBUTING.md](CONTRIBUTING.md).

## Author

SpecPromDesign LLC (ООО «СпецПромДизайн»)  
© 2026. Open-source edition — GNU GPL v3; commercial terms — by separate agreement.
