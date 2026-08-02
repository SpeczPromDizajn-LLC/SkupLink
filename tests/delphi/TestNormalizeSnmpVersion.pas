unit TestNormalizeSnmpVersion;

interface

uses
  DUnitX.TestFramework,
  Common;

type
  [TestFixture]
  TNormalizeSnmpVersionTests = class
  public
    [Test]
    procedure Maps2And2cTo2c;
    [Test]
    procedure Maps1AndUnknownTo1;
  end;

implementation

procedure TNormalizeSnmpVersionTests.Maps2And2cTo2c;
begin
  Assert.AreEqual(STR_SNMP_VERSION_2C, NormalizeSnmpVersion('2c'));
  Assert.AreEqual(STR_SNMP_VERSION_2C, NormalizeSnmpVersion('2'));
  Assert.AreEqual(STR_SNMP_VERSION_2C, NormalizeSnmpVersion(' 2C '));
end;

procedure TNormalizeSnmpVersionTests.Maps1AndUnknownTo1;
begin
  Assert.AreEqual(STR_SNMP_VERSION_1, NormalizeSnmpVersion('1'));
  Assert.AreEqual(STR_SNMP_VERSION_1, NormalizeSnmpVersion(''));
  Assert.AreEqual(STR_SNMP_VERSION_1, NormalizeSnmpVersion('3'));
end;

end.
