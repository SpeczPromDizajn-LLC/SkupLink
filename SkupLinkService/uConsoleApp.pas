unit uConsoleApp;

interface

procedure RunConsoleMode;

implementation

uses
 System.SysUtils,
{$IFDEF MSWINDOWS}
 Winapi.Windows,
{$ENDIF}
{$IFDEF POSIX}
 Posix.Signal,
{$ENDIF}
 Common,
 uServiceHost;

var
 GHost: TServiceHost = nil;

{$IFDEF MSWINDOWS}

function ConsoleCtrlHandler(CtrlType: DWORD): BOOL; stdcall;
 begin
  Result := TRUE;

  if GHost <> nil then
   GHost.RequestStop;
 end;
{$ENDIF}
{$IFDEF POSIX}

procedure PosixSignalHandler(SigNum: Integer); cdecl;
 begin
  if GHost <> nil then
   GHost.RequestStop;
 end;
{$ENDIF}

procedure RunConsoleMode;
{$IFDEF POSIX}
 var
  Action: sigaction_t;
{$ENDIF}
 begin
{$IFDEF MSWINDOWS}
  SetConsoleCtrlHandler(@ConsoleCtrlHandler, TRUE);
{$ENDIF}
{$IFDEF POSIX}
  FillChar(Action, SizeOf(Action), 0);
  Action._u.sa_handler := PosixSignalHandler;
  sigemptyset(Action.sa_mask);
  sigaction(SIGINT, @Action, nil);
  sigaction(SIGTERM, @Action, nil);
{$ENDIF}
  GHost := TServiceHost.Create;

  try
   Writeln(STR_MSG_CONSOLE_MODE);
{$IFDEF DEBUG}
   Writeln(Format(STR_MSG_VERSION, [STR_APP_VERSION]));
{$ENDIF}
   Writeln(STR_MSG_CONFIG_FILE_PREFIX, GHost.Config.FileName);
   Writeln(Format(STR_MSG_WEB, [HTTP_PORT]));
   Writeln(STR_MSG_STOP_HINT);

   GHost.RunUntilStopped;
  finally
   FreeAndNil(GHost);
  end;
 end;

end.
