unit uApiModels;

// Tray-side /api/tray model (REST.Json).

interface

uses
 System.SysUtils;

type
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

implementation

constructor TApiTrayStatus.Create;
 begin
  inherited Create;
  Fok := TRUE;
  Fsnmp_connected := FALSE;
  Fon_battery := FALSE;
  Fcharge_percent := -1;
 end;

end.
