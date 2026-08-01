unit uUpsModels;

// UPS data model for REST.Json serialization.

interface

uses
 System.SysUtils,
 Common;

type
 TUpsTopology = (utUnknown, utSinglePhase, utThreePhaseInOut, utThreePhaseInSingleOut);

 TUpsIdentInfo = class
 private
  Fmanufacturer:     string;
  Fmodel:            string;
  Fsoftware_version: string;
  Fname:             string;
  Fattached_devices: string;
 public
  property manufacturer:     string read Fmanufacturer write Fmanufacturer;
  property model:            string read Fmodel write Fmodel;
  property software_version: string read Fsoftware_version write Fsoftware_version;
  property name:             string read Fname write Fname;
  property attached_devices: string read Fattached_devices write Fattached_devices;
 end;

 TUpsInputPhase = class
 private
  Findex:     Integer;
  Fvoltage:   Double;
  Ffrequency: Double;
 public
  property index:     Integer read Findex write Findex;
  property voltage:   Double read Fvoltage write Fvoltage;
  property frequency: Double read Ffrequency write Ffrequency;
 end;

 TUpsOutputPhase = class
 private
  Findex:        Integer;
  Fvoltage:      Double;
  Ffrequency:    Double;
  Fpercent_load: Double;
  Fpower_watts:  Double;
 public
  property index:   Integer read Findex write Findex;
  property voltage: Double read Fvoltage write Fvoltage;
  property frequency:    Double read Ffrequency write Ffrequency;
  property percent_load: Double read Fpercent_load write Fpercent_load;
  property power_watts:  Double read Fpower_watts write Fpower_watts;
 end;

 TUpsInputInfo = class
 private
  Fphases: TArray<TUpsInputPhase>;
  procedure FreePhases;
 public
  destructor Destroy; override;
  procedure Clear;
  function AddPhase: TUpsInputPhase;
  property phases: TArray<TUpsInputPhase> read Fphases write Fphases;
 end;

 TUpsOutputInfo = class
 private
  Ffrequency:          Double;
  Fphases:             TArray<TUpsOutputPhase>;
  Ftotal_percent_load: Double;
  Ftotal_power_watts:  Double;
  procedure FreePhases;
 public
  destructor Destroy; override;
  procedure Clear;
  function AddPhase: TUpsOutputPhase;
  property frequency: Double read Ffrequency write Ffrequency;
  property phases: TArray<TUpsOutputPhase> read Fphases write Fphases;
  property total_percent_load: Double read Ftotal_percent_load write Ftotal_percent_load;
  property total_power_watts: Double read Ftotal_power_watts write Ftotal_power_watts;
 end;

 TUpsBatteryInfo = class
 private
  Fstatus:                       string;
  Fstatus_code:                  Integer;
  Fvoltage:                      Double;
  Fcharge_percent:               Integer;
  Festimated_minutes_remaining:  Integer;
  Festimated_seconds_remaining:  Integer;
  Fseconds_on_battery:           Integer;
 public
  property status:      string read Fstatus write Fstatus;
  property status_code: Integer read Fstatus_code write Fstatus_code;
  property voltage:     Double read Fvoltage write Fvoltage;
  property charge_percent: Integer read Fcharge_percent write Fcharge_percent;
  property estimated_minutes_remaining: Integer read Festimated_minutes_remaining write Festimated_minutes_remaining;
  property estimated_seconds_remaining: Integer read Festimated_seconds_remaining write Festimated_seconds_remaining;
  property seconds_on_battery: Integer read Fseconds_on_battery write Fseconds_on_battery;
 end;

 TUpsSnapshot = class
 private
  Fident:              TUpsIdentInfo;
  Ftopology:           string;
  Finput_phase_count:  Integer;
  Foutput_phase_count: Integer;
  Finput:              TUpsInputInfo;
  Foutput:             TUpsOutputInfo;
  Fbattery:            TUpsBatteryInfo;
  Fsnmp_connected:     Boolean;
 public
  constructor Create;
  destructor Destroy; override;
  class function TopologyToString(pValue: TUpsTopology): string; static;
  class function DetectTopology(pInLines, pOutLines: Integer): TUpsTopology; static;
  class function BatteryStatusToString(pCode: Integer): string; static;
  property ident: TUpsIdentInfo read Fident write Fident;
  property topology: string read Ftopology write Ftopology;
  property input_phase_count: Integer read Finput_phase_count write Finput_phase_count;
  property output_phase_count: Integer read Foutput_phase_count write Foutput_phase_count;
  property input: TUpsInputInfo read Finput write Finput;
  property output: TUpsOutputInfo read Foutput write Foutput;
  property battery: TUpsBatteryInfo read Fbattery write Fbattery;
  property snmp_connected: Boolean read Fsnmp_connected write Fsnmp_connected;
 end;

 TUpsHistorySample = class
 private
  Fts:              string;
  Finput_voltages:  TArray<Double>;
  Foutput_voltages: TArray<Double>;
  Fload_percents:   TArray<Double>;
  Fbattery_voltage: Double;
  Fcharge_percent:  Double;
 public
  property ts: string read Fts write Fts;
  property input_voltages: TArray<Double> read Finput_voltages write Finput_voltages;
  property output_voltages: TArray<Double> read Foutput_voltages write Foutput_voltages;
  property load_percents: TArray<Double> read Fload_percents write Fload_percents;
  property battery_voltage: Double read Fbattery_voltage write Fbattery_voltage;
  property charge_percent: Double read Fcharge_percent write Fcharge_percent;
 end;

 TUpsHistory = class
 private
  Fsamples: TArray<TUpsHistorySample>;
  procedure FreeSamples;
 public
  destructor Destroy; override;
  function AddSample: TUpsHistorySample;
  property samples: TArray<TUpsHistorySample> read Fsamples write Fsamples;
 end;

implementation

destructor TUpsInputInfo.Destroy;
 begin
  FreePhases;
  inherited Destroy;
 end;

procedure TUpsInputInfo.FreePhases;
 begin
  for var i := Low(Fphases) to High(Fphases) do
   Fphases[i].Free;

  SetLength(Fphases, 0);
 end;

procedure TUpsInputInfo.Clear;
 begin
  FreePhases;
 end;

function TUpsInputInfo.AddPhase: TUpsInputPhase;
 begin
  Result := TUpsInputPhase.Create;
  SetLength(Fphases, Length(Fphases) + 1);
  Fphases[High(Fphases)] := Result;
 end;

destructor TUpsOutputInfo.Destroy;
 begin
  FreePhases;
  inherited Destroy;
 end;

procedure TUpsOutputInfo.FreePhases;
 begin
  for var i := Low(Fphases) to High(Fphases) do
   Fphases[i].Free;

  SetLength(Fphases, 0);
 end;

procedure TUpsOutputInfo.Clear;
 begin
  FreePhases;
  Ffrequency := 0;
  Ftotal_percent_load := 0;
  Ftotal_power_watts := 0;
 end;

function TUpsOutputInfo.AddPhase: TUpsOutputPhase;
 begin
  Result := TUpsOutputPhase.Create;
  SetLength(Fphases, Length(Fphases) + 1);
  Fphases[High(Fphases)] := Result;
 end;

constructor TUpsSnapshot.Create;
 begin
  inherited Create;
  Fident := TUpsIdentInfo.Create;
  Finput := TUpsInputInfo.Create;
  Foutput := TUpsOutputInfo.Create;
  Fbattery := TUpsBatteryInfo.Create;
  Ftopology := TopologyToString(utUnknown);
  Fsnmp_connected := FALSE;
 end;

destructor TUpsSnapshot.Destroy;
 begin
  Fbattery.Free;
  Foutput.Free;
  Finput.Free;
  Fident.Free;
  inherited Destroy;
 end;

class function TUpsSnapshot.TopologyToString(pValue: TUpsTopology): string;
 begin
  case pValue of
   utSinglePhase:
    Result := STR_TOPOLOGY_SINGLE_PHASE;

   utThreePhaseInOut:
    Result := STR_TOPOLOGY_THREE_PHASE_IN_OUT;

   utThreePhaseInSingleOut:
    Result := STR_TOPOLOGY_THREE_PHASE_IN_SINGLE_OUT;
  else
   Result := STR_TOPOLOGY_UNKNOWN;
  end;
 end;

class function TUpsSnapshot.DetectTopology(pInLines, pOutLines: Integer): TUpsTopology;
 begin
  if (pInLines <= 1) and (pOutLines <= 1) then
   Result := utSinglePhase
  else
   begin
    if (pInLines >= 3) and (pOutLines >= 3) then
     Result := utThreePhaseInOut
    else
     begin
      if (pInLines >= 3) and (pOutLines <= 1) then
       Result := utThreePhaseInSingleOut
      else
       Result := utUnknown;
     end;
   end;
 end;

class function TUpsSnapshot.BatteryStatusToString(pCode: Integer): string;
 begin
  case pCode of
   1:
    Result := STR_BATTERY_STATUS_UNKNOWN;

   2:
    Result := STR_BATTERY_STATUS_NORMAL;

   3:
    Result := STR_BATTERY_STATUS_LOW;

   4:
    Result := STR_BATTERY_STATUS_DEPLETED;
  else
   Result := STR_BATTERY_STATUS_UNKNOWN;
  end;
 end;

destructor TUpsHistory.Destroy;
 begin
  FreeSamples;
  inherited Destroy;
 end;

procedure TUpsHistory.FreeSamples;
 begin
  for var i := Low(Fsamples) to High(Fsamples) do
   Fsamples[i].Free;

  SetLength(Fsamples, 0);
 end;

function TUpsHistory.AddSample: TUpsHistorySample;
 begin
  Result := TUpsHistorySample.Create;
  SetLength(Fsamples, Length(Fsamples) + 1);
  Fsamples[High(Fsamples)] := Result;
 end;

end.
