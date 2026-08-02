program SkupLinkTray;

uses
 Vcl.Forms,
 System.SysUtils,
 Winapi.Windows,
 Common in 'Common.pas',
 uApiModels in 'uApiModels.pas',
 uMain in 'uMain.pas' {FormTray};

var
 Mutex: THandle;

begin
{$IFDEF DEBUG}
 ReportMemoryLeaksOnShutdown := TRUE;
{$ENDIF}

 Mutex := CreateMutex(nil, TRUE, PChar(STR_MUTEX_NAME));

 if (Mutex = 0) or (GetLastError = ERROR_ALREADY_EXISTS) then
  begin
   if Mutex <> 0 then
    CloseHandle(Mutex);
   Exit;
  end;

 try
  Application.Initialize;
  Application.MainFormOnTaskbar := FALSE;
  Application.ShowMainForm := FALSE;
  Application.Title := STR_APP_TITLE;
  Application.CreateForm(TFormTray, FormTray);
  Application.Run;
 finally
  CloseHandle(Mutex);
 end;
end.
