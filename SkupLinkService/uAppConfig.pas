unit uAppConfig;

// Persistent service settings (JSON file; snake_case keys via F-field names).

interface

uses
 System.SysUtils,
 System.Classes,
 System.SyncObjs,
 Common;

type
 TAppConfigData = class
 private
  Fsnmp_host:                string;
  Fsnmp_community:           string;
  Fsnmp_version:             string;
  Fshutdown_battery_percent: Integer;
  Fshutdown_delay_seconds:   Integer;
  Fpassword_hash:            string;
 public
  constructor Create;

  property snmp_host: string read Fsnmp_host write Fsnmp_host;
  property snmp_community: string read Fsnmp_community write Fsnmp_community;
  property snmp_version: string read Fsnmp_version write Fsnmp_version;
  property shutdown_battery_percent: Integer read Fshutdown_battery_percent write Fshutdown_battery_percent;
  property shutdown_delay_seconds: Integer read Fshutdown_delay_seconds write Fshutdown_delay_seconds;
  property password_hash: string read Fpassword_hash write Fpassword_hash;

  procedure AssignFrom(const pSource: TAppConfigData);
  procedure Normalize;
  // Factory defaults + HashPassword(admin) once. For first-run / corrupt recovery only —
  // never call from Snapshot/Normalize hot paths.
  procedure ResetToFactoryDefaults;
 end;

 TAppConfig = class
 private
  FLock:     TCriticalSection;
  FData:     TAppConfigData;
  FFileName: string;
  function ResolveDefaultFileName: string;
  procedure SaveUnlocked;
  procedure LogConfigNotice(const pMsg: string);
  procedure BackupCorruptConfigFile;
  procedure WriteFactoryDefaultsUnlocked(const pLogMsg: string);
 public
  constructor Create;
  destructor Destroy; override;

  procedure Load;
  procedure UpdateFrom(const pSource: TAppConfigData);

  function Snapshot: TAppConfigData;
  function ToPublicJson: string;
  procedure ApplyJson(const pJson: string);

  property FileName: string read FFileName;
 end;

implementation

uses
 System.IOUtils,
 REST.JSON,
 uApiModels,
 uPasswordHash{$IFDEF MSWINDOWS},
 Winapi.Windows{$ENDIF};

constructor TAppConfigData.Create;
 begin
  inherited Create;
  Fsnmp_host := STR_SNMP_HOST_DEFAULT;
  Fsnmp_community := STR_SNMP_COMMUNITY_DEFAULT;
  Fsnmp_version := STR_SNMP_VERSION_DEFAULT;
  Fshutdown_battery_percent := SHUTDOWN_BATTERY_PERCENT_DEFAULT;
  Fshutdown_delay_seconds := SHUTDOWN_DELAY_SECONDS_DEFAULT;
  // Do not HashPassword here — Snapshot() creates TAppConfigData often (SNMP poll).
  // Default admin hash: ResetToFactoryDefaults (missing/corrupt) or Load (empty hash persist).
  Fpassword_hash := '';
 end;

procedure TAppConfigData.AssignFrom(const pSource: TAppConfigData);
 begin
  if pSource = nil then
   Exit;

  Fsnmp_host := pSource.snmp_host;
  Fsnmp_community := pSource.snmp_community;
  Fsnmp_version := pSource.snmp_version;
  Fshutdown_battery_percent := pSource.shutdown_battery_percent;
  Fshutdown_delay_seconds := pSource.shutdown_delay_seconds;
  Fpassword_hash := pSource.password_hash;
  Normalize;
 end;

procedure TAppConfigData.Normalize;
 begin
  Fsnmp_host := Trim(Fsnmp_host);
  Fsnmp_community := Trim(Fsnmp_community);
  Fsnmp_version := NormalizeSnmpVersion(Fsnmp_version);
  Fpassword_hash := Trim(Fpassword_hash);

  if Fsnmp_host = '' then
   Fsnmp_host := STR_SNMP_HOST_FALLBACK;

  if Fsnmp_community = '' then
   Fsnmp_community := STR_SNMP_COMMUNITY_DEFAULT;

  if (Fshutdown_battery_percent < 1) or (Fshutdown_battery_percent > 99) then
   Fshutdown_battery_percent := SHUTDOWN_BATTERY_PERCENT_DEFAULT;

  if (Fshutdown_delay_seconds < 0) or (Fshutdown_delay_seconds > SHUTDOWN_DELAY_SECONDS_MAX) then
   Fshutdown_delay_seconds := SHUTDOWN_DELAY_SECONDS_DEFAULT;

  // Intentionally no HashPassword here: Snapshot/AssignFrom call Normalize every poll.
 end;

procedure TAppConfigData.ResetToFactoryDefaults;
 begin
  Fsnmp_host := STR_SNMP_HOST_DEFAULT;
  Fsnmp_community := STR_SNMP_COMMUNITY_DEFAULT;
  Fsnmp_version := STR_SNMP_VERSION_DEFAULT;
  Fshutdown_battery_percent := SHUTDOWN_BATTERY_PERCENT_DEFAULT;
  Fshutdown_delay_seconds := SHUTDOWN_DELAY_SECONDS_DEFAULT;
  Fpassword_hash := '';
  Normalize;
  Fpassword_hash := HashPassword(STR_DEFAULT_PASSWORD);
 end;

constructor TAppConfig.Create;
 begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FData := TAppConfigData.Create;
  FFileName := ResolveDefaultFileName;
 end;

destructor TAppConfig.Destroy;
 begin
  FData.Free;
  FLock.Free;
  inherited Destroy;
 end;

function TAppConfig.ResolveDefaultFileName: string;
{$IF not (Defined(MSWINDOWS) and Defined(DEBUG))}
  function TryWriteablePath(const pPath: string): Boolean;
   var
    Dir: string;
   begin
    try
     Dir := TPath.GetDirectoryName(pPath);

     if Dir <> '' then
      ForceDirectories(Dir);

     Result := TDirectory.Exists(Dir) or (Dir = '');
    except
     Result := FALSE;
    end;
   end;

{$ENDIF}

 begin
{$IFDEF MSWINDOWS}
{$IFDEF DEBUG}
  Result := TPath.Combine(GetCurrentDir, STR_CONFIG_FILE_NAME);
{$ELSE}
  Result := TPath.Combine(TPath.Combine(GetEnvironmentVariable(STR_ENV_PROGRAMDATA), STR_CONFIG_APP_FOLDER), STR_CONFIG_FILE_NAME);

  if not TryWriteablePath(Result) then
   Result := TPath.Combine(ExtractFilePath(ParamStr(0)), STR_CONFIG_FILE_NAME);
{$ENDIF}
{$ELSE}
  Result := TPath.Combine(STR_CONFIG_LINUX_DIR, STR_CONFIG_FILE_NAME);

  if not TryWriteablePath(Result) then
   Result := TPath.Combine(ExtractFilePath(ParamStr(0)), STR_CONFIG_FILE_NAME);
{$ENDIF}
 end;

procedure TAppConfig.LogConfigNotice(const pMsg: string);
 begin
{$IFDEF MSWINDOWS}
  OutputDebugString(PChar(pMsg));
{$ENDIF}
{$IFDEF DEBUG}
  Writeln(pMsg);
{$ENDIF}
 end;

procedure TAppConfig.BackupCorruptConfigFile;
 var
  BakName: string;

 begin
  if not TFile.Exists(FFileName) then
   Exit;

  BakName := FFileName + STR_CONFIG_BACKUP_SUFFIX;

  if TFile.Exists(BakName) then
   BakName := FFileName + '.' + FormatDateTime('yyyymmdd_hhnnss', Now) + STR_CONFIG_BACKUP_SUFFIX;

  try
   if TFile.Exists(BakName) then
    TFile.Delete(BakName);

   TFile.Move(FFileName, BakName);
  except
   on EMove: Exception do
    begin
     DebugLogSilentExcept('TAppConfig.BackupCorruptConfigFile.Move', EMove.Message);

     try
      TFile.Copy(FFileName, BakName, TRUE);
      TFile.Delete(FFileName);
     except
      on ECopy: Exception do
       DebugLogSilentExcept('TAppConfig.BackupCorruptConfigFile.Copy', ECopy.Message);
     end;
    end;
  end;
 end;

procedure TAppConfig.WriteFactoryDefaultsUnlocked(const pLogMsg: string);
 begin
  FData.ResetToFactoryDefaults;
  LogConfigNotice(pLogMsg);
  SaveUnlocked;
 end;

procedure TAppConfig.SaveUnlocked;
 var
  JSON: string;
  Dir:  string;

 begin
  FData.Normalize;
  Dir := TPath.GetDirectoryName(FFileName);

  if (Dir <> '') and not TDirectory.Exists(Dir) then
   ForceDirectories(Dir);

  JSON := TJson.ObjectToJsonString(FData);
  TFile.WriteAllText(FFileName, JSON, TEncoding.UTF8);
 end;

procedure TAppConfig.Load;
 var
  JSON:      string;
  Loaded:    TAppConfigData;
  LoadError: string;

 begin
  FLock.Enter;

  try
   if not TFile.Exists(FFileName) then
    begin
     WriteFactoryDefaultsUnlocked(STR_MSG_CONFIG_MISSING_DEFAULTS);
     Exit;
    end;

   Loaded := nil;
   LoadError := '';

   try
    JSON := TFile.ReadAllText(FFileName, TEncoding.UTF8);
    Loaded := TJson.JsonToObject<TAppConfigData>(JSON);

    if Loaded = nil then
     LoadError := 'invalid or empty JSON';
   except
    on E: Exception do
     LoadError := E.Message;
   end;

   if LoadError <> '' then
    begin
     Loaded.Free;
     BackupCorruptConfigFile;
     WriteFactoryDefaultsUnlocked(Format(STR_MSG_CONFIG_CORRUPT_REPAIR, [LoadError]));
     Exit;
    end;

   try
    FData.AssignFrom(Loaded);
   finally
    Loaded.Free;
   end;

   // File parsed OK but password_hash empty: fill admin hash once and persist
   // so the next restart does not repeat the empty-hash state.
   if FData.password_hash = '' then
    begin
     FData.password_hash := HashPassword(STR_DEFAULT_PASSWORD);
     LogConfigNotice(STR_MSG_CONFIG_EMPTY_PASSWORD);
     SaveUnlocked;
    end;
  finally
   FLock.Leave;
  end;
 end;

procedure TAppConfig.UpdateFrom(const pSource: TAppConfigData);
 begin
  FLock.Enter;

  try
   FData.AssignFrom(pSource);
   SaveUnlocked;
  finally
   FLock.Leave;
  end;
 end;

function TAppConfig.Snapshot: TAppConfigData;
 begin
  Result := TAppConfigData.Create;
  FLock.Enter;

  try
   Result.AssignFrom(FData);
  finally
   FLock.Leave;
  end;
 end;

function TAppConfig.ToPublicJson: string;
 var
  Snap: TAppConfigData;
  Pub:  TApiPublicSettings;

 begin
  Snap := Snapshot;
  Pub := TApiPublicSettings.Create;

  try
   Pub.snmp_host := Snap.snmp_host;
   Pub.snmp_community := Snap.snmp_community;
   Pub.snmp_version := Snap.snmp_version;
   Pub.shutdown_battery_percent := Snap.shutdown_battery_percent;
   Pub.shutdown_delay_seconds := Snap.shutdown_delay_seconds;
   Result := TJson.ObjectToJsonString(Pub);
  finally
   Pub.Free;
   Snap.Free;
  end;
 end;

procedure TAppConfig.ApplyJson(const pJson: string);
 var
  Pub:    TApiPublicSettings;
  Merged: TAppConfigData;

 begin
  // Full public settings object from UI. password_hash is not in TApiPublicSettings —
  // it stays from the current config (change via /api/password).
  try
   Pub := TJson.JsonToObject<TApiPublicSettings>(pJson);
  except
   raise Exception.Create(STR_ERR_INVALID_JSON_BODY_SETTINGS);
  end;

  if Pub = nil then
   raise Exception.Create(STR_ERR_INVALID_JSON_BODY_SETTINGS);

  try
   if not IsValidSnmpVersion(Pub.snmp_version) then
    raise Exception.Create(STR_ERR_SNMP_VERSION);

   Merged := Snapshot;

   try
    Merged.snmp_host := Pub.snmp_host;
    Merged.snmp_community := Pub.snmp_community;
    Merged.snmp_version := NormalizeSnmpVersion(Pub.snmp_version);
    Merged.shutdown_battery_percent := Pub.shutdown_battery_percent;
    Merged.shutdown_delay_seconds := Pub.shutdown_delay_seconds;
    UpdateFrom(Merged);
   finally
    Merged.Free;
   end;
  finally
   Pub.Free;
  end;
 end;

end.
