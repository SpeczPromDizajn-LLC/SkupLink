# SkupLink — SNMP UPS Monitor

**Язык:** [Русский](README.md) | [English](README.en.md)

Сервис (Windows / Linux) для опроса SNMP-карт ИБП по **RFC 1628 (UPS-MIB)** с HTTP API и веб-интерфейсом.  
Написан на **Delphi** (Indy SNMP + встроенный HTTP-сервер).

## Возможности

- Опрос ИБП по **SNMPv1 / SNMPv2c** (стандартные OID UPS-MIB)
- Веб-интерфейс: состояние, фазы, АКБ, графики (~1 час истории)
- HTTP JSON API с авторизацией по паролю
- Поиск SNMP-карт в LAN (UDP discovery) — только для карт серии **СКУП** производства [ООО «СпецПромДизайн»](https://spd.net.ru)
- Отложенное выключение ПК при низком заряде АКБ (системный shutdown Windows / Linux)
- Windows: служба + tray-индикатор; Linux: systemd-unit
- Лёгкий фоновый сервис, настройки в JSON

## Быстрый старт

1. Соберите сервис (см. ниже) или возьмите готовый пакет.
2. Положите каталог `web/` рядом с исполняемым файлом.
3. Запустите сервис и откройте `http://127.0.0.1:8847/`.
4. Войдите с паролем по умолчанию: **`admin`** (сразу смените в настройках).

Конфиг (пример): `SkupLinkService/config.example.json`.

| ОС / сборка | Путь к `config.json` |
|---|---|
| Windows Debug | `<текущая директория>\config.json` |
| Windows Release | `%ProgramData%\SkupLink\config.json` |
| Linux | `/etc/skuplink/config.json` |

## Сборка

Требования: **Delphi 11/12** (или совместимая) с пакетами **Indy** и **REST**.

### Windows — сервис

1. Откройте `SkupLinkService/SkupLink.dproj`.
2. Конфигурация **Debug** (консоль) или **Release** (служба), платформа `Win32` / `Win64`.
3. Build → `SkupLink.exe`.

Установка службы (Release):

```bat
SkupLink.exe /install /silent
net start "SkupLink UPS SNMP Agent"
```

### Windows — tray

1. Откройте `SkupLinkTray/SkupLinkTray.dproj`.
2. **Release / Win32** → `SkupLinkTray/Win32/Release/SkupLinkTray.exe`.

Установщик NSIS: `Windows/Setup_SkupLink.nsi`.

### Linux

1. Соберите `SkupLinkService` как **Release / Linux64**.
2. Обновите пакет `Linux/` (бинарник, `web/`, `config.example.json`) — см. `Linux/update.bat` / `install.sh`.
3. На целевой машине:

```bash
cd Linux
sudo bash install.sh
```

## Структура репозитория

```
SkupLinkService/   # сервис (Windows/Linux), web UI, config.example.json
SkupLinkTray/      # Windows tray
Windows/           # NSIS-установщик и bat-хелперы
Linux/             # пакет для systemd
_docs/             # документация и материалы для GitHub
```

Схема API: `_docs/api/api-scheme.txt`.

## Лицензирование

**Исходный код этой версии распространяется под лицензией [GNU GPL v3](LICENSE).**  
Вы можете свободно использовать, изменять и распространять код при условии, что производные работы также остаются под GPL v3.

### Коммерческое использование и брендирование

Если вам нужно:

- использовать программу внутри компании **без** открытия своих доработок;
- изменить название, логотип и веб-интерфейс под свой бренд;
- встроить программу в закрытый коммерческий продукт;

— нужна **отдельная коммерческая лицензия** (договор с правообладателем).  
Свяжитесь для обсуждения условий: **info@spd.net.ru** · [spd.net.ru](https://spd.net.ru)

Правообладатель открытой и коммерческой линии — **ООО «СпецПромДизайн»**.

## Контрибьюторам

Перед отправкой Pull Request прочитайте [CONTRIBUTING.md](CONTRIBUTING.md)  
(включая лицензионное соглашение с контрибьютором — CLA).  
English: [CONTRIBUTING.en.md](CONTRIBUTING.en.md).

## Автор

ООО «СпецПромДизайн»  
© 2026. Открытая версия — GNU GPL v3; коммерческие условия — по отдельному договору.
