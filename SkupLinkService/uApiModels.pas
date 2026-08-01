unit uApiModels;

// HTTP API models for REST.Json serialization.

interface

uses
 System.SysUtils;

type
 TApiOk = class
 private
  Fok: Boolean;
 public
  constructor Create(pOk: Boolean = TRUE);
  property ok: Boolean read Fok write Fok;
  class function TrueJson: string; static;
 end;

 TApiHealth = class
 private
  Fok:      Boolean;
  Fversion: string;
 public
  constructor Create;
  property ok: Boolean read Fok write Fok;
  property version: string read Fversion write Fversion;
  class function Json: string; static;
 end;

 TApiError = class
 private
  Fok:    Boolean;
  Ferror: string;
 public
  constructor Create(const pError: string);
  property ok: Boolean read Fok write Fok;
  property error: string read Ferror write Ferror;
  class function ToJson(const pError: string): string; static;
 end;

 TApiLoginRequest = class
 private
  Fpassword: string;
 public
  property password: string read Fpassword write Fpassword;
 end;

 TApiLoginResponse = class
 private
  Fok:    Boolean;
  Ftoken: string;
 public
  constructor Create(const pToken: string);
  property ok: Boolean read Fok write Fok;
  property token: string read Ftoken write Ftoken;
 end;

 TApiPasswordRequest = class
 private
  Fold_password: string;
  Fnew_password: string;
 public
  property old_password: string read Fold_password write Fold_password;
  property new_password: string read Fnew_password write Fnew_password;
 end;

 TApiPublicSettings = class
 private
  Fsnmp_host:                string;
  Fsnmp_community:           string;
  Fsnmp_version:             string;
  Fshutdown_battery_percent: Integer;
  Fshutdown_delay_seconds:   Integer;
 public
  property snmp_host: string read Fsnmp_host write Fsnmp_host;
  property snmp_community: string read Fsnmp_community write Fsnmp_community;
  property snmp_version: string read Fsnmp_version write Fsnmp_version;
  property shutdown_battery_percent: Integer read Fshutdown_battery_percent write Fshutdown_battery_percent;
  property shutdown_delay_seconds: Integer read Fshutdown_delay_seconds write Fshutdown_delay_seconds;
 end;

 TApiTrayStatus = class
 private
  Fok:             Boolean;
  Fsnmp_connected: Boolean;
  Fon_battery:     Boolean;
  Fcharge_percent: Integer;
 public
  constructor Create;
  property ok: Boolean read Fok write Fok;
  property snmp_connected: Boolean read Fsnmp_connected write Fsnmp_connected;
  property on_battery: Boolean read Fon_battery write Fon_battery;
  property charge_percent: Integer read Fcharge_percent write Fcharge_percent;
 end;

 TApiDiscoverDevice = class
 private
  Fip:        string;
  Fname:      string;
  Fversion:   string;
  Frev:       string;
  Fmac:       string;
  Fuid:       string;
  Fdevice_id: Integer;
 public
  property ip: string read Fip write Fip;
  property name: string read Fname write Fname;
  property version: string read Fversion write Fversion;
  property rev: string read Frev write Frev;
  property mac: string read Fmac write Fmac;
  property uid: string read Fuid write Fuid;
  property device_id: Integer read Fdevice_id write Fdevice_id;
 end;

 TApiDiscoverResponse = class
 private
  Fok:         Boolean;
  Fdevices:    TArray<TApiDiscoverDevice>;
  Fbroadcasts: TArray<string>;
  procedure FreeDevices;
 public
  constructor Create;
  destructor Destroy; override;
  function AddDevice: TApiDiscoverDevice;
  property ok: Boolean read Fok write Fok;
  property devices: TArray<TApiDiscoverDevice> read Fdevices write Fdevices;
  property broadcasts: TArray<string> read Fbroadcasts write Fbroadcasts;
 end;

implementation

uses
 REST.Json,
 Common;

constructor TApiOk.Create(pOk: Boolean);
 begin
  inherited Create;
  Fok := pOk;
 end;

class function TApiOk.TrueJson: string;
 var
  Obj: TApiOk;

 begin
  Obj := TApiOk.Create(TRUE);

  try
   Result := TJson.ObjectToJsonString(Obj);
  finally
   Obj.Free;
  end;
 end;

constructor TApiHealth.Create;
 begin
  inherited Create;
  Fok := TRUE;
  Fversion := STR_APP_VERSION;
 end;

class function TApiHealth.Json: string;
 var
  Obj: TApiHealth;

 begin
  Obj := TApiHealth.Create;

  try
   Result := TJson.ObjectToJsonString(Obj);
  finally
   Obj.Free;
  end;
 end;

constructor TApiError.Create(const pError: string);
 begin
  inherited Create;
  Fok := FALSE;
  Ferror := pError;
 end;

class function TApiError.ToJson(const pError: string): string;
 var
  Obj: TApiError;

 begin
  Obj := TApiError.Create(pError);

  try
   Result := TJson.ObjectToJsonString(Obj);
  finally
   Obj.Free;
  end;
 end;

constructor TApiLoginResponse.Create(const pToken: string);
 begin
  inherited Create;
  Fok := TRUE;
  Ftoken := pToken;
 end;

constructor TApiTrayStatus.Create;
 begin
  inherited Create;
  Fok := TRUE;
  Fsnmp_connected := FALSE;
  Fon_battery := FALSE;
  Fcharge_percent := -1;
 end;

constructor TApiDiscoverResponse.Create;
 begin
  inherited Create;
  Fok := TRUE;
 end;

destructor TApiDiscoverResponse.Destroy;
 begin
  FreeDevices;
  inherited Destroy;
 end;

procedure TApiDiscoverResponse.FreeDevices;
 begin
  for var i := Low(Fdevices) to High(Fdevices) do
   Fdevices[i].Free;

  SetLength(Fdevices, 0);
 end;

function TApiDiscoverResponse.AddDevice: TApiDiscoverDevice;
 begin
  Result := TApiDiscoverDevice.Create;
  SetLength(Fdevices, Length(Fdevices) + 1);
  Fdevices[High(Fdevices)] := Result;
 end;

end.
