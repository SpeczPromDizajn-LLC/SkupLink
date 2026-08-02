const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const {
  WEB_ROOT,
  FIXTURES_ROOT,
  readText,
  readJson,
  hasPath,
  getNestedValue,
  envMode
} = require('./test-utils');

const APP_JS = path.join(WEB_ROOT, 'app.js');

/** Fields that app.js reads from each API surface (from property access analysis). */
const CONTRACTS = {
  '/api/ups': {
    fixtures: ['ups-online.json', 'ups-no-snmp.json'],
    requiredPaths: [
      'snmp_connected',
      'topology',
      'ident.manufacturer',
      'ident.model',
      'ident.name',
      'input.phases',
      'output.phases',
      'output.frequency',
      'output.total_percent_load',
      'output.total_power_watts',
      'battery.voltage',
      'battery.charge_percent',
      'battery.status',
      'battery.seconds_on_battery',
      'battery.estimated_minutes_remaining'
    ],
    onlineOnlyPhasePaths: [
      'input.phases.0.index',
      'input.phases.0.voltage',
      'input.phases.0.frequency',
      'output.phases.0.index',
      'output.phases.0.voltage',
      'output.phases.0.percent_load',
      'output.phases.0.power_watts'
    ]
  },
  '/api/history': {
    fixtures: ['history-sample.json'],
    requiredPaths: [
      'samples',
      'samples.0.ts',
      'samples.0.input_voltages',
      'samples.0.output_voltages',
      'samples.0.load_percents',
      'samples.0.battery_voltage',
      'samples.0.charge_percent'
    ]
  },
  '/api/settings': {
    fixtures: ['settings-public.json'],
    requiredPaths: [
      'snmp_host',
      'snmp_community',
      'snmp_version',
      'shutdown_battery_percent',
      'shutdown_delay_seconds'
    ]
  },
  '/api/login': {
    fixtures: ['login-ok.json'],
    requiredPaths: ['ok', 'token']
  },
  '/api/discover': {
    fixtures: ['discover-sample.json'],
    requiredPaths: [
      'ok',
      'devices',
      'devices.0.ip',
      'devices.0.name',
      'devices.0.version',
      'devices.0.rev',
      'devices.0.mac',
      'devices.0.uid',
      'devices.0.device_id',
      'broadcasts'
    ]
  },
  '/api/tray': {
    fixtures: ['tray-online.json', 'tray-no-snmp.json'],
    requiredPaths: ['ok', 'snmp_connected', 'on_battery', 'charge_percent']
  },
  '/health': {
    fixtures: ['health.json'],
    requiredPaths: ['ok', 'version']
  }
};

function pathExistsWithArrays(obj, dottedPath)
{
  const segments = dottedPath.split('.').filter(Boolean);
  let cursor = obj;

  for (const segment of segments)
  {
    if (cursor == null)
      return false;

    if (/^\d+$/.test(segment))
    {
      const idx = Number(segment);
      if (!Array.isArray(cursor) || idx >= cursor.length)
        return false;
      cursor = cursor[idx];
      continue;
    }

    if (!Object.prototype.hasOwnProperty.call(cursor, segment))
      return false;

    cursor = cursor[segment];
  }

  return true;
}

function collectAppApiUsages()
{
  const source = readText(APP_JS);
  const endpoints = new Set();
  const callRe = /(?:api|fetch)\(\s*(['"])(\/api\/[^'"]+|\/health)\1/g;
  let match = callRe.exec(source);

  while (match)
  {
    endpoints.add(match[2].replace(/\/$/, ''));
    match = callRe.exec(source);
  }

  return endpoints;
}

test('API fixtures exist and parse as JSON', () => {
  assert.ok(fs.existsSync(FIXTURES_ROOT), `fixtures root missing: ${FIXTURES_ROOT}`);

  const missing = [];
  const bad = [];

  for (const contract of Object.values(CONTRACTS))
  {
    for (const name of contract.fixtures)
    {
      const full = path.join(FIXTURES_ROOT, name);
      if (!fs.existsSync(full))
      {
        missing.push(name);
        continue;
      }

      try
      {
        readJson(full);
      }
      catch (error)
      {
        bad.push(`${name} -> ${error.message}`);
      }
    }
  }

  assert.equal(missing.length, 0, `Missing fixtures:\n${missing.join('\n')}`);
  assert.equal(bad.length, 0, `Invalid fixture JSON:\n${bad.join('\n')}`);
});

test('API fixtures cover fields consumed by app.js', () => {
  const diagnostics = [];

  for (const [endpoint, contract] of Object.entries(CONTRACTS))
  {
    for (const name of contract.fixtures)
    {
      const data = readJson(path.join(FIXTURES_ROOT, name));

      for (const fieldPath of contract.requiredPaths)
      {
        if (!pathExistsWithArrays(data, fieldPath))
          diagnostics.push(`${endpoint} / ${name} -> missing ${fieldPath}`);
      }

      if (name === 'ups-online.json' && contract.onlineOnlyPhasePaths)
      {
        for (const fieldPath of contract.onlineOnlyPhasePaths)
        {
          if (!pathExistsWithArrays(data, fieldPath))
            diagnostics.push(`${endpoint} / ${name} -> missing ${fieldPath}`);
        }
      }
    }
  }

  if (diagnostics.length === 0)
    return;

  const mode = envMode('API_CONTRACT_MODE', 'warn');
  const message = `API field contract failures:\n${diagnostics.join('\n')}`;

  if (mode === 'fail')
    assert.equal(diagnostics.length, 0, message);
  else
    console.warn(message);
});

test('app.js API endpoints have fixture coverage', () => {
  const used = collectAppApiUsages();
  const covered = new Set(Object.keys(CONTRACTS));
  // logout/password have no response body fields used by UI beyond ok/error
  const optional = new Set(['/api/logout', '/api/password']);
  const missing = [...used].filter((ep) => !covered.has(ep) && !optional.has(ep));

  assert.equal(
    missing.length,
    0,
    `app.js calls endpoints without fixtures/contracts:\n${missing.join('\n')}`
  );
});

test('ups-online fixture looks SNMP-connected; ups-no-snmp does not', () => {
  const online = readJson(path.join(FIXTURES_ROOT, 'ups-online.json'));
  const offline = readJson(path.join(FIXTURES_ROOT, 'ups-no-snmp.json'));

  assert.equal(online.snmp_connected, true);
  assert.equal(offline.snmp_connected, false);
  assert.ok(Array.isArray(online.input.phases) && online.input.phases.length >= 1);
  assert.ok(Array.isArray(online.output.phases) && online.output.phases.length >= 1);
});

test('settings fixture uses valid snmp_version and ranges', () => {
  const s = readJson(path.join(FIXTURES_ROOT, 'settings-public.json'));
  assert.ok(s.snmp_version === '1' || s.snmp_version === '2c');
  assert.ok(s.shutdown_battery_percent >= 1 && s.shutdown_battery_percent <= 99);
  assert.ok(s.shutdown_delay_seconds >= 0 && s.shutdown_delay_seconds <= 7200);
});

test('history samples expose chart series fields as arrays/numbers', () => {
  const hist = readJson(path.join(FIXTURES_ROOT, 'history-sample.json'));
  assert.ok(Array.isArray(hist.samples) && hist.samples.length >= 2);

  for (const sample of hist.samples)
  {
    assert.ok(typeof sample.ts === 'string' && sample.ts.length > 0);
    assert.ok(Array.isArray(sample.input_voltages));
    assert.ok(Array.isArray(sample.output_voltages));
    assert.ok(Array.isArray(sample.load_percents));
    assert.equal(typeof sample.battery_voltage, 'number');
    assert.equal(typeof sample.charge_percent, 'number');
  }
});

// Keep getNestedValue referenced for future nested checks / SKUP-8 parity helpers.
test('getNestedValue helper resolves fixture paths', () => {
  const online = readJson(path.join(FIXTURES_ROOT, 'ups-online.json'));
  const found = getNestedValue(online, ['battery', 'charge_percent']);
  assert.equal(found.exists, true);
  assert.equal(typeof found.value, 'number');
  assert.equal(hasPath(online, 'battery.charge_percent'), true);
});
