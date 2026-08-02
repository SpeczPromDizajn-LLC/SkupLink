unit uSnmpUpsClient;

// SNMPv1/v2c poller for RFC 1628 UPS-MIB (NUT ietf mapping). Uses Indy TIdSNMP.

interface

uses
 System.SysUtils,
 System.Classes,
 System.SyncObjs,
 IdSNMP,
 IdASN1Util,
 Common,
 uAppConfig,
 uUpsModels,
 uHistoryStore,
 uShutdownWatch;

type
 TSnmpUpsClient = class
 private
  FConfig:   TAppConfig;
  FHistory:  THistoryStore;
  FShutdown: TShutdownWatch;
  FLock:           TCriticalSection;
  FLastJson:       string;
  FPollWireVersion: Integer;

  function GetString(pSNMP: TIdSNMP; const pOID: string; out pValue: string): Boolean;
  function GetInteger(pSNMP: TIdSNMP; const pOID: string; out pValue: Integer): Boolean;
  function RequireString(pSNMP: TIdSNMP; const pOID: string): string;
  function RequireInteger(pSNMP: TIdSNMP; const pOID: string): Integer;
  function ScaleTenths(pRaw: Integer): Double;
  procedure PollInternal(const pCfg: TAppConfigData; pDest: TUpsSnapshot);
  function SnapshotToJson(pSnap: TUpsSnapshot): string;
 public
  constructor Create(pConfig: TAppConfig; pHistory: THistoryStore; pShutdown: TShutdownWatch);
  destructor Destroy; override;

  procedure PollOnce;
  function GetLastJson: string;
  function GetTrayJson: string;
 end;

implementation

uses
 REST.Json,
 uApiModels,
 uSnmpOids;

constructor TSnmpUpsClient.Create(pConfig: TAppConfig; pHistory: THistoryStore; pShutdown: TShutdownWatch);
 var
  Snap: TUpsSnapshot;

 begin
  inherited Create;
  FConfig := pConfig;
  FHistory := pHistory;
  FShutdown := pShutdown;
  FLock := TCriticalSection.Create;
  FPollWireVersion := SNMP_WIRE_VERSION_1;
  Snap := TUpsSnapshot.Create;

  try
   Snap.snmp_connected := FALSE;
   FLastJson := SnapshotToJson(Snap);
  finally
   Snap.Free;
  end;
 end;

destructor TSnmpUpsClient.Destroy;
 begin
  FLock.Free;
  inherited Destroy;
 end;

function TSnmpUpsClient.ScaleTenths(pRaw: Integer): Double;
 begin
  Result := pRaw / 10.0;
 end;

function TSnmpUpsClient.GetString(pSNMP: TIdSNMP; const pOID: string; out pValue: string): Boolean;
 begin
  pValue := '';
  Result := FALSE;

  pSNMP.Query.Clear;
  pSNMP.Query.Version := FPollWireVersion;
  pSNMP.Query.MIBAdd(pOID, '', ASN1_NULL);
  pSNMP.Query.ID := Random(65535) + 1;
  pSNMP.Query.PDUType := PDUGetRequest;

  if not pSNMP.SendQuery then
   Exit;

  if pSNMP.Reply.ValueCount < 1 then
   Exit;

  pValue := pSNMP.Reply.Value[0];
  Result := TRUE;
 end;

function TSnmpUpsClient.GetInteger(pSNMP: TIdSNMP; const pOID: string; out pValue: Integer): Boolean;
 var
  s: string;

 begin
  pValue := 0;
  Result := GetString(pSNMP, pOID, s);

  if not Result then
   Exit;

  Result := TryStrToInt(Trim(s), pValue);
 end;

function TSnmpUpsClient.RequireString(pSNMP: TIdSNMP; const pOID: string): string;
 begin
  if not GetString(pSNMP, pOID, Result) then
   raise Exception.CreateFmt(STR_ERR_SNMP_GET, [pOID]);
 end;

function TSnmpUpsClient.RequireInteger(pSNMP: TIdSNMP; const pOID: string): Integer;
 begin
  if not GetInteger(pSNMP, pOID, Result) then
   raise Exception.CreateFmt(STR_ERR_SNMP_GET, [pOID]);
 end;

procedure TSnmpUpsClient.PollInternal(const pCfg: TAppConfigData; pDest: TUpsSnapshot);
 var
  SNMP:                   TIdSNMP;
  InLines, OutLines, Raw: Integer;
  InPhase:                TUpsInputPhase;
  OutPhase:               TUpsOutputPhase;
  Topology:               TUpsTopology;
  TotalLoad, TotalPower:  Double;

 begin
  pDest.ident.manufacturer := '';
  pDest.ident.model := '';
  pDest.ident.software_version := '';
  pDest.ident.name := '';
  pDest.ident.attached_devices := '';
  pDest.input.Clear;
  pDest.output.Clear;
  pDest.battery.status := STR_BATTERY_STATUS_UNKNOWN;
  pDest.battery.status_code := 1;
  pDest.battery.voltage := 0;
  pDest.battery.charge_percent := -1;
  pDest.battery.estimated_minutes_remaining := 0;
  pDest.battery.estimated_seconds_remaining := 0;
  pDest.battery.seconds_on_battery := 0;
  pDest.input_phase_count := 0;
  pDest.output_phase_count := 0;
  pDest.topology := TUpsSnapshot.TopologyToString(utUnknown);
  pDest.snmp_connected := FALSE;

  FPollWireVersion := SnmpVersionToWire(pCfg.snmp_version);
  SNMP := TIdSNMP.Create(nil);

  try
   // TIdSNMP.GetBinding also binds TrapPort (default 162). That privileged
   // port is unused by us and often fails with EIdCouldNotBindSocket.
   SNMP.TrapPort := 0;
   SNMP.Community := pCfg.snmp_community;
   SNMP.Host := pCfg.snmp_host;
   SNMP.Port := SNMP_PORT;
   SNMP.ReceiveTimeout := SNMP_RECEIVE_TIMEOUT_MS;

   pDest.ident.manufacturer := RequireString(SNMP, OID_upsIdentManufacturer);
   pDest.ident.model := RequireString(SNMP, OID_upsIdentModel);
   pDest.ident.software_version := RequireString(SNMP, OID_upsIdentUPSSoftwareVersion);
   pDest.ident.name := RequireString(SNMP, OID_upsIdentName);
   pDest.ident.attached_devices := RequireString(SNMP, OID_upsIdentAttachedDevices);

   InLines := RequireInteger(SNMP, OID_upsInputNumLines);
   OutLines := RequireInteger(SNMP, OID_upsOutputNumLines);

   if InLines < 1 then
    InLines := 1;

   if OutLines < 1 then
    OutLines := 1;

   if InLines > 3 then
    InLines := 3;

   if OutLines > 3 then
    OutLines := 3;

   pDest.input_phase_count := InLines;
   pDest.output_phase_count := OutLines;
   Topology := TUpsSnapshot.DetectTopology(InLines, OutLines);
   pDest.topology := TUpsSnapshot.TopologyToString(Topology);

   for var line := 1 to InLines do
    begin
     InPhase := pDest.input.AddPhase;
     InPhase.index := line;
     InPhase.voltage := RequireInteger(SNMP, OidInputVoltage(line));
     InPhase.frequency := ScaleTenths(RequireInteger(SNMP, OidInputFrequency(line)));
    end;

   pDest.output.frequency := ScaleTenths(RequireInteger(SNMP, OID_upsOutputFrequency));

   TotalLoad := 0;
   TotalPower := 0;

   for var line := 1 to OutLines do
    begin
     OutPhase := pDest.output.AddPhase;
     OutPhase.index := line;
     OutPhase.voltage := RequireInteger(SNMP, OidOutputVoltage(line));
     OutPhase.frequency := pDest.output.frequency;
     OutPhase.percent_load := RequireInteger(SNMP, OidOutputPercentLoad(line));
     OutPhase.power_watts := RequireInteger(SNMP, OidOutputPower(line));
     TotalLoad := TotalLoad + OutPhase.percent_load;
     TotalPower := TotalPower + OutPhase.power_watts;
    end;

   if OutLines > 0 then
    pDest.output.total_percent_load := TotalLoad / OutLines
   else
    pDest.output.total_percent_load := TotalLoad;

   pDest.output.total_power_watts := TotalPower;

   Raw := RequireInteger(SNMP, OID_upsBatteryStatus);
   pDest.battery.status_code := Raw;
   pDest.battery.status := TUpsSnapshot.BatteryStatusToString(Raw);
   pDest.battery.voltage := ScaleTenths(RequireInteger(SNMP, OID_upsBatteryVoltage));

   if GetInteger(SNMP, OID_upsEstimatedChargeRemaining, Raw) then
    pDest.battery.charge_percent := Raw
   else
    pDest.battery.charge_percent := -1;

   Raw := RequireInteger(SNMP, OID_upsEstimatedMinutesRemaining);
   pDest.battery.estimated_minutes_remaining := Raw;
   pDest.battery.estimated_seconds_remaining := Raw * 60;
   pDest.battery.seconds_on_battery := RequireInteger(SNMP, OID_upsSecondsOnBattery);

   pDest.snmp_connected := TRUE;
  finally
   SNMP.Free;
  end;
 end;

function TSnmpUpsClient.SnapshotToJson(pSnap: TUpsSnapshot): string;
 begin
  Result := TJson.ObjectToJsonString(pSnap);
 end;

procedure TSnmpUpsClient.PollOnce;
 var
  Cfg:    TAppConfigData;
  Snap:   TUpsSnapshot;
  Json:   string;
  Sample: THistorySample;
  N:      Integer;

 begin
  Cfg := FConfig.Snapshot;
  Snap := TUpsSnapshot.Create;

  try
   try
    PollInternal(Cfg, Snap);
   except
    // Drop any mid-poll partial fields; publish a clean offline snapshot.
    Snap.Free;
    Snap := TUpsSnapshot.Create;
    Snap.snmp_connected := FALSE;
   end;

   if Snap.snmp_connected then
    begin
     FillChar(Sample, SizeOf(Sample), 0);
     Sample.Ts := Now;
     Sample.BatteryVoltage := Snap.battery.voltage;
     Sample.ChargePercent := Snap.battery.charge_percent;

     N := Length(Snap.input.phases);

     if N > 3 then
      N := 3;

     Sample.InputCount := N;

     for var i := 0 to N - 1 do
      Sample.InputVoltage[i] := Snap.input.phases[i].voltage;

     N := Length(Snap.output.phases);

     if N > 3 then
      N := 3;

     Sample.OutputCount := N;

     for var i := 0 to N - 1 do
      begin
       Sample.OutputVoltage[i] := Snap.output.phases[i].voltage;
       Sample.LoadPercent[i] := Snap.output.phases[i].percent_load;
      end;

     FHistory.Add(Sample);
    end;

   FShutdown.Evaluate(Snap);
   Json := SnapshotToJson(Snap);

   FLock.Enter;

   try
    FLastJson := Json;
   finally
    FLock.Leave;
   end;
  finally
   Cfg.Free;
   Snap.Free;
  end;
 end;

function TSnmpUpsClient.GetLastJson: string;
 begin
  FLock.Enter;

  try
   Result := FLastJson;
  finally
   FLock.Leave;
  end;
 end;

function TSnmpUpsClient.GetTrayJson: string;
 var
  Snap: TUpsSnapshot;
  Tray: TApiTrayStatus;

 begin
  FLock.Enter;

  try
   Snap := TJson.JsonToObject<TUpsSnapshot>(FLastJson);

   if Snap = nil then
    Snap := TUpsSnapshot.Create;
  finally
   FLock.Leave;
  end;

  Tray := TApiTrayStatus.Create;

  try
   Tray.ok := TRUE;
   Tray.snmp_connected := Snap.snmp_connected;
   Tray.on_battery := Snap.snmp_connected and (Snap.battery.seconds_on_battery > 0);
   Tray.charge_percent := Snap.battery.charge_percent;
   Result := TJson.ObjectToJsonString(Tray);
  finally
   Tray.Free;
   Snap.Free;
  end;
 end;

end.
