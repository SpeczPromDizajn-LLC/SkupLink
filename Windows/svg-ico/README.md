# svg-to-ico

Универсальный конвертер **SVG → ICO** (Node.js).

Используется для сборки иконки установщика SkupLink (`../SkupLink.ico`) из веб-favicon.

## Требования

- [Node.js](https://nodejs.org/) 18+
- npm

## Установка

```bat
cd /d D:\PROJECTS\Soft\Programs\SkupLink\trunk\Windows\svg-ico
npm install
```

## Использование

```bat
node svg-to-ico.mjs <input.svg> <output.ico> [--sizes 16,24,32,48,64,128,256]
```

или через npm:

```bat
npm run svg-to-ico -- <input.svg> <output.ico> [--sizes ...]
```

### Параметры

| Параметр | Описание |
|---|---|
| `input.svg` | Исходный SVG-файл |
| `output.ico` | Путь к результирующему `.ico` |
| `--sizes` | Список размеров в пикселях через запятую (по умолчанию: `16,24,32,48,64,128,256`) |
| `-h`, `--help` | Справка |

### Примеры

Собрать иконку установщика SkupLink из favicon:

```bat
node svg-to-ico.mjs ..\..\SkupLinkService\web\favicon.svg ..\SkupLink.ico
```

Произвольный SVG с выбранными размерами:

```bat
node svg-to-ico.mjs logo.svg app.ico --sizes 16,32,48,256
```

## Как это работает

1. **sharp** растеризует SVG в PNG для каждого размера (квадрат, `fit: contain`, прозрачный фон).
2. **png-to-ico** упаковывает набор PNG в один multi-size `.ico`.

Скрипт не привязан к геометрии конкретного favicon — подходит для любого SVG.

## Зависимости

- `sharp` — растеризация SVG
- `png-to-ico` — сборка ICO

Каталог `node_modules/` в репозиторий не коммитится.
