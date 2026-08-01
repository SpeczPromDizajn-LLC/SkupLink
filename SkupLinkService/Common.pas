unit Common;

interface

const
 // App (name must not collide with Delphi properties — identifiers are case-insensitive)
 STR_APP_NAME    = 'SkupLink';
 STR_APP_VERSION = '1.0';

 // Service / HTTP
 HTTP_PORT             = 8847;
 POLL_INTERVAL_SECONDS = 5;

 // SNMP
 SNMP_PORT                  = 161;
 SNMP_RECEIVE_TIMEOUT_MS    = 2000;
 STR_SNMP_HOST_DEFAULT      = '192.168.3.126';
 STR_SNMP_HOST_FALLBACK     = '127.0.0.1';
 STR_SNMP_COMMUNITY_DEFAULT = 'public';
 STR_SNMP_VERSION_1         = '1';
 STR_SNMP_VERSION_2C        = '2c';
 STR_SNMP_VERSION_DEFAULT   = STR_SNMP_VERSION_1;
 // Indy / RFC wire values: 0 = SNMPv1, 1 = SNMPv2c
 SNMP_WIRE_VERSION_1  = 0;
 SNMP_WIRE_VERSION_2C = 1;

 // UDP device discovery (Kortex-compatible)
 UDP_DISCOVER_PORT           = 51847;
 UDP_DISCOVER_QUERY          = 'I';
 UDP_DISCOVER_DURATION_MS    = 3000;
 UDP_DISCOVER_SEND_EVERY_MS  = 500;
 UDP_DISCOVER_BLOCK_I2C_SIZE = 128;

 // Config paths
 STR_CONFIG_FILE_NAME  = 'config.json';
 STR_CONFIG_APP_FOLDER = STR_APP_NAME;
 STR_WEB_FOLDER        = 'web';

{$IFDEF MSWINDOWS}
 STR_ENV_PROGRAMDATA = 'ProgramData';
{$ELSE}
 STR_CONFIG_LINUX_DIR = '/etc/skuplink';
{$ENDIF}
 // Auth / UI defaults
 STR_DEFAULT_PASSWORD             = 'admin';
 SHUTDOWN_BATTERY_PERCENT_DEFAULT = 15;
 SHUTDOWN_DELAY_SECONDS_DEFAULT   = 120;
 SHUTDOWN_DELAY_SECONDS_MAX       = 7200;
 AUTH_SESSION_TTL_SECONDS         = 12 * 60 * 60;
 HISTORY_MAX_POINTS               = 720; // ~1 hour at 5s poll

 // Topology JSON values
 STR_TOPOLOGY_UNKNOWN                   = 'unknown';
 STR_TOPOLOGY_SINGLE_PHASE              = 'single_phase';
 STR_TOPOLOGY_THREE_PHASE_IN_OUT        = 'three_phase_in_out';
 STR_TOPOLOGY_THREE_PHASE_IN_SINGLE_OUT = 'three_phase_in_single_out';

 // Battery status JSON values
 STR_BATTERY_STATUS_UNKNOWN  = 'unknown';
 STR_BATTERY_STATUS_NORMAL   = 'battery_normal';
 STR_BATTERY_STATUS_LOW      = 'battery_low';
 STR_BATTERY_STATUS_DEPLETED = 'battery_depleted';

 // API / auth error messages
 STR_ERR_UNAUTHORIZED               = 'Unauthorized';
 STR_ERR_INVALID_JSON_BODY          = 'Invalid JSON body';
 STR_ERR_BODY_MUST_BE_JSON_OBJECT   = 'Body must be a JSON object';
 STR_ERR_EMPTY_JSON_BODY            = 'Empty JSON body';
 STR_ERR_PASSWORD_REQUIRED          = 'Password is required';
 STR_ERR_INVALID_PASSWORD           = 'Invalid password';
 STR_ERR_OLD_PASSWORD_REQUIRED      = 'Old password is required';
 STR_ERR_NEW_PASSWORD_REQUIRED      = 'New password is required';
 STR_ERR_NEW_PASSWORD_TOO_SHORT     = 'New password must be at least 4 characters';
 STR_ERR_CURRENT_PASSWORD_INCORRECT = 'Current password is incorrect';
 STR_ERR_METHOD_NOT_ALLOWED         = 'Method Not Allowed';
 STR_ERR_NOT_FOUND                  = 'Not Found';
 STR_ERR_INVALID_JSON_BODY_SETTINGS = 'Invalid JSON body for settings';
 STR_ERR_SNMP_VERSION               = 'snmp_version must be "1" or "2c"';
 STR_ERR_HTTP_BIND                  = 'Cannot bind HTTP port %d. Another ' + STR_APP_NAME + ' instance may be running. %s';
 STR_ERR_SNMP_GET                   = 'SNMP GET failed: %s';
 STR_ERR_DISCOVER_BUSY              = 'Device discovery is already running';
 STR_ERR_DISCOVER_FAILED            = 'Device discovery failed: %s';
 STR_ERR_INTERNAL                   = 'Internal server error';

 // Console / debug messages
 STR_MSG_CONSOLE_MODE             = STR_APP_NAME + ' console mode';
 STR_MSG_VERSION                  = 'Version: %s';
 STR_MSG_CONFIG_FILE_PREFIX       = 'Config file: ';
 STR_MSG_WEB                      = 'http://localhost:%d';
 STR_MSG_STOP_HINT                = 'Stop: Ctrl+C / SIGTERM';
 STR_MSG_SHUTDOWN_WARNING_EN      = STR_APP_NAME + ': low UPS battery. The computer will shut down';
 STR_MSG_SHUTDOWN_WARNING_RU      = STR_APP_NAME + ': низкий заряд ИБП. Компьютер будет выключен';
 STR_MSG_SHUTDOWN_SCHEDULED_DEBUG = '[' + STR_APP_NAME + '] Shutdown threshold reached - OS shutdown schedule skipped in DEBUG build (delay %d s)';
 STR_MSG_SHUTDOWN_ABORT_DEBUG     = '[' + STR_APP_NAME + '] Mains restored - OS shutdown abort skipped in DEBUG build';
 STR_SERVICE_DISPLAY_NAME         = STR_APP_NAME + ' UPS SNMP Agent';
 STR_SERVICE_DESCRIPTION          = 'SNMP UPS monitor, HTTP API and web UI for SKUP cards. Shuts down the PC on low battery';

 // RFC 1628 UPS-MIB (IETF / NUT ietf)
 // Base: 1.3.6.1.2.1.33.1
 OID_UPS_MIB = '1.3.6.1.2.1.33.1';

 // Ident
 OID_upsIdentManufacturer       = OID_UPS_MIB + '.1.1.0';
 OID_upsIdentModel              = OID_UPS_MIB + '.1.2.0';
 OID_upsIdentUPSSoftwareVersion = OID_UPS_MIB + '.1.3.0';
 OID_upsIdentName               = OID_UPS_MIB + '.1.5.0';
 OID_upsIdentAttachedDevices    = OID_UPS_MIB + '.1.6.0';

 // Battery
 OID_upsBatteryStatus             = OID_UPS_MIB + '.2.1.0';
 OID_upsSecondsOnBattery          = OID_UPS_MIB + '.2.2.0';
 OID_upsEstimatedMinutesRemaining = OID_UPS_MIB + '.2.3.0';
 OID_upsEstimatedChargeRemaining  = OID_UPS_MIB + '.2.4.0';
 OID_upsBatteryVoltage            = OID_UPS_MIB + '.2.5.0';

 // Input
 OID_upsInputNumLines = OID_UPS_MIB + '.3.2.0';
 // upsInputFrequency / Voltage indexed by line: ...3.3.1.2|3.<line>
 OID_upsInputFrequencyBase = OID_UPS_MIB + '.3.3.1.2.';
 OID_upsInputVoltageBase   = OID_UPS_MIB + '.3.3.1.3.';

 // Output
 OID_upsOutputFrequency = OID_UPS_MIB + '.4.2.0';
 OID_upsOutputNumLines  = OID_UPS_MIB + '.4.3.0';
 // upsOutputVoltage / Power / PercentLoad indexed by line
 OID_upsOutputVoltageBase     = OID_UPS_MIB + '.4.4.1.2.';
 OID_upsOutputPowerBase       = OID_UPS_MIB + '.4.4.1.4.';
 OID_upsOutputPercentLoadBase = OID_UPS_MIB + '.4.4.1.5.';

 // UPS SNMP card device codes (UDP discover reply DeviceID)
 DEVICE_CODE_SKUP_8        = 74;
 DEVICE_CODE_SKUP_11       = 76;
 DEVICE_CODE_SNC_S2        = 78;
 DEVICE_CODE_SKUP_11_M     = 79;
 DEVICE_CODE_SKUP_8_M      = 80;
 DEVICE_CODE_PCK_SMARTCARD = 82;

function DiscoverDeviceTypeName(pDeviceCode: Integer): string;
function IsValidSnmpVersion(const pVersion: string): Boolean;
function NormalizeSnmpVersion(const pVersion: string): string;
function SnmpVersionToWire(const pVersion: string): Integer;
function ShutdownWarningMessage: string;

implementation

uses
 System.SysUtils{$IFDEF MSWINDOWS}, Winapi.Windows{$ENDIF};

function IsValidSnmpVersion(const pVersion: string): Boolean;
 var
  v: string;

 begin
  v := LowerCase(Trim(pVersion));
  Result := (v = STR_SNMP_VERSION_1) or (v = STR_SNMP_VERSION_2C) or (v = '2');
 end;

function NormalizeSnmpVersion(const pVersion: string): string;
 var
  v: string;

 begin
  v := LowerCase(Trim(pVersion));

  if (v = STR_SNMP_VERSION_2C) or (v = '2') then
   Result := STR_SNMP_VERSION_2C
  else
   Result := STR_SNMP_VERSION_1;
 end;

function SnmpVersionToWire(const pVersion: string): Integer;
 begin
  if NormalizeSnmpVersion(pVersion) = STR_SNMP_VERSION_2C then
   Result := SNMP_WIRE_VERSION_2C
  else
   Result := SNMP_WIRE_VERSION_1;
 end;

function DiscoverDeviceTypeName(pDeviceCode: Integer): string;
 begin
  case pDeviceCode of
   DEVICE_CODE_SKUP_8:
    Result := 'SKUP-8';

   DEVICE_CODE_SKUP_11:
    Result := 'SKUP-11';

   DEVICE_CODE_SNC_S2:
    Result := 'SNC-S2';

   DEVICE_CODE_SKUP_11_M:
    Result := 'SKUP-11M';

   DEVICE_CODE_SKUP_8_M:
    Result := 'SKUP-8M';

   DEVICE_CODE_PCK_SMARTCARD:
    Result := 'PCK-SMARTCARD';
  else
   Result := '';
  end;
 end;

function ShutdownWarningMessage: string;
{$IFDEF MSWINDOWS}
 begin
  if PRIMARYLANGID(GetSystemDefaultUILanguage) = LANG_RUSSIAN then
   Result := STR_MSG_SHUTDOWN_WARNING_RU
  else
   Result := STR_MSG_SHUTDOWN_WARNING_EN;
 end;
{$ELSE}
 var
  Lang: string;

 begin
  Lang := GetEnvironmentVariable('LC_ALL');

  if Lang = '' then
   Lang := GetEnvironmentVariable('LC_MESSAGES');

  if Lang = '' then
   Lang := GetEnvironmentVariable('LANG');

  if Lang.ToLower.StartsWith('ru') then
   Result := STR_MSG_SHUTDOWN_WARNING_RU
  else
   Result := STR_MSG_SHUTDOWN_WARNING_EN;
 end;
{$ENDIF}

end.
