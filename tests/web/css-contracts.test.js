const assert = require('node:assert/strict');
const test = require('node:test');

const {
  listFilesByExtensions,
  toWebRelative,
  readText,
  envMode
} = require('./test-utils');

function collectDefinedClasses()
{
  const defined = new Map();
  const cssFiles = listFilesByExtensions(['.css']);

  for (const filePath of cssFiles)
  {
    const rel = toWebRelative(filePath);
    const source = readText(filePath)
      .replace(/\/\*[\s\S]*?\*\//g, '')
      .replace(/url\(\s*(['"]?).*?\1\s*\)/gi, 'url()')
      .replace(/@font-face\s*\{[\s\S]*?\}/gi, '');

    const classRe = /\.([A-Za-z_][\w-]*)/g;
    let match = classRe.exec(source);

    while (match)
    {
      const name = match[1];
      if (!defined.has(name))
        defined.set(name, new Set());
      defined.get(name).add(rel);
      match = classRe.exec(source);
    }
  }

  return defined;
}

function collectUsedClasses()
{
  const used = new Map();
  const htmlFiles = listFilesByExtensions(['.html']);
  const jsFiles = listFilesByExtensions(['.js']);

  function add(name, where)
  {
    if (!used.has(name))
      used.set(name, new Set());
    used.get(name).add(where);
  }

  for (const filePath of htmlFiles)
  {
    const rel = toWebRelative(filePath);
    const source = readText(filePath);
    const classAttrRe = /\bclass\s*=\s*(['"])(.*?)\1/gi;
    let match = classAttrRe.exec(source);

    while (match)
    {
      for (const token of match[2].split(/\s+/))
      {
        if (token)
          add(token, rel);
      }
      match = classAttrRe.exec(source);
    }
  }

  for (const filePath of jsFiles)
  {
    const rel = toWebRelative(filePath);
    const source = readText(filePath);

    const classNameRe = /\.className\s*=\s*(['"])(.*?)\1/g;
    let match = classNameRe.exec(source);
    while (match)
    {
      for (const token of match[2].split(/\s+/))
      {
        if (token)
          add(token, rel);
      }
      match = classNameRe.exec(source);
    }

    const classListRe = /classList\.(?:add|remove|toggle)\(\s*(['"])([^'"]+)\1/g;
    let cl = classListRe.exec(source);
    while (cl)
    {
      add(cl[2], rel);
      cl = classListRe.exec(source);
    }

    // class="..." inside template/string HTML builders
    const htmlClassRe = /\bclass\s*=\s*(['"])(.*?)\1/gi;
    let hc = htmlClassRe.exec(source);
    while (hc)
    {
      for (const token of hc[2].split(/\s+/))
      {
        if (token)
          add(token, rel);
      }
      hc = htmlClassRe.exec(source);
    }

    // Multi-class UI literals assigned via variables: "pill pill-ok", "form-msg err"
    const uiMultiClassRe = /(['"])((?:pill|btn|form-msg)(?:\s+[a-z_][\w-]*)+)\1/g;
    let ll = uiMultiClassRe.exec(source);
    while (ll)
    {
      for (const token of ll[2].split(/\s+/))
      {
        if (token)
          add(token, rel);
      }
      ll = uiMultiClassRe.exec(source);
    }
  }

  return used;
}

test('CSS contracts: classes used in HTML/JS are defined in CSS', () => {
  const defined = collectDefinedClasses();
  const used = collectUsedClasses();
  const missing = [];

  // Runtime-only / state classes that may be toggled without a dedicated rule block
  // are still expected to appear in CSS; no allowlist unless needed.
  for (const [className, places] of used.entries())
  {
    if (!defined.has(className))
      missing.push(`.${className} -> used in: ${[...places].sort().join(', ')}`);
  }

  assert.equal(missing.length, 0, `Missing CSS class definitions:\n${missing.join('\n')}`);
});

test('CSS contracts: unused CSS classes are reported (or failed in strict mode)', () => {
  const defined = collectDefinedClasses();
  const used = collectUsedClasses();

  // Pseudo-state / structural helpers often paired in selectors
  const allowUnused = new Set([
    // keep empty; tighten as needed
  ]);

  const unused = [...defined.keys()]
    .filter((name) => !used.has(name) && !allowUnused.has(name))
    .sort((a, b) => a.localeCompare(b));

  if (unused.length === 0)
    return;

  const diagnostics = unused.map(
    (name) => `.${name} -> defined in: ${[...defined.get(name)].sort().join(', ')}`
  );
  const message = `Unused CSS classes:\n${diagnostics.join('\n')}`;
  const mode = envMode('CSS_UNUSED_MODE', 'warn');

  if (mode === 'fail')
    assert.equal(unused.length, 0, message);
  else
    console.warn(message);
});
