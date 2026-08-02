const assert = require('node:assert/strict');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const { WEB_ROOT, readText } = require('./test-utils');

function loadSLLang(initialLang)
{
  const source = readText(path.join(WEB_ROOT, 'lang.js'));
  const store = new Map();

  if (initialLang)
    store.set('skuplink_lang', initialLang);

  const nodes = [];
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
      querySelectorAll(selector)
      {
        if (selector === '[data-i18n]' || selector === '[data-i18n-placeholder]' ||
            selector === '[data-i18n-aria]' || selector === '.lang-btn' ||
            selector === '[data-app-version]')
          return nodes.filter((n) => {
            if (selector === '.lang-btn')
              return n.classList && n.classList.contains('lang-btn');
            if (selector.startsWith('['))
            {
              const attr = selector.slice(1, -1);
              return n.getAttribute && n.getAttribute(attr) != null;
            }
            return false;
          });
        return [];
      }
    }
  };

  sandbox.window = sandbox;
  vm.runInNewContext(source, sandbox, { filename: 'lang.js' });

  return { SLLang: sandbox.SLLang, document: sandbox.document, store };
}

test('SLLang.t returns Russian default strings', () => {
  const { SLLang } = loadSLLang('ru');
  assert.equal(SLLang.t('brand'), 'SkupLink');
  assert.equal(SLLang.t('tab_overview'), 'Обзор');
  assert.equal(SLLang.t('dash'), '—');
});

test('SLLang.t interpolates variables and unit tokens', () => {
  const { SLLang } = loadSLLang('en');
  assert.equal(SLLang.t('version_label', { n: '1.0' }), 'v. 1.0');
  assert.equal(SLLang.t('threshold_percent', { n: 15 }), '15 %');
  assert.equal(SLLang.t('error_http', { code: 500 }), 'HTTP error 500');
  assert.match(SLLang.t('phase_in_value', { v: '220', hz: '50.0' }), /220 V/);
});

test('SLLang.setLang switches dictionary', () => {
  const { SLLang, store } = loadSLLang('ru');
  assert.equal(SLLang.t('logout'), 'Выход');
  SLLang.setLang('en');
  assert.equal(SLLang.t('logout'), 'Sign out');
  assert.equal(store.get('skuplink_lang'), 'en');
});

test('SLLang.t falls back to key for unknown entries', () => {
  const { SLLang } = loadSLLang('en');
  assert.equal(SLLang.t('definitely_missing_key_xyz'), 'definitely_missing_key_xyz');
});
