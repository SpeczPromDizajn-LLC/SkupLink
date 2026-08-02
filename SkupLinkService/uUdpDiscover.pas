unit uUdpDiscover;

// UDP broadcast discovery of Kortex-compatible devices (query 'I' on port 51847).
// Sends to every local subnet broadcast address (multi-NIC / VPN), collects replies.

interface

uses
 System.SysUtils,
 System.Classes,
 System.SyncObjs,
 System.Generics.Collections,
 IdGlobal,
 IdSocketHandle,
 IdUDPServer,
 Common;

type
 TDiscoveredDevice = record
 public
  IP:       string;
  Version:  string;
  Rev:      string;
  MAC:      string;
  UID:      UInt64;
  DeviceID: Integer;
  function DisplayName: string;
 end;

 TUdpDiscover = class
 private
  FLock:     TCriticalSection;
  FScanLock: TCriticalSection;
  FDevices:  TList<TDiscoveredDevice>;
  procedure AddOrUpdate(const pIP, pPayload: string);
  procedure HandleUDPRead(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
  function DevicesToJson(const pBroadcasts: TArray<string>): string;
  class function DecodeStrInfo(const pStr: string; out pVersion, pRev, pMAC: string; out pUID: UInt64; out pDeviceID: Integer): Boolean; static;
 public
  constructor Create;
  destructor Destroy; override;

  function Scan: string;
 end;

implementation

uses
 System.Diagnostics,
 REST.Json,
 uApiModels,
 uNetInterfaces;

function TDiscoveredDevice.DisplayName: string;
 begin
  Result := DiscoverDeviceTypeName(DeviceID);

  if Result = '' then
   Result := IP;
 end;

constructor TUdpDiscover.Create;
 begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FScanLock := TCriticalSection.Create;
  FDevices := TList<TDiscoveredDevice>.Create;
 end;

destructor TUdpDiscover.Destroy;
 begin
  FDevices.Free;
  FScanLock.Free;
  FLock.Free;
  inherited Destroy;
 end;

class function TUdpDiscover.DecodeStrInfo(const pStr: string; out pVersion, pRev, pMAC: string; out pUID: UInt64; out pDeviceID: Integer): Boolean;
 var
  ss: TArray<string>;

 begin
  Result := TRUE;
  pVersion := '';
  pRev := #0;
  pMAC := '';
  pUID := 0;
  pDeviceID := 0;

  ss := pStr.Split(['&', ','], 9);

  case Length(ss) of
   9, 8, 7, 6:
    begin
     pVersion := ss[0];
     pMAC := ss[2];
     pUID := UInt64(StrToInt64Def(ss[3], 0));
     pDeviceID := StrToIntDef(ss[4], 0);
     pRev := ss[5];
    end;

   5:
    begin
     pVersion := ss[0];
     pMAC := ss[2];
     pUID := UInt64(StrToInt64Def(ss[3], 0));
     pDeviceID := StrToIntDef(ss[4], 0);
     pRev := #0;
    end;

   4:
    begin
     pVersion := ss[0];
     pMAC := ss[2];
     pUID := UInt64(StrToInt64Def(ss[3], 0));
    end;

   3:
    begin
     pVersion := ss[0];
     pMAC := ss[2];
    end;

  else
   Result := FALSE;
  end;
 end;

procedure TUdpDiscover.AddOrUpdate(const pIP, pPayload: string);
 var
  Version, Rev, MAC: string;
  UID:               UInt64;
  DeviceID:          Integer;
  Item:              TDiscoveredDevice;
  i:                 Integer;

 begin
  if (pIP = '') or not DecodeStrInfo(pPayload, Version, Rev, MAC, UID, DeviceID) then
   Exit;

  if DiscoverDeviceTypeName(DeviceID) = '' then
   Exit;

  Item.IP := pIP;
  Item.Version := Version;
  Item.Rev := Rev;
  Item.MAC := MAC;
  Item.UID := UID;
  Item.DeviceID := DeviceID;

  FLock.Enter;

  try
   for i := 0 to FDevices.Count - 1 do
    if SameText(FDevices[i].IP, pIP) then
     begin
      FDevices[i] := Item;
      Exit;
     end;

   FDevices.Add(Item);
  finally
   FLock.Leave;
  end;
 end;

procedure TUdpDiscover.HandleUDPRead(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
 begin
  AddOrUpdate(ABinding.PeerIP, BytesToString(AData));
 end;

function TUdpDiscover.DevicesToJson(const pBroadcasts: TArray<string>): string;
 var
  Resp: TApiDiscoverResponse;
  Dev:  TApiDiscoverDevice;
  Item: TDiscoveredDevice;

 begin
  Resp := TApiDiscoverResponse.Create;

  try
   FLock.Enter;

   try
    for var i := 0 to FDevices.Count - 1 do
     begin
      Item := FDevices[i];
      Dev := Resp.AddDevice;
      Dev.ip := Item.IP;
      Dev.name := Item.DisplayName;
      Dev.version := Item.Version;

      if (Item.Rev <> '') and (Item.Rev <> #0) then
       Dev.rev := Item.Rev
      else
       Dev.rev := '';

      Dev.mac := Item.MAC;

      if Item.UID > 0 then
       Dev.uid := IntToStr(Item.UID)
      else
       Dev.uid := '';

      Dev.device_id := Item.DeviceID;
     end;
   finally
    FLock.Leave;
   end;

   Resp.broadcasts := Copy(pBroadcasts);
   Result := TJson.ObjectToJsonString(Resp);
  finally
   Resp.Free;
  end;
 end;

function TUdpDiscover.Scan: string;
 var
  Server:     TIdUDPServer;
  Broadcasts: TArray<string>;
  Sw:         TStopwatch;
  NextSendMs: Int64;
  i:          Integer;

 begin
  if not FScanLock.TryEnter then
   raise Exception.Create(STR_ERR_DISCOVER_BUSY);

  try
   FLock.Enter;

   try
    FDevices.Clear;
   finally
    FLock.Leave;
   end;

   Broadcasts := EnumBroadcastAddresses;

   Server := TIdUDPServer.Create(nil);

   try
    Server.DefaultPort := UDP_DISCOVER_PORT;
    Server.BroadcastEnabled := TRUE;
    // Console/service has no VCL message loop — without this, OnUDPRead is
    // queued via Synchronize and never runs (KortexUpdate is a Forms app).
    Server.ThreadedEvent := TRUE;
    Server.OnUDPRead := HandleUDPRead;

    try
     Server.Active := TRUE;
    except
     on E: Exception do
      raise Exception.CreateFmt(STR_ERR_DISCOVER_FAILED, [E.Message]);
    end;

    Sw := TStopwatch.StartNew;
    NextSendMs := 0;

    while Sw.ElapsedMilliseconds < UDP_DISCOVER_DURATION_MS do
     begin
      if Sw.ElapsedMilliseconds >= NextSendMs then
       begin
        for i := 0 to High(Broadcasts) do
         try
          Server.Send(Broadcasts[i], UDP_DISCOVER_PORT, UDP_DISCOVER_QUERY);
         except
          on E: Exception do
           DebugLogSilentExcept('TUdpDiscover.Scan.Send', E.Message);
         end;

        NextSendMs := Sw.ElapsedMilliseconds + UDP_DISCOVER_SEND_EVERY_MS;
       end;

      Sleep(50);
     end;

    Server.Active := FALSE;
   finally
    Server.Free;
   end;

   Result := DevicesToJson(Broadcasts);
  finally
   FScanLock.Leave;
  end;
 end;

end.
