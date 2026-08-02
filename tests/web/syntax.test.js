const assert = require('node:assert/strict');
const test = require('node:test');
const vm = require('node:vm');

const {
  listFilesByExtensions,
  toWebRelative,
  readText
} = require('./test-utils');

const VOID_TAGS = new Set([
  'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
  'link', 'meta', 'param', 'source', 'track', 'wbr'
]);

const OPTIONAL_END_TAGS = new Set([
  'li', 'p', 'dt', 'dd', 'option', 'thead', 'tbody', 'tfoot', 'tr', 'td', 'th'
]);

function checkJsSyntax(filePath, source)
{
  try
  {
    new vm.Script(source, { filename: filePath });
    return null;
  }
  catch (error)
  {
    return error;
  }
}

function checkCssSyntax(source)
{
  const stack = [];
  let inComment = false;
  let inSingle = false;
  let inDouble = false;
  let escaped = false;

  for (let i = 0; i < source.length; i++)
  {
    const ch = source[i];
    const next = source[i + 1];

    if (inComment)
    {
      if ((ch === '*') && (next === '/'))
      {
        inComment = false;
        i++;
      }
      continue;
    }

    if (inSingle)
    {
      if (!escaped && (ch === '\''))
        inSingle = false;
      escaped = (!escaped && (ch === '\\'));
      continue;
    }

    if (inDouble)
    {
      if (!escaped && (ch === '"'))
        inDouble = false;
      escaped = (!escaped && (ch === '\\'));
      continue;
    }

    if ((ch === '/') && (next === '*'))
    {
      inComment = true;
      i++;
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

    if ((ch === '{') || (ch === '[') || (ch === '('))
      stack.push(ch);

    if ((ch === '}') || (ch === ']') || (ch === ')'))
    {
      const open = stack.pop();
      const ok =
        ((open === '{') && (ch === '}')) ||
        ((open === '[') && (ch === ']')) ||
        ((open === '(') && (ch === ')'));

      if (!ok)
        return new Error(`Unbalanced token near position ${i}: '${ch}'`);
    }
  }

  if (inComment)
    return new Error('Unclosed CSS comment');
  if (inSingle || inDouble)
    return new Error('Unclosed CSS string literal');
  if (stack.length > 0)
    return new Error('Unbalanced CSS delimiters');

  return null;
}

function checkHtmlSyntax(source)
{
  const errors = [];
  const stack = [];
  const scriptErrors = [];

  const scriptRe = /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
  let scriptMatch = scriptRe.exec(source);
  while (scriptMatch)
  {
    const attrs = scriptMatch[1] || '';
    const body = scriptMatch[2] || '';

    if (!/\bsrc\s*=/i.test(attrs))
    {
      const scriptError = checkJsSyntax('<inline-script>', body);
      if (scriptError)
        scriptErrors.push(scriptError.message);
    }

    scriptMatch = scriptRe.exec(source);
  }

  const stripped = source
    .replace(/<script\b[\s\S]*?<\/script>/gi, '')
    .replace(/<style\b[\s\S]*?<\/style>/gi, '');

  const tagRe = /<!--[\s\S]*?-->|<!DOCTYPE[^>]*>|<\/?([a-zA-Z][\w:-]*)\b[^>]*>/gi;
  let tagMatch = tagRe.exec(stripped);

  while (tagMatch)
  {
    const fullTag = tagMatch[0];
    const tagName = (tagMatch[1] || '').toLowerCase();

    if ((tagName !== '') && !fullTag.startsWith('<!--') && !fullTag.startsWith('<!DOCTYPE'))
    {
      const isClosing = fullTag.startsWith('</');
      const isSelfClosing = /\/>$/.test(fullTag);

      if (!isClosing && !isSelfClosing && !VOID_TAGS.has(tagName))
      {
        stack.push(tagName);
      }
      else if (isClosing)
      {
        const idx = stack.lastIndexOf(tagName);
        if (idx === -1)
          errors.push(`Unexpected closing tag </${tagName}>`);
        else
          stack.splice(idx);
      }
    }

    tagMatch = tagRe.exec(stripped);
  }

  const nonOptionalUnclosed = stack.filter((tag) => !OPTIONAL_END_TAGS.has(tag));
  if (nonOptionalUnclosed.length > 0)
    errors.push(`Unclosed tags: ${nonOptionalUnclosed.join(', ')}`);

  return [...scriptErrors, ...errors];
}

test('JS syntax is valid in all web files', () => {
  const jsFiles = listFilesByExtensions(['.js']);
  const failures = [];

  for (const filePath of jsFiles)
  {
    const source = readText(filePath);
    const error = checkJsSyntax(filePath, source);
    if (error)
      failures.push(`${toWebRelative(filePath)} -> ${error.message}`);
  }

  assert.equal(failures.length, 0, `JS syntax errors:\n${failures.join('\n')}`);
});

test('HTML syntax and inline scripts are valid', () => {
  const htmlFiles = listFilesByExtensions(['.html']);
  const failures = [];

  for (const filePath of htmlFiles)
  {
    const source = readText(filePath);
    const errors = checkHtmlSyntax(source);
    if (errors.length > 0)
      failures.push(`${toWebRelative(filePath)} -> ${errors.join('; ')}`);
  }

  assert.equal(failures.length, 0, `HTML syntax errors:\n${failures.join('\n')}`);
});

test('CSS syntax is valid in all web files', () => {
  const cssFiles = listFilesByExtensions(['.css']);
  const failures = [];

  for (const filePath of cssFiles)
  {
    const source = readText(filePath);
    const error = checkCssSyntax(source);
    if (error)
      failures.push(`${toWebRelative(filePath)} -> ${error.message}`);
  }

  assert.equal(failures.length, 0, `CSS syntax errors:\n${failures.join('\n')}`);
});
