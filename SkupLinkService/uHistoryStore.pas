unit uHistoryStore;

// In-memory ring buffer of polled UPS metrics for web charts.

interface

uses
 System.SysUtils,
 System.Classes,
 System.SyncObjs,
 Common;

type
 THistorySample = record
 public
  Ts:             TDateTime;
  InputCount:     Integer;
  OutputCount:    Integer;
  InputVoltage:   array [0 .. 2] of Double;
  OutputVoltage:  array [0 .. 2] of Double;
  LoadPercent:    array [0 .. 2] of Double;
  BatteryVoltage: Double;
  ChargePercent:  Double;
 end;

 THistoryStore = class
 private
  FLock:    TCriticalSection;
  FSamples: TArray<THistorySample>;
  FCount:   Integer;
  FHead:    Integer;
  class function CopyDoubles(const pValues: array of Double; pCount: Integer): TArray<Double>; static;
 public
  constructor Create;
  destructor Destroy; override;

  procedure Add(const pSample: THistorySample);
  function ToJson: string;
 end;

implementation

uses
 System.DateUtils,
 REST.Json,
 uUpsModels;

constructor THistoryStore.Create;
 begin
  inherited Create;
  FLock := TCriticalSection.Create;
  SetLength(FSamples, HISTORY_MAX_POINTS);
  FCount := 0;
  FHead := 0;
 end;

destructor THistoryStore.Destroy;
 begin
  FLock.Free;
  inherited Destroy;
 end;

procedure THistoryStore.Add(const pSample: THistorySample);
 begin
  FLock.Enter;

  try
   FSamples[FHead] := pSample;
   FHead := (FHead + 1) mod HISTORY_MAX_POINTS;

   if FCount < HISTORY_MAX_POINTS then
    Inc(FCount);
  finally
   FLock.Leave;
  end;
 end;

class function THistoryStore.CopyDoubles(const pValues: array of Double; pCount: Integer): TArray<Double>;
 var
  n: Integer;

 begin
  n := pCount;

  if n > Length(pValues) then
   n := Length(pValues);

  SetLength(Result, n);

  for var i := 0 to n - 1 do
   Result[i] := pValues[i];
 end;

function THistoryStore.ToJson: string;
 var
  History: TUpsHistory;
  Item:    TUpsHistorySample;
  Index:   Integer;
  Start:   Integer;

 begin
  History := TUpsHistory.Create;

  try
   FLock.Enter;

   try
    if FCount < HISTORY_MAX_POINTS then
     Start := 0
    else
     Start := FHead;

    for var i := 0 to FCount - 1 do
     begin
      Index := (Start + i) mod HISTORY_MAX_POINTS;
      Item := History.AddSample;
      Item.ts := DateToISO8601(FSamples[Index].Ts, TRUE);
      Item.input_voltages := CopyDoubles(FSamples[Index].InputVoltage, FSamples[Index].InputCount);
      Item.output_voltages := CopyDoubles(FSamples[Index].OutputVoltage, FSamples[Index].OutputCount);
      Item.load_percents := CopyDoubles(FSamples[Index].LoadPercent, FSamples[Index].OutputCount);
      Item.battery_voltage := FSamples[Index].BatteryVoltage;
      Item.charge_percent := FSamples[Index].ChargePercent;
     end;
   finally
    FLock.Leave;
   end;

   Result := TJson.ObjectToJsonString(History);
  finally
   History.Free;
  end;
 end;

end.
