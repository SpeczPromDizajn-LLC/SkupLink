unit Common;

interface

const
 HTTP_PORT               = 8847;
 TRAY_POLL_INTERVAL_MS   = 3000;
 HTTP_CONNECT_TIMEOUT_MS = 1500;
 HTTP_READ_TIMEOUT_MS    = 1500;

 STR_APP_NAME   = 'SkupLink';
 STR_APP_TITLE  = STR_APP_NAME;
 STR_MUTEX_NAME = 'Local\' + STR_APP_NAME + 'TraySingleton';

 STR_URL_WEB      = 'http://localhost:%d/';
 STR_URL_TRAY_API = 'http://127.0.0.1:%d/api/tray';

 STR_HINT_NO_SNMP    = STR_APP_NAME + ': Нет SNMP';
 STR_HINT_NO_LINK    = STR_APP_NAME + ': Нет связи';
 STR_HINT_CHARGE_NA  = STR_APP_NAME + ': —';
 STR_HINT_CHARGE_FMT = STR_APP_NAME + ': АКБ %d%%';

 STR_MENU_OPEN = 'Открыть Web UI';
 STR_MENU_EXIT = 'Выход';

 // Stable tray identity (Win10/11 remembers show/hide per GUID)
 TRAY_ICON_GUID: TGUID = '{6C2A9E41-8B7D-4F3A-9C1E-2D5B7A90E4F1}';

implementation

end.
