unit uSnmpOids;

// Helpers for indexed RFC 1628 UPS-MIB OIDs (constants in Common.pas).

interface

function OidInputFrequency(pLine: Integer): string;
function OidInputVoltage(pLine: Integer): string;
function OidOutputVoltage(pLine: Integer): string;
function OidOutputPower(pLine: Integer): string;
function OidOutputPercentLoad(pLine: Integer): string;

implementation

uses
 System.SysUtils,
 Common;

function OidInputFrequency(pLine: Integer): string;
 begin
  Result := OID_upsInputFrequencyBase + pLine.ToString;
 end;

function OidInputVoltage(pLine: Integer): string;
 begin
  Result := OID_upsInputVoltageBase + pLine.ToString;
 end;

function OidOutputVoltage(pLine: Integer): string;
 begin
  Result := OID_upsOutputVoltageBase + pLine.ToString;
 end;

function OidOutputPower(pLine: Integer): string;
 begin
  Result := OID_upsOutputPowerBase + pLine.ToString;
 end;

function OidOutputPercentLoad(pLine: Integer): string;
 begin
  Result := OID_upsOutputPercentLoadBase + pLine.ToString;
 end;

end.
