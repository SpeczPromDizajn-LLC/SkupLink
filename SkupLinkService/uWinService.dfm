object SkupLinkService: TSkupLinkService
  OnCreate = ServiceCreate
  DisplayName = 'SkupLink UPS SNMP Agent'
  AfterInstall = ServiceAfterInstall
  OnShutdown = ServiceShutdown
  OnStart = ServiceStart
  OnStop = ServiceStop
  Height = 150
  Width = 215
end
