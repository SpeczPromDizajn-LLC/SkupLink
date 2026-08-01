unit uShutdownWatch;

interface

uses
 System.SysUtils,
 System.Classes,
 System.SyncObjs,
 Common,
 uAppConfig,
 uUpsModels;

type
 TShutdownWatch = class
 private
  FConfig:  TAppConfig;
  FLock:    TCriticalSection;
  FPending: Boolean;
  procedure EnableShutdownPrivilege;
  function ScheduleOsShutdown(pDelaySeconds: Integer): Boolean;
  function AbortOsShutdown: Boolean;
  procedure ClearPending;
 public
  constructor Create(pConfig: TAppConfig);
  destructor Destroy; override;

  procedure Evaluate(pSnap: TUpsSnapshot);
 end;

implementation

{$IFDEF MSWINDOWS}
uses
 Winapi.Windows;
{$ELSE}
uses
 Posix.Stdlib;
{$ENDIF}

constructor TShutdownWatch.Create(pConfig: TAppConfig);
 begin
  inherited Create;
  FConfig := pConfig;
  FLock := TCriticalSection.Create;
  FPending := FALSE;
 end;

destructor TShutdownWatch.Destroy;
 begin
  FLock.Free;
  inherited Destroy;
 end;

procedure TShutdownWatch.EnableShutdownPrivilege;
{$IFDEF MSWINDOWS}
 var
  Token:      THandle;
  Privileges: TTokenPrivileges;
  Len:        DWORD;
{$ENDIF}
 begin
{$IFDEF MSWINDOWS}
  if not OpenProcessToken(GetCurrentProcess, TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, Token) then
   Exit;

  try
   if LookupPrivilegeValue(nil, 'SeShutdownPrivilege', Privileges.Privileges[0].Luid) then
    begin
     Privileges.PrivilegeCount := 1;
     Privileges.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;
     AdjustTokenPrivileges(Token, FALSE, Privileges, 0, nil, Len);
    end;
  finally
   CloseHandle(Token);
  end;
{$ENDIF}
 end;

function TShutdownWatch.ScheduleOsShutdown(pDelaySeconds: Integer): Boolean;
 var
  Msg: string;
{$IFNDEF MSWINDOWS}
  Mins: Integer;
  Cmd:  string;
{$ENDIF}
 begin
  Msg := ShutdownWarningMessage;
{$IFDEF DEBUG}
  Writeln(Format(STR_MSG_SHUTDOWN_SCHEDULED_DEBUG, [pDelaySeconds]));
  Result := TRUE;
{$ELSE}
{$IFDEF MSWINDOWS}
  // API may write into the message buffer — keep a unique writable string.
  UniqueString(Msg);
  EnableShutdownPrivilege;
  Result := InitiateSystemShutdown(nil, PChar(Msg), DWORD(pDelaySeconds), TRUE, FALSE);
{$ELSE}
  // util-linux shutdown uses minutes (+m). Round seconds up; 0 => now.
  if pDelaySeconds <= 0 then
   Cmd := Format('/sbin/shutdown -h now "%s"', [Msg])
  else
   begin
    Mins := (pDelaySeconds + 59) div 60;

    if Mins < 1 then
     Mins := 1;

    Cmd := Format('/sbin/shutdown -h +%d "%s"', [Mins, Msg]);
   end;

  Result := _system(MarshaledAString(UTF8String(Cmd))) = 0;
{$ENDIF}
{$ENDIF}
 end;

function TShutdownWatch.AbortOsShutdown: Boolean;
 begin
{$IFDEF DEBUG}
  Writeln(STR_MSG_SHUTDOWN_ABORT_DEBUG);
  Result := TRUE;
{$ELSE}
{$IFDEF MSWINDOWS}
  EnableShutdownPrivilege;
  Result := AbortSystemShutdown(nil);
{$ELSE}
  Result := _system(MarshaledAString(UTF8String('/sbin/shutdown -c'))) = 0;
{$ENDIF}
{$ENDIF}
 end;

procedure TShutdownWatch.ClearPending;
 begin
  FLock.Enter;

  try
   FPending := FALSE;
  finally
   FLock.Leave;
  end;
 end;

procedure TShutdownWatch.Evaluate(pSnap: TUpsSnapshot);
 var
  Cfg:     TAppConfigData;
  Pending: Boolean;

 begin
  if not pSnap.snmp_connected then
   Exit;

  if pSnap.battery.seconds_on_battery <= 0 then
   begin
    FLock.Enter;

    try
     Pending := FPending;
    finally
     FLock.Leave;
    end;

    if Pending then
     AbortOsShutdown;

    ClearPending;
    Exit;
   end;

  if pSnap.battery.charge_percent < 0 then
   Exit;

  Cfg := FConfig.Snapshot;

  try
   if pSnap.battery.charge_percent > Cfg.shutdown_battery_percent then
    Exit;

   FLock.Enter;

   try
    if FPending then
     Exit;
   finally
    FLock.Leave;
   end;

   if not ScheduleOsShutdown(Cfg.shutdown_delay_seconds) then
    Exit;

   FLock.Enter;

   try
    FPending := TRUE;
   finally
    FLock.Leave;
   end;
  finally
   Cfg.Free;
  end;
 end;

end.
