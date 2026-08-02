const assert = require('node:assert/strict');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const {
  WEB_ROOT,
  listFilesByExtensions,
  toWebRelative,
  readText,
  envMode
} = require('./test-utils');

const LANG_FILE = path.join(WEB_ROOT, 'lang.js');

function extractBalanced(source, openBracePos)
{
  let depth = 0;
  let inSingle = false;
  let inDouble = false;
  let escaped = false;

  for (let i = openBracePos; i < source.length; i++)
  {
    const ch = source[i];

    if (inSingle)
    {
      if (!escaped && ch === '\'')
        inSingle = false;
      escaped = (!escaped && ch === '\\');
      continue;
    }

    if (inDouble)
    {
      if (!escaped && ch === '"')
        inDouble = false;
      escaped = (!escaped && ch === '\\');
      continue;
    }

    if (ch === '\'')
    {
      inSingle = true;
      escaped = false;
      continue;
    }

    if (ch === '"')
    {
      inDouble = true;
      escaped = false;
      continue;
    }

    if (ch === '{')
      depth++;
    else if (ch === '}')
    {
      depth--;
      if (depth === 0)
        return source.slice(openBracePos, i + 1);
    }
  }

  throw new Error('Unbalanced braces while parsing dictionaries');
}

function parseStringKeys(objectLiteral)
{
  const keys = new Set();
  const keyRe = /(?:^|[,{\s])([A-Za-z_][\w]*)\s*:/g;
  let match = keyRe.exec(objectLiteral);

  while (match)
  {
    keys.add(match[1]);
    match = keyRe.exec(objectLiteral);
  }

  return keys;
}

function loadDictionaries()
{
  const source = readText(LANG_FILE);
  const startMatch = /const\s+dictionaries\s*=\s*\{/.exec(source);
  assert.ok(startMatch, 'dictionaries declaration not found in lang.js');

  const openPos = startMatch.index + startMatch[0].length - 1;
  const block = extractBalanced(source, openPos);
  const result = {};

  const langRe = /\b(ru|en)\s*:\s*\{/g;
  let match = langRe.exec(block);

  while (match)
  {
    const lang = match[1];
    const langOpen = match.index + match[0].length - 1;
    const langBlock = extractBalanced(block, langOpen);
    result[lang] = parseStringKeys(langBlock);
    match = langRe.exec(block);
  }

  assert.ok(result.ru, 'ru dictionary missing');
  assert.ok(result.en, 'en dictionary missing');

  return result;
}

function collectUsedKeys(dicts)
{
  const used = new Set();
  const dynamic = [];
  const htmlFiles = listFilesByExtensions(['.html']);
  const jsFiles = listFilesByExtensions(['.js']);

  for (const filePath of htmlFiles)
  {
    const source = readText(filePath);
    const attrRe = /\bdata-i18n(?:-placeholder|-aria)?\s*=\s*(['"])([^'"]+)\1/gi;
    let match = attrRe.exec(source);

    while (match)
    {
      used.add(match[2]);
      match = attrRe.exec(source);
    }
  }

  for (const filePath of jsFiles)
  {
    const source = readText(filePath);
    const isLang = path.basename(filePath) === 'lang.js';

    const literalRe = /\bt\(\s*(['"])([A-Za-z_][\w]*)\1/g;
    let match = literalRe.exec(source);

    while (match)
    {
      used.add(match[2]);
      match = literalRe.exec(source);
    }

    // topology/battery maps: unknown: "topology_unknown"
    const mapValueRe = /\b([A-Za-z_][\w]*)\s*:\s*(['"])([A-Za-z_][\w]*)\2/g;
    let mapMatch = mapValueRe.exec(source);
    while (mapMatch)
    {
      if (/^(topology_|battery_|phase_)/.test(mapMatch[3]))
        used.add(mapMatch[3]);
      mapMatch = mapValueRe.exec(source);
    }

    const arrayKeyRe = /\[\s*(['"])(phase_[rst])\1\s*,\s*(['"])(phase_[rst])\3\s*,\s*(['"])(phase_[rst])\5\s*\]/g;
    let arrMatch = arrayKeyRe.exec(source);
    while (arrMatch)
    {
      used.add(arrMatch[2]);
      used.add(arrMatch[4]);
      used.add(arrMatch[6]);
      arrMatch = arrayKeyRe.exec(source);
    }

    if (!isLang)
    {
      const anyT = /\bt\(\s*([^)'"][^)]*)\)/g;
      let anyMatch = anyT.exec(source);
      while (anyMatch)
      {
        const arg = anyMatch[1].trim();
        if (!/^['"]/.test(arg))
          dynamic.push(`${toWebRelative(filePath)} -> t(${arg})`);
        anyMatch = anyT.exec(source);
      }
    }
  }

  // Placeholders like {unit_hz} inside dictionary strings count as used keys.
  if (dicts)
  {
    const source = readText(LANG_FILE);
    const placeholderRe = /\{([A-Za-z_][\w]*)\}/g;
    let ph = placeholderRe.exec(source);
    while (ph)
    {
      if (dicts.ru.has(ph[1]))
        used.add(ph[1]);
      ph = placeholderRe.exec(source);
    }
  }

  return { used, dynamic };
}

test('lang.js loads and exports SLLang', () => {
  const source = readText(LANG_FILE);
  const store = new Map();
  const sandbox = {
    localStorage: {
      getItem(key)
      {
        return store.has(key) ? store.get(key) : null;
      },
      setItem(key, value)
      {
        store.set(key, String(value));
      }
    },
    document: {
      documentElement: { lang: '' },
      title: '',
      querySelectorAll()
      {
        return [];
      }
    }
  };
  sandbox.window = sandbox;
  vm.runInNewContext(source, sandbox, { filename: 'lang.js' });
  assert.equal(typeof sandbox.SLLang.t, 'function');
  assert.equal(typeof sandbox.SLLang.apply, 'function');
  assert.equal(typeof sandbox.SLLang.setLang, 'function');
});

test('ru and en dictionaries share the same key set', () => {
  const dicts = loadDictionaries();
  const ru = [...dicts.ru].sort();
  const en = [...dicts.en].sort();

  const missingInEn = ru.filter((k) => !dicts.en.has(k));
  const missingInRu = en.filter((k) => !dicts.ru.has(k));

  assert.equal(
    missingInEn.length + missingInRu.length,
    0,
    `Key parity mismatch.\nMissing in en: ${missingInEn.join(', ') || '-'}\nMissing in ru: ${missingInRu.join(', ') || '-'}`
  );
});

test('All used i18n keys exist in both dictionaries', () => {
  const dicts = loadDictionaries();
  const { used, dynamic } = collectUsedKeys(dicts);

  if (dynamic.length > 0)
    console.warn(`Dynamic t() usages (review):\n${dynamic.join('\n')}`);

  const missing = [];

  for (const key of [...used].sort())
  {
    if (!dicts.ru.has(key))
      missing.push(`ru missing: ${key}`);
    if (!dicts.en.has(key))
      missing.push(`en missing: ${key}`);
  }

  assert.equal(missing.length, 0, `Used keys missing in lang.js:\n${missing.join('\n')}`);
});

test('All data-i18n attributes are non-empty quoted keys', () => {
  const htmlFiles = listFilesByExtensions(['.html']);
  const invalid = [];
  const attrRe = /\b(data-i18n(?:-placeholder|-aria)?)\s*=\s*(?:(['"])\s*([^'"]*?)\s*\2|([^\s>]+))/gi;

  for (const filePath of htmlFiles)
  {
    const source = readText(filePath);
    let match = attrRe.exec(source);

    while (match)
    {
      const attrName = match[1];
      const quote = match[2];
      const quoted = (match[3] || '').trim();
      const unquoted = (match[4] || '').trim();

      if (quote == null)
        invalid.push(`${toWebRelative(filePath)} -> ${attrName}=${unquoted} (must be quoted)`);
      else if (!/^[A-Za-z_][\w]*$/.test(quoted))
        invalid.push(`${toWebRelative(filePath)} -> ${attrName}="${quoted}"`);

      match = attrRe.exec(source);
    }
  }

  assert.equal(invalid.length, 0, `Invalid i18n attributes:\n${invalid.join('\n')}`);
});

test('Unused lang keys are reported (or fail in strict mode)', () => {
  const dicts = loadDictionaries();
  const { used } = collectUsedKeys(dicts);
  const unused = [...dicts.ru].filter((k) => !used.has(k)).sort();

  if (unused.length === 0)
    return;

  const mode = envMode('LANG_UNUSED_MODE', 'warn');
  const message = `Unused lang keys:\n${unused.join('\n')}`;

  if (mode === 'fail')
    assert.equal(unused.length, 0, message);
  else
    console.warn(message);
});
