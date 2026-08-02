const assert = require('node:assert/strict');
const path = require('node:path');
const test = require('node:test');

const {
  WEB_ROOT,
  listFilesByExtensions,
  toWebRelative,
  readText,
  resolveWebLink,
  extractInlineScripts,
  extractScriptSrcs,
  extractHtmlIds
} = require('./test-utils');

function collectDomRefs(scriptSource)
{
  const refs = new Set();
  const createdIds = new Set();

  const patterns = [
    /\$\(\s*(['"])([^'"`]+)\1\s*\)/g,
    /\bgetElementById\(\s*(['"])([^'"`]+)\1\s*\)/g,
    /\bsetText\(\s*(['"])([^'"`]+)\1\s*,/g
  ];

  for (const pattern of patterns)
  {
    let match = pattern.exec(scriptSource);
    while (match)
    {
      refs.add(match[2]);
      match = pattern.exec(scriptSource);
    }
  }

  // Template id: $(`panel-${btn.dataset.tab}`) — tabs used in HTML
  if (/\$\(\s*`panel-\$\{/.test(scriptSource))
  {
    for (const tab of ['overview', 'charts', 'settings'])
      refs.add(`panel-${tab}`);
  }

  const idAssignmentPatterns = [
    /\.id\s*=\s*(['"])([^'"`]+)\1/g,
    /\bsetAttribute\(\s*['"]id['"]\s*,\s*(['"])([^'"`]+)\1\s*\)/g
  ];

  for (const pattern of idAssignmentPatterns)
  {
    let match = pattern.exec(scriptSource);
    while (match)
    {
      createdIds.add(match[2]);
      match = pattern.exec(scriptSource);
    }
  }

  return { refs, createdIds };
}

test('DOM contracts: referenced element ids exist in target pages', () => {
  const htmlFiles = listFilesByExtensions(['.html']);
  const htmlData = [];
  const scriptToPages = new Map();
  const failures = [];

  for (const htmlFile of htmlFiles)
  {
    const htmlSource = readText(htmlFile);
    const ids = new Set(extractHtmlIds(htmlSource));
    const inlineScripts = extractInlineScripts(htmlSource);
    const scriptSrcs = extractScriptSrcs(htmlSource);
    const relHtml = toWebRelative(htmlFile);
    const resolvedScripts = [];

    for (const src of scriptSrcs)
    {
      const resolved = resolveWebLink(src, htmlFile);
      if (!resolved || resolved.error || !resolved.path)
        continue;

      const relScript = toWebRelative(resolved.path);
      if (path.basename(relScript) === 'lang.js')
        continue;

      resolvedScripts.push({ relScript, absScript: resolved.path });
      if (!scriptToPages.has(relScript))
        scriptToPages.set(relScript, []);
      scriptToPages.get(relScript).push(relHtml);
    }

    htmlData.push({
      relHtml,
      ids,
      inlineScripts,
      resolvedScripts
    });
  }

  for (const page of htmlData)
  {
    for (const inlineScript of page.inlineScripts)
    {
      const { refs, createdIds } = collectDomRefs(inlineScript);
      for (const ref of refs)
      {
        if (createdIds.has(ref))
          continue;

        if (!page.ids.has(ref))
          failures.push(`${page.relHtml} -> inline script references missing id '${ref}'`);
      }
    }
  }

  const pageIdsByRelHtml = new Map(htmlData.map((p) => [p.relHtml, p.ids]));
  const processedScripts = new Set();

  for (const page of htmlData)
  {
    for (const script of page.resolvedScripts)
    {
      if (processedScripts.has(script.relScript))
        continue;

      processedScripts.add(script.relScript);
      const scriptSource = readText(script.absScript);
      const { refs, createdIds } = collectDomRefs(scriptSource);
      const pages = scriptToPages.get(script.relScript) || [];

      const unionIds = new Set();
      for (const relHtml of pages)
      {
        const ids = pageIdsByRelHtml.get(relHtml) || new Set();
        for (const id of ids)
          unionIds.add(id);
      }

      for (const ref of refs)
      {
        if (createdIds.has(ref))
          continue;

        if (!unionIds.has(ref))
          failures.push(`${script.relScript} -> missing id '${ref}' in pages: ${pages.join(', ') || '(none)'}`);
      }
    }
  }

  // Also ensure app.js alone is checked against index.html even if script map empty
  const appJs = path.join(WEB_ROOT, 'app.js');
  const indexHtml = path.join(WEB_ROOT, 'index.html');
  if (fsExists(appJs) && fsExists(indexHtml) && !processedScripts.has('app.js'))
  {
    const ids = new Set(extractHtmlIds(readText(indexHtml)));
    const { refs, createdIds } = collectDomRefs(readText(appJs));

    for (const ref of refs)
    {
      if (createdIds.has(ref))
        continue;
      if (!ids.has(ref))
        failures.push(`app.js -> missing id '${ref}' in index.html`);
    }
  }

  assert.equal(failures.length, 0, `DOM contract errors:\n${failures.join('\n')}`);
});

function fsExists(p)
{
  return require('node:fs').existsSync(p);
}
