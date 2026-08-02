const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const {
  SERVICE_ROOT,
  TRAY_ROOT,
  FIXTURES_ROOT,
  readText,
  readJson,
  extractPasConstInt,
  extractPasClassBody,
  extractPasPropertyNames,
  extractPasTrayFieldWrites,
  extractPasTrayFieldReads
} = require('./test-utils');

const SERVICE_COMMON = path.join(SERVICE_ROOT, 'Common.pas');
const TRAY_COMMON = path.join(TRAY_ROOT, 'Common.pas');
const SERVICE_API_MODELS = path.join(SERVICE_ROOT, 'uApiModels.pas');
const TRAY_API_MODELS = path.join(TRAY_ROOT, 'uApiModels.pas');
const SERVICE_SNMP = path.join(SERVICE_ROOT, 'uSnmpUpsClient.pas');
const TRAY_MAIN = path.join(TRAY_ROOT, 'uMain.pas');

const EXPECTED_TRAY_FIELDS = [
  'ok',
  'snmp_connected',
  'on_battery',
  'charge_percent'
];

function sorted(values)
{
  return [...values].sort();
}

test('HTTP_PORT matches between service and tray Common.pas', () => {
  for (const filePath of [SERVICE_COMMON, TRAY_COMMON])
    assert.ok(fs.existsSync(filePath), `missing ${filePath}`);

  const servicePort = extractPasConstInt(readText(SERVICE_COMMON), 'HTTP_PORT');
  const trayPort = extractPasConstInt(readText(TRAY_COMMON), 'HTTP_PORT');

  assert.equal(servicePort, 8847, 'service HTTP_PORT missing or unexpected');
  assert.equal(trayPort, servicePort, 'HTTP_PORT drifted between service and tray');
});

test('TApiTrayStatus properties match between service and tray uApiModels.pas', () => {
  for (const filePath of [SERVICE_API_MODELS, TRAY_API_MODELS])
    assert.ok(fs.existsSync(filePath), `missing ${filePath}`);

  const serviceBody = extractPasClassBody(readText(SERVICE_API_MODELS), 'TApiTrayStatus');
  const trayBody = extractPasClassBody(readText(TRAY_API_MODELS), 'TApiTrayStatus');

  assert.ok(serviceBody, 'TApiTrayStatus not found in service uApiModels.pas');
  assert.ok(trayBody, 'TApiTrayStatus not found in tray uApiModels.pas');

  const serviceProps = extractPasPropertyNames(serviceBody);
  const trayProps = extractPasPropertyNames(trayBody);

  assert.deepEqual(
    sorted(serviceProps),
    sorted(EXPECTED_TRAY_FIELDS),
    'service TApiTrayStatus properties drifted from expected tray JSON fields'
  );
  assert.deepEqual(
    sorted(trayProps),
    sorted(serviceProps),
    'TApiTrayStatus property set drifted between service and tray'
  );
});

test('GetTrayJson writers and tray uMain readers use TApiTrayStatus fields', () => {
  const serviceSnmp = readText(SERVICE_SNMP);
  const trayMain = readText(TRAY_MAIN);

  const writes = extractPasTrayFieldWrites(serviceSnmp);
  const reads = extractPasTrayFieldReads(trayMain);

  assert.deepEqual(
    sorted(writes),
    sorted(EXPECTED_TRAY_FIELDS),
    'GetTrayJson Tray.* := fields must match TApiTrayStatus JSON properties'
  );

  for (const field of EXPECTED_TRAY_FIELDS)
  {
    assert.ok(
      reads.includes(field),
      `tray uMain.pas must read Tray.${field} from /api/tray JSON`
    );
  }
});

test('tray API fixtures expose the same field names as TApiTrayStatus', () => {
  for (const name of ['tray-online.json', 'tray-no-snmp.json'])
  {
    const fixturePath = path.join(FIXTURES_ROOT, name);
    assert.ok(fs.existsSync(fixturePath), `missing fixture ${fixturePath}`);

    const keys = Object.keys(readJson(fixturePath));
    assert.deepEqual(
      sorted(keys),
      sorted(EXPECTED_TRAY_FIELDS),
      `fixture ${name} keys must match TApiTrayStatus properties`
    );
  }
});
