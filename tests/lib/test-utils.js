const fs = require('node:fs');
const path = require('node:path');

const REPO_ROOT = path.resolve(__dirname, '../..');
const WEB_ROOT = path.resolve(__dirname, '../../SkupLinkService/web');
const LINUX_WEB_ROOT = path.resolve(__dirname, '../../Linux/web');
const SERVICE_ROOT = path.resolve(__dirname, '../../SkupLinkService');
const TRAY_ROOT = path.resolve(__dirname, '../../SkupLinkTray');
const FIXTURES_ROOT = path.resolve(__dirname, '../contracts/fixtures/api');

function walkFiles(dirPath, output = [])
{
  if (!fs.existsSync(dirPath))
    return output;

  const entries = fs.readdirSync(dirPath, { withFileTypes: true });

  for (const entry of entries)
  {
    const fullPath = path.join(dirPath, entry.name);

    if (entry.isDirectory())
      walkFiles(fullPath, output);
    else if (entry.isFile())
      output.push(fullPath);
  }

  return output;
}

function listFilesByExtensions(extensions, root = WEB_ROOT)
{
  const normalized = new Set(extensions.map((ext) => ext.toLowerCase()));

  return walkFiles(root)
    .filter((filePath) => normalized.has(path.extname(filePath).toLowerCase()))
    .sort();
}

function toWebRelative(filePath, root = WEB_ROOT)
{
  return path.relative(root, filePath).split(path.sep).join('/');
}

function readText(filePath)
{
  return fs.readFileSync(filePath, 'utf8');
}

function readJson(filePath)
{
  return JSON.parse(readText(filePath));
}

function stripQueryAndHash(rawUrl)
{
  const hashPos = rawUrl.indexOf('#');
  const queryPos = rawUrl.indexOf('?');

  let endPos = rawUrl.length;
  if (hashPos >= 0)
    endPos = Math.min(endPos, hashPos);
  if (queryPos >= 0)
    endPos = Math.min(endPos, queryPos);

  return rawUrl.slice(0, endPos);
}

function shouldSkipLink(url, options = {})
{
  if (!url)
    return true;

  const trimmed = url.trim();

  if ((trimmed === '') || (trimmed === '#') || trimmed.startsWith('#'))
    return true;

  if (/^(mailto|tel|javascript|data):/i.test(trimmed))
    return true;

  if (/^[a-z][a-z0-9+.-]*:/i.test(trimmed))
    return true;

  if (trimmed.startsWith('//'))
    return true;

  if (options.skipDynamicRoutes)
  {
    const cleaned = stripQueryAndHash(trimmed);

    if (/^\/api\//i.test(cleaned))
      return true;

    if (/^\/health$/i.test(cleaned))
      return true;
  }

  return false;
}

function isWithinWebRoot(targetPath, root = WEB_ROOT)
{
  const rel = path.relative(root, targetPath);

  return rel !== '' && !rel.startsWith('..') && !path.isAbsolute(rel);
}

function resolveWebLink(rawUrl, sourceFile, options = {})
{
  if (shouldSkipLink(rawUrl, options))
    return null;

  const cleaned = stripQueryAndHash(rawUrl.trim());
  let resolvedPath;

  if (cleaned.startsWith('/'))
    resolvedPath = path.resolve(WEB_ROOT, cleaned.slice(1));
  else
    resolvedPath = path.resolve(path.dirname(sourceFile), cleaned);

  if (!isWithinWebRoot(resolvedPath) && (resolvedPath !== WEB_ROOT))
    return { error: `path escapes web root (${resolvedPath})` };

  return { path: resolvedPath };
}

function pathExistsForLink(candidatePath)
{
  if (fs.existsSync(candidatePath))
  {
    const stat = fs.statSync(candidatePath);

    if (stat.isFile())
      return true;

    if (stat.isDirectory() && fs.existsSync(path.join(candidatePath, 'index.html')))
      return true;
  }

  if (!path.extname(candidatePath))
  {
    if (fs.existsSync(`${candidatePath}.html`))
      return true;

    if (fs.existsSync(path.join(candidatePath, 'index.html')))
      return true;
  }

  return false;
}

function extractHtmlAttributeLinks(content)
{
  const links = [];
  const attrRe = /\b(?:href|src|action|formaction|xlink:href)\s*=\s*(['"])(.*?)\1/gi;
  let match = attrRe.exec(content);

  while (match)
  {
    links.push(match[2]);
    match = attrRe.exec(content);
  }

  return links;
}

function extractCssUrls(content)
{
  const links = [];
  const urlRe = /url\(\s*(['"]?)([^'")]+)\1\s*\)/gi;
  let match = urlRe.exec(content);

  while (match)
  {
    links.push(match[2]);
    match = urlRe.exec(content);
  }

  return links;
}

function extractInlineScripts(content)
{
  const scripts = [];
  const scriptRe = /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
  let match = scriptRe.exec(content);

  while (match)
  {
    const attrs = match[1] || '';
    const body = match[2] || '';

    if (!/\bsrc\s*=/i.test(attrs))
      scripts.push(body);

    match = scriptRe.exec(content);
  }

  return scripts;
}

function extractScriptSrcs(content)
{
  const scripts = [];
  const scriptRe = /<script\b[^>]*\bsrc\s*=\s*(['"])(.*?)\1[^>]*>/gi;
  let match = scriptRe.exec(content);

  while (match)
  {
    scripts.push(match[2]);
    match = scriptRe.exec(content);
  }

  return scripts;
}

function extractHtmlIds(content)
{
  const ids = [];
  const idRe = /\bid\s*=\s*(['"])([^'"]+)\1/gi;
  let match = idRe.exec(content);

  while (match)
  {
    ids.push(match[2]);
    match = idRe.exec(content);
  }

  return ids;
}

function getNestedValue(obj, pathSegments)
{
  let cursor = obj;

  for (const segment of pathSegments)
  {
    if ((cursor == null) || !Object.prototype.hasOwnProperty.call(cursor, segment))
      return { exists: false, value: undefined };

    cursor = cursor[segment];
  }

  return { exists: true, value: cursor };
}

function hasPath(obj, dottedPath)
{
  const segments = dottedPath.split('.').filter(Boolean);
  return getNestedValue(obj, segments).exists;
}

function collapseWhitespace(value)
{
  return value.replace(/\s+/g, ' ').trim();
}

function envMode(name, fallback = 'warn')
{
  const raw = process.env[name];

  if (raw == null || raw === '')
    return fallback;

  return String(raw).toLowerCase();
}

/** Integer const `Name = 123;` from Delphi source (ignores comments on prior lines). */
function extractPasConstInt(source, constName)
{
  const re = new RegExp(
    `(?:^|[\\r\\n])[ \\t]*${constName}[ \\t]*=[ \\t]*(-?\\d+)[ \\t]*;`,
    'm'
  );
  const match = source.match(re);

  if (!match)
    return null;

  return Number(match[1]);
}

/** Body between `ClassName = class` and matching `end;` (first level). */
function extractPasClassBody(source, className)
{
  const re = new RegExp(
    `${className}[ \\t]*=[ \\t]*class\\b([\\s\\S]*?)\\r?\\n[ \\t]*end[ \\t]*;`,
    'i'
  );
  const match = source.match(re);

  return match ? match[1] : null;
}

function extractPasPropertyNames(classBody)
{
  if (!classBody)
    return [];

  const names = [];
  const re = /\bproperty[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]*:/g;
  let match = re.exec(classBody);

  while (match)
  {
    names.push(match[1]);
    match = re.exec(classBody);
  }

  return names;
}

/** `Tray.field :=` assignments (service GetTrayJson writers). */
function extractPasTrayFieldWrites(source)
{
  const names = [];
  const re = /\bTray\.([A-Za-z_][A-Za-z0-9_]*)[ \t]*:=/g;
  let match = re.exec(source);

  while (match)
  {
    names.push(match[1]);
    match = re.exec(source);
  }

  return [...new Set(names)];
}

/** `Tray.field` reads in tray client code (excludes declarations). */
function extractPasTrayFieldReads(source)
{
  const names = [];
  const re = /\bTray\.([A-Za-z_][A-Za-z0-9_]*)\b/g;
  let match = re.exec(source);

  while (match)
  {
    names.push(match[1]);
    match = re.exec(source);
  }

  return [...new Set(names)];
}

function reportByMode(diagnostics, modeName, messagePrefix, fallback = 'warn')
{
  if (diagnostics.length === 0)
    return;

  const mode = envMode(modeName, fallback);
  const message = `${messagePrefix}\n${diagnostics.join('\n')}`;

  if (mode === 'fail')
  {
    const assert = require('node:assert/strict');
    assert.equal(diagnostics.length, 0, message);
  }
  else
  {
    console.warn(message);
  }
}

module.exports = {
  REPO_ROOT,
  WEB_ROOT,
  LINUX_WEB_ROOT,
  SERVICE_ROOT,
  TRAY_ROOT,
  FIXTURES_ROOT,
  walkFiles,
  listFilesByExtensions,
  toWebRelative,
  readText,
  readJson,
  resolveWebLink,
  pathExistsForLink,
  extractHtmlAttributeLinks,
  extractCssUrls,
  extractInlineScripts,
  extractScriptSrcs,
  extractHtmlIds,
  getNestedValue,
  hasPath,
  collapseWhitespace,
  envMode,
  reportByMode,
  extractPasConstInt,
  extractPasClassBody,
  extractPasPropertyNames,
  extractPasTrayFieldWrites,
  extractPasTrayFieldReads
};
