unit uAuth;

// Session tokens for the web UI / API.
// Password is stored as PBKDF2-HMAC-SHA256 with random salt (see uPasswordHash).

interface

uses
 System.SysUtils,
 System.Classes,
 System.SyncObjs,
 System.Generics.Collections,
 Common,
 uAppConfig;

type
 TAuthSession = record
 public
  Token:     string;
  ExpiresAt: TDateTime;
 end;

 TAuthService = class
 private
  FConfig:   TAppConfig;
  FLock:     TCriticalSection;
  FSessions: TDictionary<string, TDateTime>;
  procedure PurgeExpired;
 public
  constructor Create(pConfig: TAppConfig);
  destructor Destroy; override;

  function Login(const pPassword: string; out pToken: string): Boolean;
  procedure Logout(const pToken: string);
  function IsValidToken(const pToken: string): Boolean;
  function ChangePassword(const pOldPassword, pNewPassword: string): Boolean;
 end;

implementation

uses
 System.DateUtils,
 uPasswordHash;

constructor TAuthService.Create(pConfig: TAppConfig);
 begin
  inherited Create;
  FConfig := pConfig;
  FLock := TCriticalSection.Create;
  FSessions := TDictionary<string, TDateTime>.Create;
 end;

destructor TAuthService.Destroy;
 begin
  FSessions.Free;
  FLock.Free;
  inherited Destroy;
 end;

procedure TAuthService.PurgeExpired;
 var
  NowAt: TDateTime;
  Keys:  TArray<string>;

 begin
  NowAt := Now;
  Keys := FSessions.Keys.ToArray;

  for var Key in Keys do
   if FSessions.Items[Key] < NowAt then
    FSessions.Remove(Key);
 end;

function TAuthService.Login(const pPassword: string; out pToken: string): Boolean;
 var
  Snap: TAppConfigData;

 begin
  pToken := '';
  Result := FALSE;
  Snap := FConfig.Snapshot;

  try
   if not VerifyPassword(pPassword, Snap.password_hash) then
    Exit;

   FLock.Enter;
   try
    PurgeExpired;
    pToken := LowerCase(StringReplace(StringReplace(StringReplace(GUIDToString(TGUID.NewGuid), '{', '', [rfReplaceAll]), '}', '', [rfReplaceAll]), '-', '',
     [rfReplaceAll]));
    FSessions.AddOrSetValue(pToken, IncSecond(Now, AUTH_SESSION_TTL_SECONDS));
    Result := TRUE;
   finally
    FLock.Leave;
   end;
  finally
   Snap.Free;
  end;
 end;

procedure TAuthService.Logout(const pToken: string);
 begin
  if Trim(pToken) = '' then
   Exit;

  FLock.Enter;
  try
   FSessions.Remove(pToken);
  finally
   FLock.Leave;
  end;
 end;

function TAuthService.IsValidToken(const pToken: string): Boolean;
 var
  Exp: TDateTime;

 begin
  Result := FALSE;

  if Trim(pToken) = '' then
   Exit;

  FLock.Enter;
  try
   PurgeExpired;

   if not FSessions.TryGetValue(pToken, Exp) then
    Exit;

   if Exp < Now then
    begin
     FSessions.Remove(pToken);
     Exit;
    end;

   // Sliding expiry on activity.
   FSessions.AddOrSetValue(pToken, IncSecond(Now, AUTH_SESSION_TTL_SECONDS));
   Result := TRUE;
  finally
   FLock.Leave;
  end;
 end;

function TAuthService.ChangePassword(const pOldPassword, pNewPassword: string): Boolean;
 var
  Snap: TAppConfigData;

 begin
  if Length(Trim(pNewPassword)) < 4 then
   raise Exception.Create(STR_ERR_NEW_PASSWORD_TOO_SHORT);

  Snap := FConfig.Snapshot;

  try
   if not VerifyPassword(pOldPassword, Snap.password_hash) then
    raise Exception.Create(STR_ERR_CURRENT_PASSWORD_INCORRECT);

   Snap.password_hash := HashPassword(Trim(pNewPassword));
   FConfig.UpdateFrom(Snap);
   Result := TRUE;
  finally
   Snap.Free;
  end;
 end;

end.
