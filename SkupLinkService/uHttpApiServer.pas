unit uHttpApiServer;

// HTTP API + static web UI (web/).
// Public:  GET /health, GET /api/tray, POST /api/login, static assets
// Authed:  UPS / settings / history / password / discover / logout

interface

uses
 System.SysUtils,
 System.Classes,
 IdContext,
 IdCustomHTTPServer,
 IdHTTPServer,
 Common,
 uAppConfig,
 uSnmpUpsClient,
 uAuth,
 uHistoryStore,
 uUdpDiscover;

type
 THttpApiServer = class
 private
  FServer:   TIdHTTPServer;
  FConfig:   TAppConfig;
  FSnmp:     TSnmpUpsClient;
  FAuth:     TAuthService;
  FHistory:  THistoryStore;
  FDiscover: TUdpDiscover;
  FWebRoot:  string;

  procedure HandleCommandGet(pContext: TIdContext; pRequestInfo: TIdHTTPRequestInfo; pResponseInfo: TIdHTTPResponseInfo);
  procedure HandleCommandOther(pContext: TIdContext; pRequestInfo: TIdHTTPRequestInfo; pResponseInfo: TIdHTTPResponseInfo);
  procedure WriteJson(pResponseInfo: TIdHTTPResponseInfo; pCode: Integer; const pBody: string);
  procedure WriteError(pResponseInfo: TIdHTTPResponseInfo; pCode: Integer; const pMessage: string);
  procedure WritePlain(pResponseInfo: TIdHTTPResponseInfo; pCode: Integer; const pBody, pContentType: string);
  function NormalizePath(const pPath: string): string;
  function ReadRequestBody(pRequestInfo: TIdHTTPRequestInfo): string;
  function ExtractToken(pRequestInfo: TIdHTTPRequestInfo): string;
  function RequireAuth(pRequestInfo: TIdHTTPRequestInfo; pResponseInfo: TIdHTTPResponseInfo): Boolean;
  function MimeForExt(const pExt: string): string;
  function TryServeStatic(const pPath: string; pResponseInfo: TIdHTTPResponseInfo): Boolean;
  procedure HandleLogin(const pBody: string; pResponseInfo: TIdHTTPResponseInfo);
  procedure HandlePassword(const pBody: string; pResponseInfo: TIdHTTPResponseInfo);
  procedure HandleDiscover(pResponseInfo: TIdHTTPResponseInfo);
 public
  constructor Create(pConfig: TAppConfig; pSnmp: TSnmpUpsClient; pAuth: TAuthService; pHistory: THistoryStore);
  destructor Destroy; override;

  procedure Start;
  procedure Stop;
 end;

implementation

uses
 System.IOUtils,
 System.StrUtils,
 IdGlobal,
 IdSocketHandle,
 REST.Json,
 uApiModels;

// THttpApiServer

constructor THttpApiServer.Create(pConfig: TAppConfig; pSnmp: TSnmpUpsClient; pAuth: TAuthService; pHistory: THistoryStore);
 begin
  inherited Create;
  FConfig := pConfig;
  FSnmp := pSnmp;
  FAuth := pAuth;
  FHistory := pHistory;
  FDiscover := TUdpDiscover.Create;
{$IFDEF DEBUG}
  FWebRoot := TPath.Combine(GetCurrentDir, STR_WEB_FOLDER);

  if not TDirectory.Exists(FWebRoot) then
   FWebRoot := TPath.Combine(ExtractFilePath(ParamStr(0)), STR_WEB_FOLDER);
{$ELSE}
  FWebRoot := TPath.Combine(ExtractFilePath(ParamStr(0)), STR_WEB_FOLDER);
{$ENDIF}
  FServer := TIdHTTPServer.Create(nil);
  FServer.OnCommandGet := HandleCommandGet;
  FServer.OnCommandOther := HandleCommandOther;
 end;

destructor THttpApiServer.Destroy;
 begin
  Stop;
  FServer.Free;
  FDiscover.Free;
  inherited Destroy;
 end;

procedure THttpApiServer.Start;
 var
  Binding: TIdSocketHandle;

 begin
  if FServer.Active then
   FServer.Active := FALSE;

  // Avoid leftover exclusive bind after DEBUG restart.
  FServer.ReuseSocket := rsTrue;
  FServer.DefaultPort := HTTP_PORT;
  FServer.Bindings.Clear;
  Binding := FServer.Bindings.Add;
  Binding.IP := '0.0.0.0';
  Binding.Port := HTTP_PORT;
  Binding.IPVersion := Id_IPv4;

  try
   FServer.Active := TRUE;
  except
   on E: Exception do
    raise Exception.CreateFmt(STR_ERR_HTTP_BIND, [HTTP_PORT, E.Message]);
  end;
 end;

procedure THttpApiServer.Stop;
 begin
  if FServer.Active then
   FServer.Active := FALSE;
 end;

function THttpApiServer.NormalizePath(const pPath: string): string;
 begin
  Result := LowerCase(Trim(pPath));
  if Result = '' then
   Result := '/';

  while (Length(Result) > 1) and (Result[Length(Result)] = '/') do
   Delete(Result, Length(Result), 1);
 end;

procedure THttpApiServer.WriteJson(pResponseInfo: TIdHTTPResponseInfo; pCode: Integer; const pBody: string);
 begin
  pResponseInfo.ContentType := 'application/json; charset=utf-8';
  pResponseInfo.CharSet := 'utf-8';
  pResponseInfo.ContentText := pBody;
  pResponseInfo.ResponseNo := pCode;
 end;

procedure THttpApiServer.WritePlain(pResponseInfo: TIdHTTPResponseInfo; pCode: Integer; const pBody, pContentType: string);
 begin
  pResponseInfo.ContentType := pContentType;
  pResponseInfo.ContentText := pBody;
  pResponseInfo.ResponseNo := pCode;
 end;

procedure THttpApiServer.WriteError(pResponseInfo: TIdHTTPResponseInfo; pCode: Integer; const pMessage: string);
 begin
  WriteJson(pResponseInfo, pCode, TApiError.ToJson(pMessage));
 end;

function THttpApiServer.ReadRequestBody(pRequestInfo: TIdHTTPRequestInfo): string;
 var
  SS: TStringStream;

 begin
  Result := '';

  if (pRequestInfo.PostStream <> nil) and (pRequestInfo.PostStream.Size > 0) then
   begin
    SS := TStringStream.Create('', TEncoding.UTF8);

    try
     pRequestInfo.PostStream.Position := 0;
     SS.CopyFrom(pRequestInfo.PostStream, 0);
     Result := SS.DataString;
    finally
     SS.Free;
    end;
   end
  else
   Result := pRequestInfo.UnparsedParams;
 end;

function THttpApiServer.ExtractToken(pRequestInfo: TIdHTTPRequestInfo): string;
 var
  Auth: string;

 begin
  Result := Trim(pRequestInfo.RawHeaders.Values['X-Auth-Token']);

  if Result <> '' then
   Exit;

  Auth := Trim(pRequestInfo.RawHeaders.Values['Authorization']);

  if StartsText('Bearer ', Auth) then
   Result := Trim(Copy(Auth, 8, MaxInt));
 end;

function THttpApiServer.RequireAuth(pRequestInfo: TIdHTTPRequestInfo; pResponseInfo: TIdHTTPResponseInfo): Boolean;
 begin
  Result := FAuth.IsValidToken(ExtractToken(pRequestInfo));

  if not Result then
   WriteError(pResponseInfo, 401, STR_ERR_UNAUTHORIZED);
 end;

function THttpApiServer.MimeForExt(const pExt: string): string;
 var
  Ext: string;

 begin
  Ext := LowerCase(pExt);

  if Ext = '.html' then
   Exit('text/html; charset=utf-8');

  if Ext = '.css' then
   Exit('text/css; charset=utf-8');

  if Ext = '.js' then
   Exit('application/javascript; charset=utf-8');

  if Ext = '.svg' then
   Exit('image/svg+xml');

  if Ext = '.png' then
   Exit('image/png');

  if Ext = '.ico' then
   Exit('image/x-icon');

  if Ext = '.json' then
   Exit('application/json; charset=utf-8');

  if Ext = '.woff2' then
   Exit('font/woff2');

  Exit('application/octet-stream');
 end;

function THttpApiServer.TryServeStatic(const pPath: string; pResponseInfo: TIdHTTPResponseInfo): Boolean;
 var
  Rel:  string;
  Full: string;
  Root: string;

 begin
  Result := FALSE;

  try
   if not TDirectory.Exists(FWebRoot) then
    Exit;

   if (pPath = '/') or (pPath = '') then
    Rel := 'index.html'
   else
    begin
     Rel := Copy(pPath, 2, MaxInt);
     Rel := StringReplace(Rel, '/', PathDelim, [rfReplaceAll]);
    end;

   if Pos('..', Rel) > 0 then
    Exit;

   Root := ExcludeTrailingPathDelimiter(TPath.GetFullPath(FWebRoot));
   Full := TPath.GetFullPath(TPath.Combine(FWebRoot, Rel));

   if not StartsText(Root + PathDelim, Full) then
    Exit;

   if not TFile.Exists(Full) then
    Exit;

   pResponseInfo.ContentType := MimeForExt(ExtractFileExt(Full));
   pResponseInfo.ContentStream := TFileStream.Create(Full, fmOpenRead or fmShareDenyNone);
   pResponseInfo.FreeContentStream := TRUE;
   pResponseInfo.ResponseNo := 200;
   Result := TRUE;
  except
   Result := FALSE;
  end;
 end;

procedure THttpApiServer.HandleLogin(const pBody: string; pResponseInfo: TIdHTTPResponseInfo);
 var
  Req:   TApiLoginRequest;
  Resp:  TApiLoginResponse;
  Token: string;

 begin
  try
   Req := TJson.JsonToObject<TApiLoginRequest>(pBody);
  except
   WriteError(pResponseInfo, 400, STR_ERR_INVALID_JSON_BODY);
   Exit;
  end;

  if Req = nil then
   begin
    WriteError(pResponseInfo, 400, STR_ERR_INVALID_JSON_BODY);
    Exit;
   end;

  try
   if Trim(Req.password) = '' then
    begin
     WriteError(pResponseInfo, 400, STR_ERR_PASSWORD_REQUIRED);
     Exit;
    end;

   if not FAuth.Login(Req.password, Token) then
    begin
     WriteError(pResponseInfo, 401, STR_ERR_INVALID_PASSWORD);
     Exit;
    end;

   Resp := TApiLoginResponse.Create(Token);

   try
    WriteJson(pResponseInfo, 200, TJson.ObjectToJsonString(Resp));
   finally
    Resp.Free;
   end;
  finally
   Req.Free;
  end;
 end;

procedure THttpApiServer.HandlePassword(const pBody: string; pResponseInfo: TIdHTTPResponseInfo);
 var
  Req: TApiPasswordRequest;

 begin
  try
   Req := TJson.JsonToObject<TApiPasswordRequest>(pBody);
  except
   WriteError(pResponseInfo, 400, STR_ERR_INVALID_JSON_BODY);
   Exit;
  end;

  if Req = nil then
   begin
    WriteError(pResponseInfo, 400, STR_ERR_INVALID_JSON_BODY);
    Exit;
   end;

  try
   if Trim(Req.old_password) = '' then
    begin
     WriteError(pResponseInfo, 400, STR_ERR_OLD_PASSWORD_REQUIRED);
     Exit;
    end;

   if Trim(Req.new_password) = '' then
    begin
     WriteError(pResponseInfo, 400, STR_ERR_NEW_PASSWORD_REQUIRED);
     Exit;
    end;

   try
    FAuth.ChangePassword(Req.old_password, Req.new_password);
    WriteJson(pResponseInfo, 200, TApiOk.TrueJson);
   except
    on E: Exception do
     WriteError(pResponseInfo, 400, E.Message);
   end;
  finally
   Req.Free;
  end;
 end;

procedure THttpApiServer.HandleCommandGet(pContext: TIdContext; pRequestInfo: TIdHTTPRequestInfo; pResponseInfo: TIdHTTPResponseInfo);
 var
  Path:   string;
  Method: string;

 begin
  try
   Path := NormalizePath(pRequestInfo.Document);
   Method := UpperCase(pRequestInfo.Command);

   // Indy routes GET, POST and HEAD to OnCommandGet (not OnCommandOther).
   if (Method = 'POST') or (Method = 'PUT') or (Method = 'DELETE') or (Method = 'PATCH') then
    begin
     HandleCommandOther(pContext, pRequestInfo, pResponseInfo);
     Exit;
    end;

   if (Method <> 'GET') and (Method <> 'HEAD') then
    begin
     WritePlain(pResponseInfo, 405, STR_ERR_METHOD_NOT_ALLOWED, 'text/plain; charset=utf-8');
     Exit;
    end;

   if Path = '/health' then
    begin
     WriteJson(pResponseInfo, 200, TApiHealth.Json);
     Exit;
    end;

   if Path = '/api/tray' then
    begin
     WriteJson(pResponseInfo, 200, FSnmp.GetTrayJson);
     Exit;
    end;

   if Path = '/api/ups' then
    begin
     if not RequireAuth(pRequestInfo, pResponseInfo) then
      Exit;

     WriteJson(pResponseInfo, 200, FSnmp.GetLastJson);
     Exit;
    end;

   if Path = '/api/settings' then
    begin
     if not RequireAuth(pRequestInfo, pResponseInfo) then
      Exit;

     WriteJson(pResponseInfo, 200, FConfig.ToPublicJson);
     Exit;
    end;

   if Path = '/api/history' then
    begin
     if not RequireAuth(pRequestInfo, pResponseInfo) then
      Exit;

     WriteJson(pResponseInfo, 200, FHistory.ToJson);
     Exit;
    end;

   if Path = '/api/discover' then
    begin
     if not RequireAuth(pRequestInfo, pResponseInfo) then
      Exit;

     HandleDiscover(pResponseInfo);
     Exit;
    end;

   // Web UI and static assets (/, /app.css, …)
   if not StartsText('/api/', Path) then
    begin
     if TryServeStatic(Path, pResponseInfo) then
      Exit;
    end;

   WritePlain(pResponseInfo, 404, STR_ERR_NOT_FOUND, 'text/plain; charset=utf-8');
  except
   on E: Exception do
    WriteError(pResponseInfo, 500, STR_ERR_INTERNAL);
  end;
 end;

procedure THttpApiServer.HandleCommandOther(pContext: TIdContext; pRequestInfo: TIdHTTPRequestInfo; pResponseInfo: TIdHTTPResponseInfo);
 var
  Path:   string;
  Method: string;
  Body:   string;

 begin
  try
   Path := NormalizePath(pRequestInfo.Document);
   Method := UpperCase(pRequestInfo.Command);

   if Method = 'GET' then
    begin
     HandleCommandGet(pContext, pRequestInfo, pResponseInfo);
     Exit;
    end;

   if Method = 'POST' then
    begin
     if Path = '/api/login' then
      begin
       Body := ReadRequestBody(pRequestInfo);
       HandleLogin(Body, pResponseInfo);
       Exit;
      end;

     if Path = '/api/logout' then
      begin
       if not RequireAuth(pRequestInfo, pResponseInfo) then
        Exit;

       FAuth.Logout(ExtractToken(pRequestInfo));
       WriteJson(pResponseInfo, 200, TApiOk.TrueJson);
       Exit;
      end;

     if Path = '/api/password' then
      begin
       if not RequireAuth(pRequestInfo, pResponseInfo) then
        Exit;

       Body := ReadRequestBody(pRequestInfo);
       HandlePassword(Body, pResponseInfo);
       Exit;
      end;

     if Path = '/api/settings' then
      begin
       if not RequireAuth(pRequestInfo, pResponseInfo) then
        Exit;

       Body := ReadRequestBody(pRequestInfo);

       if Trim(Body) = '' then
        begin
         WriteError(pResponseInfo, 400, STR_ERR_EMPTY_JSON_BODY);
         Exit;
        end;

       try
        FConfig.ApplyJson(Body);
        WriteJson(pResponseInfo, 200, FConfig.ToPublicJson);
       except
        on E: Exception do
         WriteError(pResponseInfo, 400, E.Message);
       end;

       Exit;
      end;

     if Path = '/api/discover' then
      begin
       if not RequireAuth(pRequestInfo, pResponseInfo) then
        Exit;

       HandleDiscover(pResponseInfo);
       Exit;
      end;
    end;

   WritePlain(pResponseInfo, 405, STR_ERR_METHOD_NOT_ALLOWED, 'text/plain; charset=utf-8');
  except
   on E: Exception do
    WriteError(pResponseInfo, 500, STR_ERR_INTERNAL);
  end;
 end;

procedure THttpApiServer.HandleDiscover(pResponseInfo: TIdHTTPResponseInfo);
 begin
  try
   WriteJson(pResponseInfo, 200, FDiscover.Scan);
  except
   on E: Exception do
    WriteError(pResponseInfo, 400, E.Message);
  end;
 end;

end.
