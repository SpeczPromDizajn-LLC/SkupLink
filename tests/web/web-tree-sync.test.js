const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const {
  WEB_ROOT,
  LINUX_WEB_ROOT,
  walkFiles,
  toWebRelative
} = require('./test-utils');

const CONTENT_EXTS = new Set(['.html', '.css', '.js']);
const FONT_EXTS = new Set(['.woff2', '.woff', '.ttf', '.otf', '.txt', '.svg']);

function listRelative(root, predicate)
{
  return walkFiles(root)
    .map((abs) => toWebRelative(abs, root))
    .filter((rel) => predicate(rel, path.extname(rel).toLowerCase()))
    .sort();
}

function fileHash(absPath)
{
  return crypto.createHash('sha256').update(fs.readFileSync(absPath)).digest('hex');
}

test('Service/web and Linux/web share the same meaningful content files', () => {
  assert.ok(fs.existsSync(WEB_ROOT), `WEB_ROOT missing: ${WEB_ROOT}`);
  assert.ok(fs.existsSync(LINUX_WEB_ROOT), `LINUX_WEB_ROOT missing: ${LINUX_WEB_ROOT}`);

  const serviceFiles = listRelative(
    WEB_ROOT,
    (_rel, ext) => CONTENT_EXTS.has(ext)
  );
  const linuxFiles = listRelative(
    LINUX_WEB_ROOT,
    (_rel, ext) => CONTENT_EXTS.has(ext)
  );

  assert.deepEqual(
    linuxFiles,
    serviceFiles,
    `Content file set mismatch.\nOnly in Service: ${serviceFiles.filter((f) => !linuxFiles.includes(f)).join(', ') || '-'}\nOnly in Linux: ${linuxFiles.filter((f) => !serviceFiles.includes(f)).join(', ') || '-'}`
  );

  const mismatches = [];

  for (const rel of serviceFiles)
  {
    const a = path.join(WEB_ROOT, rel);
    const b = path.join(LINUX_WEB_ROOT, rel);
    const ha = fileHash(a);
    const hb = fileHash(b);

    if (ha !== hb)
      mismatches.push(rel);
  }

  assert.equal(
    mismatches.length,
    0,
    `Content differs between Service/web and Linux/web:\n${mismatches.join('\n')}`
  );
});

test('Service/web and Linux/web have matching font asset paths', () => {
  const serviceFonts = listRelative(
    WEB_ROOT,
    (rel, ext) => rel.startsWith('fonts/') && FONT_EXTS.has(ext)
  );
  const linuxFonts = listRelative(
    LINUX_WEB_ROOT,
    (rel, ext) => rel.startsWith('fonts/') && FONT_EXTS.has(ext)
  );

  assert.deepEqual(
    linuxFonts,
    serviceFonts,
    `Font path mismatch.\nOnly in Service: ${serviceFonts.filter((f) => !linuxFonts.includes(f)).join(', ') || '-'}\nOnly in Linux: ${linuxFonts.filter((f) => !serviceFonts.includes(f)).join(', ') || '-'}`
  );
});

test('favicon.svg exists in both web trees when present in Service', () => {
  const serviceFav = path.join(WEB_ROOT, 'favicon.svg');
  const linuxFav = path.join(LINUX_WEB_ROOT, 'favicon.svg');

  if (!fs.existsSync(serviceFav))
    return;

  assert.ok(fs.existsSync(linuxFav), 'Linux/web/favicon.svg is missing');
  assert.equal(fileHash(serviceFav), fileHash(linuxFav), 'favicon.svg differs between trees');
});
