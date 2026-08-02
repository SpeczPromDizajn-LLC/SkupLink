const assert = require('node:assert/strict');
const test = require('node:test');

const {
  listFilesByExtensions,
  toWebRelative,
  readText,
  resolveWebLink,
  pathExistsForLink,
  extractHtmlAttributeLinks,
  extractCssUrls
} = require('./test-utils');

function collectStaticAbsoluteUrls(source)
{
  const links = [];
  const urlRe = /(['"`])(\/(?:fonts|favicon\.svg|app\.(?:css|js)|lang\.js)[^'"`?#\s]*(?:\?[^'"`#\s]*)?(?:#[^'"`\s]*)?)\1/g;
  let match = urlRe.exec(source);

  while (match)
  {
    links.push(match[2]);
    match = urlRe.exec(source);
  }

  return links;
}

test('All local links point to existing files', () => {
  const htmlFiles = listFilesByExtensions(['.html']);
  const cssFiles = listFilesByExtensions(['.css']);
  const jsFiles = listFilesByExtensions(['.js']);
  const broken = [];

  for (const filePath of htmlFiles)
  {
    const source = readText(filePath);
    const links = [
      ...extractHtmlAttributeLinks(source),
      ...collectStaticAbsoluteUrls(source)
    ];

    for (const link of links)
    {
      const resolved = resolveWebLink(link, filePath, { skipDynamicRoutes: true });

      if (resolved == null)
        continue;

      if (resolved.error)
      {
        broken.push(`${toWebRelative(filePath)} -> ${link} (${resolved.error})`);
        continue;
      }

      if (!pathExistsForLink(resolved.path))
        broken.push(`${toWebRelative(filePath)} -> ${link} (missing)`);
    }
  }

  for (const filePath of cssFiles)
  {
    const source = readText(filePath);
    const links = extractCssUrls(source);

    for (const link of links)
    {
      const resolved = resolveWebLink(link, filePath, { skipDynamicRoutes: true });

      if (resolved == null)
        continue;

      if (resolved.error)
      {
        broken.push(`${toWebRelative(filePath)} -> ${link} (${resolved.error})`);
        continue;
      }

      if (!pathExistsForLink(resolved.path))
        broken.push(`${toWebRelative(filePath)} -> ${link} (missing)`);
    }
  }

  for (const filePath of jsFiles)
  {
    const source = readText(filePath);
    const links = collectStaticAbsoluteUrls(source);

    for (const link of links)
    {
      const resolved = resolveWebLink(link, filePath, { skipDynamicRoutes: true });

      if (resolved == null)
        continue;

      if (resolved.error)
      {
        broken.push(`${toWebRelative(filePath)} -> ${link} (${resolved.error})`);
        continue;
      }

      if (!pathExistsForLink(resolved.path))
        broken.push(`${toWebRelative(filePath)} -> ${link} (missing)`);
    }
  }

  assert.equal(broken.length, 0, `Broken local links:\n${broken.join('\n')}`);
});
