program SkupLinkTests;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}
{$R *.res}

uses
 System.SysUtils,
 DUnitX.TestFramework,
 DUnitX.Loggers.Console,
 DUnitX.Loggers.Xml.NUnit,
 Common in '..\..\SkupLinkService\Common.pas',
 uUpsModels in '..\..\SkupLinkService\uUpsModels.pas',
 TestDetectTopology in 'TestDetectTopology.pas',
 TestNormalizeSnmpVersion in 'TestNormalizeSnmpVersion.pas';

var
 runner:      ITestRunner;
 results:     IRunResults;
 logger:      ITestLogger;
 nunitLogger: ITestLogger;

begin
 try
  TDUnitX.CheckCommandLine;
  runner := TDUnitX.CreateRunner;
  runner.UseRTTI := TRUE;
  logger := TDUnitXConsoleLogger.Create(TRUE);
  runner.AddLogger(logger);

  // Optional NUnit XML when --xml:<file> is passed (CI-friendly).
  if TDUnitX.Options.XMLOutputFile <> '' then
   begin
    nunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    runner.AddLogger(nunitLogger);
   end;

  results := runner.Execute;
  if not results.AllPassed then
   System.ExitCode := 1;

{$IFNDEF CI}
  if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
   begin
    System.Write('Done.. press <Enter> key to quit.');
    System.Readln;
   end;
{$ENDIF}
 except
  on E: Exception do
   begin
    System.Writeln(E.ClassName, ': ', E.Message);
    System.ExitCode := 1;
   end;
 end;

end.
