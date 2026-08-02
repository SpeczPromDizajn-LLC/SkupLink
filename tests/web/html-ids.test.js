const assert = require('node:assert/strict');
const test = require('node:test');

const {
  listFilesByExtensions,
  toWebRelative,
  readText,
  extractHtmlIds,
  envMode
} = require('./test-utils');

test('HTML ids are unique inside each page', () => {
  const htmlFiles = listFilesByExtensions(['.html']);
  const diagnostics = [];

  for (const htmlFile of htmlFiles)
  {
    const rel = toWebRelative(htmlFile);
    const ids = extractHtmlIds(readText(htmlFile));
    const seen = new Set();
    const duplicates = new Set();

    for (const id of ids)
    {
      if (seen.has(id))
        duplicates.add(id);
      else
        seen.add(id);
    }

    if (duplicates.size > 0)
      diagnostics.push(`${rel} -> duplicate ids: ${[...duplicates].join(', ')}`);
  }

  if (diagnostics.length === 0)
    return;

  const mode = envMode('HTML_ID_MODE', 'warn');
  const message = `Duplicate HTML ids found:\n${diagnostics.join('\n')}`;

  if (mode === 'fail')
    assert.equal(diagnostics.length, 0, message);
  else
    console.warn(message);
});
