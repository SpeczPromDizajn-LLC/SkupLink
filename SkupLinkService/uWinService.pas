unit uWinService;

{$IFDEF MSWINDOWS}

interface

uses
 Winapi.Windows,
 Winapi.Messages,
 System.SysUtils,
 System.Classes,
 System.Win.Registry,
 Vcl.Graphics,
 Vcl.Controls,
 Vcl.SvcMgr,
 Vcl.Dialogs,
 Common,
 uServiceHost;

type
 TSkupLinkService = class(TService)
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
   FreeAndNil(FHost);
   Started := FALSE;
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
   FreeAndNil(FHost);
  end;
 end;

procedure TSkupLinkService.ServiceShutdown(Sender: TService);
 var
  Stopped: Boolean;

 begin
  ServiceStop(Sender, Stopped);
 end;

end.

{$ELSE}

interface

implementation

end.

{$ENDIF}
