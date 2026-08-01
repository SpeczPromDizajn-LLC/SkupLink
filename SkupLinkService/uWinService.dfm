object SkupLinkService: TSkupLinkService
  OldCreateOrder = False
  DisplayName = 'SkupLink UPS SNMP Agent'
  AfterInstall = ServiceAfterInstall
  OnShutdown = ServiceShutdown
  OnStart = ServiceStart
  OnStop = ServiceStop
  Height = 150
  Width = 215
end
