# Тесты Delphi / DUnitX

Node-тесты: UI в `../web`, API/.pas-контракты в `../contracts`. Здесь — консольный DUnitX-проект для чистых Delphi-хелперов (без HTTP / SNMP / Indy / VCL tray).

## Проект

| Файл | Назначение |
|---|---|
| `SkupLinkTests.dpr` / `.dproj` | Консольный runner (Delphi 12 / ProjectVersion 20.3) |
| `TestDetectTopology.pas` | `TUpsSnapshot.DetectTopology` |
| `TestNormalizeSnmpVersion.pas` | `NormalizeSnmpVersion` |

Подключаются только `SkupLinkService\Common.pas` и `uUpsModels.pas`.  
`uPasswordHash` пока не включён (лишние зависимости) — можно добавить отдельным fixture позже.

Проект добавлен в `SkupLink_ProjectGroup.groupproj` для удобства в IDE.  
**Не входит** в групповые цели `Build` / `Clean` / `Make` (только service + tray). Отдельная цель: `SkupLinkTests`.

## Запуск из IDE

1. Открыть `SkupLink_ProjectGroup.groupproj` или `tests\delphi\SkupLinkTests.dproj`.
2. Сделать активным **SkupLinkTests**, конфигурация **Debug**, платформа **Win32** (или **Win64**, если на машине нет DUnitX для Win32).
3. **Run** (F9) — консоль DUnitX.

## Сборка / запуск из командной строки

Из корня репозитория (нужен RAD Studio / `rsvars.bat`):

```bat
tests\run-delphi-tests.bat
```

Или вручную:

```bat
call "%ProgramFiles(x86)%\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d tests\delphi
msbuild SkupLinkTests.dproj /t:Build /p:Config=Debug /p:Platform=Win32
Win32\Debug\SkupLinkTests.exe
```

Если Win32 падает из‑за отсутствующих DCU DUnitX, соберите Win64:

```bat
msbuild SkupLinkTests.dproj /t:Build /p:Config=Debug /p:Platform=Win64
Win64\Debug\SkupLinkTests.exe
```

Опционально NUnit XML:

```bat
SkupLinkTests.exe --xml:test-results.xml
```

## Кандидаты на следующие fixture

| Модуль | Символ | Заметка |
|---|---|---|
| `SkupLinkService/uPasswordHash.pas` | `HashPassword` / `VerifyPassword` | Round-trip; нужен `System.Hash` |
