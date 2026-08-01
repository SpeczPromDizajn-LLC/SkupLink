unit uServiceHost;

// Cross-platform host: SNMP poll loop + HTTP API.
// Used by Windows TService and Linux/console entry points.

interface

uses
 System.SysUtils,
 System.Classes,
 System.SyncObjs,
 Common,
 uAppConfig,
 uSnmpUpsClient,
 uHttpApiServer,
 uAuth,
 uHistoryStore,
 uShutdownWatch;

type
 TServiceHost = class
 private
  FConfig:    TAppConfig;
  FHistory:   THistoryStore;
  FShutdown:  TShutdownWatch;
  FAuth:      TAuthService;
  FSnmp:      TSnmpUpsClient;
  FHttp:      THttpApiServer;
  FStopEvent: TEvent;
  FThread:    TThread;
  FStarted:   Boolean;
 public
  constructor Create;
  destructor Destroy; override;

  procedure Start;
  procedure RequestStop;
  procedure Stop;
  procedure RunUntilStopped;

  property Config: TAppConfig read FConfig;
  property Snmp: TSnmpUpsClient read FSnmp;
 end;

implementation

type
 TPollThread = class(TThread)
 private
  FHost: TServiceHost;
 protected
  procedure Execute; override;
 public
  constructor Create(pHost: TServiceHost);
 end;

 // TPollThread

constructor TPollThread.Create(pHost: TServiceHost);
 begin
  // Assign before inherited Create — Execute may start immediately.
  FHost := pHost;
  inherited Create(FALSE);
  FreeOnTerminate := FALSE;
 end;

procedure TPollThread.Execute;
 begin
  while not Terminated do
   begin
    try
     FHost.FSnmp.PollOnce;
    except
     // Keep service alive; snmp_connected reflects the failure.
    end;

    if Terminated then
     Break;

    if FHost.FStopEvent.WaitFor(POLL_INTERVAL_SECONDS * 1000) <> wrTimeout then
     Break;
   end;
 end;

// TServiceHost

constructor TServiceHost.Create;
 begin
  inherited Create;
  FStopEvent := TEvent.Create(nil, TRUE, FALSE, '');
  FConfig := TAppConfig.Create;

  try
   FConfig.Load;
  except
   // Keep in-memory defaults if config file is missing/unreadable.
  end;

  FHistory := THistoryStore.Create;
  FShutdown := TShutdownWatch.Create(FConfig);
  FAuth := TAuthService.Create(FConfig);
  FSnmp := TSnmpUpsClient.Create(FConfig, FHistory, FShutdown);
  FHttp := THttpApiServer.Create(FConfig, FSnmp, FAuth, FHistory);
 end;

destructor TServiceHost.Destroy;
 begin
  Stop;
  FHttp.Free;
  FSnmp.Free;
  FAuth.Free;
  FShutdown.Free;
  FHistory.Free;
  FConfig.Free;
  FStopEvent.Free;
  inherited Destroy;
 end;

procedure TServiceHost.Start;
 begin
  if FStarted then
   Exit;

  FStopEvent.ResetEvent;

  try
   FHttp.Start;
   FThread := TPollThread.Create(Self);
   FStarted := TRUE;
  except
   if FThread <> nil then
    begin
     FThread.Terminate;
     FThread.WaitFor;
     FreeAndNil(FThread);
    end;

   try
    FHttp.Stop;
   except
    on E: Exception do
     ;
   end;

   raise;
  end;
 end;

procedure TServiceHost.RequestStop;
 begin
  FStopEvent.SetEvent;
 end;

procedure TServiceHost.Stop;
 begin
  RequestStop;

  if not FStarted then
   Exit;

  if FThread <> nil then
   begin
    FThread.Terminate;
    FThread.WaitFor;
    FreeAndNil(FThread);
   end;

  try
   FHttp.Stop;
  except
   on E: Exception do
    ;
  end;

  FStarted := FALSE;
 end;

procedure TServiceHost.RunUntilStopped;
 begin
  Start;

  try
   while FStopEvent.WaitFor(1000) = wrTimeout do
    begin
     // Idle until RequestStop / signal.
    end;
  finally
   Stop;
  end;
 end;

end.
