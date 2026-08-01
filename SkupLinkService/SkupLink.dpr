program SkupLink;

{$IFDEF DEBUG}
{$APPTYPE CONSOLE}
{$ELSE}
{$IFDEF MSWINDOWS}
{$APPTYPE GUI}
{$ELSE}
{$APPTYPE CONSOLE}
{$ENDIF}
{$ENDIF}
// SkupLink — DEBUG=console; RELEASE=Windows service / Linux daemon.

uses
 System.SysUtils,
{$IFDEF MSWINDOWS}
{$IFNDEF DEBUG}
 Vcl.SvcMgr,
 uWinService in 'uWinService.pas' {SkupLinkService: TService} ,
{$ENDIF}
{$ENDIF}
 Common in 'Common.pas',
 uAppConfig in 'uAppConfig.pas',
 uAuth in 'uAuth.pas',
 uHistoryStore in 'uHistoryStore.pas',
 uShutdownWatch in 'uShutdownWatch.pas',
 uSnmpOids in 'uSnmpOids.pas',
 uUpsModels in 'uUpsModels.pas',
 uApiModels in 'uApiModels.pas',
 uSnmpUpsClient in 'uSnmpUpsClient.pas',
 uNetInterfaces in 'uNetInterfaces.pas',
 uUdpDiscover in 'uUdpDiscover.pas',
 uHttpApiServer in 'uHttpApiServer.pas',
 uServiceHost in 'uServiceHost.pas',
 uConsoleApp in 'uConsoleApp.pas';

begin
 ReportMemoryLeaksOnShutdown := TRUE;

 try
{$IFDEF DEBUG}
  RunConsoleMode;
{$ELSE}
{$IFDEF MSWINDOWS}
  if not Application.DelayInitialize or Application.Installing then
   Application.Initialize;

  Application.CreateForm(TSkupLinkService, SkupLinkService);
  Application.Run;
{$ELSE}
  RunConsoleMode;
{$ENDIF}
{$ENDIF}
 except
  on E: Exception do
   Writeln(E.ClassName, ': ', E.Message);
 end;

end.
