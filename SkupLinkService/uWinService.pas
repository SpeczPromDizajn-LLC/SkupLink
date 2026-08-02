unit uWinService;

{$IFDEF MSWINDOWS}

interface

uses
 Winapi.Windows,
 System.SysUtils,
 System.Classes,
 System.Win.Registry,
 Vcl.SvcMgr,
 Common,
 uServiceHost;

type
 TSkupLinkService = class(TService)
  procedure ServiceCreate(Sender: TObject);
  procedure ServiceAfterInstall(Sender: TService);
  procedure ServiceStart(Sender: TService; var Started: Boolean);
  procedure ServiceStop(Sender: TService; var Stopped: Boolean);
  procedure ServiceShutdown(Sender: TService);
 private
  FHost: TServiceHost;
 public
  function GetServiceController: TServiceController; override;
 end;

var
 SkupLinkService: TSkupLinkService;

implementation

{$R *.dfm}

procedure ServiceController(CtrlCode: DWord); stdcall;
 begin
  SkupLinkService.Controller(CtrlCode);
 end;

function TSkupLinkService.GetServiceController: TServiceController;
 begin
  Result := ServiceController;
 end;

procedure TSkupLinkService.ServiceCreate(Sender: TObject);
 begin
  // Canonical name: Common.STR_SERVICE_DISPLAY_NAME (dfm value is overridden).
  DisplayName := STR_SERVICE_DISPLAY_NAME;
 end;

procedure TSkupLinkService.ServiceAfterInstall(Sender: TService);
 var
  Reg: TRegistry;

 begin
  // TService has DisplayName but no Description; SCM reads it from the registry.
  Reg := TRegistry.Create(KEY_READ or KEY_WRITE);

  try
   Reg.RootKey := HKEY_LOCAL_MACHINE;

   if Reg.OpenKey('\SYSTEM\CurrentControlSet\Services\' + Name, FALSE) then
    try
     Reg.WriteString('Description', STR_SERVICE_DESCRIPTION);
    finally
     Reg.CloseKey;
    end;
  finally
   Reg.Free;
  end;
 end;

procedure TSkupLinkService.ServiceStart(Sender: TService; var Started: Boolean);
 begin
  Started := FALSE;

  try
   FHost := TServiceHost.Create;
   FHost.Start;
   Started := TRUE;
  except
   on E: Exception do
    begin
     DebugLogSilentExcept('TSkupLinkService.ServiceStart', E.Message);
     FreeAndNil(FHost);
     Started := FALSE;
    end;
  end;
 end;

procedure TSkupLinkService.ServiceStop(Sender: TService; var Stopped: Boolean);
 begin
  Stopped := TRUE;

  try
   if FHost <> nil then
    begin
     FHost.Stop;
     FreeAndNil(FHost);
    end;
  except
   on E: Exception do
    begin
     DebugLogSilentExcept('TSkupLinkService.ServiceStop', E.Message);
     FreeAndNil(FHost);
    end;
  end;
 end;

procedure TSkupLinkService.ServiceShutdown(Sender: TService);
 var
  Stopped: Boolean;

 begin
  ServiceStop(Sender, Stopped);
 end;

{$ELSE}

interface

implementation

{$ENDIF}

end.
