unit uMain;

interface

uses
 Winapi.Windows,
 Winapi.Messages,
 Winapi.ShellAPI,
 System.SysUtils,
 System.Classes,
 Vcl.Graphics,
 Vcl.Controls,
 Vcl.Forms,
 Vcl.ExtCtrls,
 Vcl.Menus,
 IdHTTP;

type
 TTrayMode = (tmOffline, tmMains, tmBattery);

 TFormTray = class(TForm)
  TimerPoll: TTimer;
  PopupMenu: TPopupMenu;
  miOpen: TMenuItem;
  miSep: TMenuItem;
  miExit: TMenuItem;
  procedure FormCreate(Sender: TObject);
  procedure FormDestroy(Sender: TObject);
  procedure TimerPollTimer(Sender: TObject);
  procedure miOpenClick(Sender: TObject);
  procedure miExitClick(Sender: TObject);
 private
  FHttp:      TIdHTTP;
  FMode:      TTrayMode;
  FCharge:    Integer;
  FIconOff:   TIcon;
  FIconMain:  TIcon;
  FIconBat:   TIcon;
  FTrayAdded: Boolean;
  FHint:      string;
  procedure FillTrayData(var pNid: TNotifyIconData; pIcon: TIcon);
  procedure TrayAddOrModify(pIcon: TIcon; pAdd: Boolean);
  procedure ApplyState(pMode: TTrayMode; pCharge: Integer);
  procedure ShowNoLink;
  procedure OpenWebUi;
  procedure PollOnce;
  procedure WMTray(var Message: TMessage); message WM_USER + 42;
 public
 end;

var
 FormTray: TFormTray;

implementation

{$R *.dfm}
{$R tray_icons.res}

uses
 REST.Json,
 Common,
 uApiModels;

procedure LoadIconRes(pIcon: TIcon; const pResName: string);
 var
  Cx: Integer;
  Cy: Integer;
  H:  HICON;

 begin
  Cx := GetSystemMetrics(SM_CXSMICON);
  Cy := GetSystemMetrics(SM_CYSMICON);

  if Cx <= 0 then
   Cx := 16;

  if Cy <= 0 then
   Cy := 16;

  H := LoadImage(HInstance, PChar(pResName), IMAGE_ICON, Cx, Cy, LR_DEFAULTCOLOR);

  if H = 0 then
   H := LoadImage(HInstance, PChar(pResName), IMAGE_ICON, 16, 16, LR_DEFAULTCOLOR);

  if H = 0 then
   H := LoadIcon(HInstance, PChar(pResName));

  if H <> 0 then
   pIcon.Handle := H // TIcon owns this handle
  else
   // Shared system icon — must copy; never abort tray startup
   pIcon.Handle := CopyIcon(LoadIcon(0, IDI_APPLICATION));
 end;

procedure TFormTray.FillTrayData(var pNid: TNotifyIconData; pIcon: TIcon);
 begin
  HandleNeeded;

  FillChar(pNid, SizeOf(pNid), 0);
  pNid.cbSize := SizeOf(pNid);
  pNid.Wnd := Handle;
  pNid.uID := 0;
  pNid.uFlags := NIF_MESSAGE or NIF_ICON or NIF_TIP or NIF_GUID;
  pNid.uCallbackMessage := WM_USER + 42;

  if (pIcon <> nil) and (pIcon.Handle <> 0) then
   pNid.HICON := pIcon.Handle
  else
   pNid.HICON := LoadIcon(0, IDI_APPLICATION);

  pNid.guidItem := TRAY_ICON_GUID;
  StrLCopy(pNid.szTip, PChar(FHint), Length(pNid.szTip) - 1);
 end;

procedure TFormTray.TrayAddOrModify(pIcon: TIcon; pAdd: Boolean);
 var
  Nid: TNotifyIconData;

 begin
  FillTrayData(Nid, pIcon);

  if pAdd then
   begin
    if Shell_NotifyIcon(NIM_ADD, @Nid) then
     FTrayAdded := TRUE
    else
     FTrayAdded := Shell_NotifyIcon(NIM_MODIFY, @Nid);
   end
  else
   if FTrayAdded then
    Shell_NotifyIcon(NIM_MODIFY, @Nid);
 end;

procedure TFormTray.FormCreate(Sender: TObject);
 begin
  Visible := FALSE;

  miOpen.Caption := STR_MENU_OPEN;
  miExit.Caption := STR_MENU_EXIT;

  FMode := tmOffline;
  FCharge := -1;
  FHint := STR_HINT_NO_LINK;
  FTrayAdded := FALSE;

  FIconOff := TIcon.Create;
  FIconMain := TIcon.Create;
  FIconBat := TIcon.Create;
  LoadIconRes(FIconOff, 'TRAY_OFFLINE');
  LoadIconRes(FIconMain, 'TRAY_MAINS');
  LoadIconRes(FIconBat, 'TRAY_BATTERY');

  FHttp := TIdHTTP.Create(nil);
  FHttp.ConnectTimeout := HTTP_CONNECT_TIMEOUT_MS;
  FHttp.ReadTimeout := HTTP_READ_TIMEOUT_MS;
  FHttp.HandleRedirects := TRUE;

  TrayAddOrModify(FIconOff, TRUE);

  TimerPoll.Interval := TRAY_POLL_INTERVAL_MS;
  TimerPoll.Enabled := TRUE;
  PollOnce;
 end;

procedure TFormTray.FormDestroy(Sender: TObject);
 var
  Nid: TNotifyIconData;

 begin
  TimerPoll.Enabled := FALSE;

  if FTrayAdded then
   begin
    FillTrayData(Nid, FIconOff);
    Nid.uFlags := NIF_GUID;
    Shell_NotifyIcon(NIM_DELETE, @Nid);
    FTrayAdded := FALSE;
   end;

  FreeAndNil(FHttp);
  FreeAndNil(FIconOff);
  FreeAndNil(FIconMain);
  FreeAndNil(FIconBat);
 end;

procedure TFormTray.ApplyState(pMode: TTrayMode; pCharge: Integer);
 var
  Icon: TIcon;

 begin
  case pMode of
   tmMains:
    Icon := FIconMain;

   tmBattery:
    Icon := FIconBat;
  else
   Icon := FIconOff;
  end;

  if pMode = tmOffline then
   FHint := STR_HINT_NO_SNMP
  else
   if pCharge < 0 then
    FHint := STR_HINT_CHARGE_NA
   else
    FHint := Format(STR_HINT_CHARGE_FMT, [pCharge]);

  if not FTrayAdded then
   TrayAddOrModify(Icon, TRUE)
  else
   if (pMode <> FMode) or (pCharge <> FCharge) then
    TrayAddOrModify(Icon, FALSE);

  FMode := pMode;
  FCharge := pCharge;
 end;

procedure TFormTray.ShowNoLink;
 begin
  ApplyState(tmOffline, -1);
  FHint := STR_HINT_NO_LINK;

  if FTrayAdded then
   TrayAddOrModify(FIconOff, FALSE)
  else
   TrayAddOrModify(FIconOff, TRUE);
 end;

procedure TFormTray.OpenWebUi;
 begin
  ShellExecute(0, 'open', PChar(Format(STR_URL_WEB, [HTTP_PORT])), nil, nil, SW_SHOWNORMAL);
 end;

procedure TFormTray.PollOnce;
 var
  Url:    string;
  Body:   string;
  Tray:   TApiTrayStatus;
  Mode:   TTrayMode;
  Charge: Integer;

 begin
  if FHttp = nil then
   Exit;

  Url := Format(STR_URL_TRAY_API, [HTTP_PORT]);

  try
   Body := FHttp.Get(Url);
  except
   ShowNoLink;
   Exit;
  end;

  try
   Tray := TJson.JsonToObject<TApiTrayStatus>(Body);
  except
   Tray := nil;
  end;

  if Tray = nil then
   begin
    ShowNoLink;
    Exit;
   end;

  try
   if (not Tray.ok) or (not Tray.snmp_connected) then
    Mode := tmOffline
   else
    if Tray.on_battery then
     Mode := tmBattery
    else
     Mode := tmMains;

   Charge := Tray.charge_percent;

   if Mode = tmOffline then
    Charge := -1;

   ApplyState(Mode, Charge);
  finally
   Tray.Free;
  end;
 end;

procedure TFormTray.TimerPollTimer(Sender: TObject);
 begin
  PollOnce;
 end;

procedure TFormTray.WMTray(var Message: TMessage);
 var
  Ev: Integer;
  Pt: TPoint;

 begin
  Ev := LoWord(Message.LParam);

  case Ev of
   WM_LBUTTONDBLCLK:
    OpenWebUi;

   WM_RBUTTONUP:
    begin
     SetForegroundWindow(Handle);
     GetCursorPos(Pt);
     PopupMenu.Popup(Pt.X, Pt.Y);
     PostMessage(Handle, WM_NULL, 0, 0);
    end;
  end;
 end;

procedure TFormTray.miOpenClick(Sender: TObject);
 begin
  OpenWebUi;
 end;

procedure TFormTray.miExitClick(Sender: TObject);
 begin
  Close;
 end;

end.
