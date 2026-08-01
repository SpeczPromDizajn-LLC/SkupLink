object FormTray: TFormTray
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'SkupLinkTray'
  ClientHeight = 153
  ClientWidth = 406
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object TimerPoll: TTimer
    Enabled = False
    Interval = 3000
    OnTimer = TimerPollTimer
    Left = 24
    Top = 16
  end
  object PopupMenu: TPopupMenu
    Left = 120
    Top = 16
    object miOpen: TMenuItem
      Caption = 'Open'
      Default = True
      OnClick = miOpenClick
    end
    object miSep: TMenuItem
      Caption = '-'
    end
    object miExit: TMenuItem
      Caption = 'Exit'
      OnClick = miExitClick
    end
  end
end
