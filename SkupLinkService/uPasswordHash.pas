unit uPasswordHash;

// PBKDF2-HMAC-SHA256 password hashing with per-password random salt.
// Stored form: pbkdf2-sha256$<iterations>$<salt_hex>$<dk_hex>

interface

uses
 System.SysUtils;

function HashPassword(const pPassword: string): string;
function VerifyPassword(const pPassword, pEncoded: string): Boolean;

implementation

uses
 System.Hash;

const
 STR_PBKDF2_PREFIX     = 'pbkdf2-sha256';
 PBKDF2_ITERATIONS     = 210000;
 PBKDF2_SALT_BYTES     = 16;
 PBKDF2_DK_BYTES       = 32;

function BytesToHex(const pBytes: TBytes): string;
 begin
  Result := LowerCase(THash.DigestAsString(pBytes));
 end;

function HexToBytes(const pHex: string): TBytes;
 var
  Hex: string;
  i:   Integer;
  n:   Integer;

 begin
  Hex := LowerCase(Trim(pHex));

  if (Length(Hex) = 0) or ((Length(Hex) mod 2) <> 0) then
   Exit(nil);

  SetLength(Result, Length(Hex) div 2);

  for i := 0 to High(Result) do
   begin
    if not TryStrToInt('$' + Copy(Hex, i * 2 + 1, 2), n) then
     Exit(nil);

    Result[i] := Byte(n);
   end;
 end;

function RandomSalt(pLen: Integer): TBytes;
 var
  Guid: TGUID;
  Pos:  Integer;
  n:    Integer;

 begin
  SetLength(Result, pLen);
  Pos := 0;

  while Pos < pLen do
   begin
    if CreateGUID(Guid) <> 0 then
     raise Exception.Create('Cannot generate password salt');

    n := SizeOf(Guid);

    if n > (pLen - Pos) then
     n := pLen - Pos;

    Move(Guid, Result[Pos], n);
    Inc(Pos, n);
   end;
 end;

function Pbkdf2HmacSha256(const pPassword, pSalt: TBytes; pIterations, pDkLen: Integer): TBytes;
 var
  HLen:      Integer;
  Blocks:    Integer;
  BlockIdx:  Integer;
  Iter:      Integer;
  ByteIdx:   Integer;
  SaltBlock: TBytes;
  U:         TBytes;
  T:         TBytes;
  OutPos:    Integer;

 begin
  if (pIterations < 1) or (pDkLen < 1) then
   raise Exception.Create('Invalid PBKDF2 parameters');

  HLen := 32;
  Blocks := (pDkLen + HLen - 1) div HLen;
  SetLength(Result, Blocks * HLen);
  OutPos := 0;

  for BlockIdx := 1 to Blocks do
   begin
    SetLength(SaltBlock, Length(pSalt) + 4);

    if Length(pSalt) > 0 then
     Move(pSalt[0], SaltBlock[0], Length(pSalt));

    SaltBlock[Length(pSalt)] := Byte(BlockIdx shr 24);
    SaltBlock[Length(pSalt) + 1] := Byte(BlockIdx shr 16);
    SaltBlock[Length(pSalt) + 2] := Byte(BlockIdx shr 8);
    SaltBlock[Length(pSalt) + 3] := Byte(BlockIdx);

    U := THashSHA2.GetHMACAsBytes(SaltBlock, pPassword, THashSHA2.TSHA2Version.SHA256);
    T := Copy(U);

    for Iter := 2 to pIterations do
     begin
      U := THashSHA2.GetHMACAsBytes(U, pPassword, THashSHA2.TSHA2Version.SHA256);

      for ByteIdx := 0 to High(T) do
       T[ByteIdx] := T[ByteIdx] xor U[ByteIdx];
     end;

    Move(T[0], Result[OutPos], HLen);
    Inc(OutPos, HLen);
   end;

  SetLength(Result, pDkLen);
 end;

function FixedTimeEquals(const pA, pB: TBytes): Boolean;
 var
  Diff: Integer;
  i:    Integer;

 begin
  if Length(pA) <> Length(pB) then
   Exit(FALSE);

  Diff := 0;

  for i := 0 to High(pA) do
   Diff := Diff or (pA[i] xor pB[i]);

  Result := Diff = 0;
 end;

function HashPassword(const pPassword: string): string;
 var
  Salt: TBytes;
  Dk:   TBytes;

 begin
  Salt := RandomSalt(PBKDF2_SALT_BYTES);
  Dk := Pbkdf2HmacSha256(TEncoding.UTF8.GetBytes(pPassword), Salt, PBKDF2_ITERATIONS, PBKDF2_DK_BYTES);
  Result := Format('%s$%d$%s$%s', [STR_PBKDF2_PREFIX, PBKDF2_ITERATIONS, BytesToHex(Salt), BytesToHex(Dk)]);
 end;

function VerifyPassword(const pPassword, pEncoded: string): Boolean;
 var
  Parts:      TArray<string>;
  Iterations: Integer;
  Salt:       TBytes;
  Expected:   TBytes;
  Actual:     TBytes;

 begin
  Result := FALSE;
  Parts := pEncoded.Trim.Split(['$']);

  if Length(Parts) <> 4 then
   Exit;

  if not SameText(Parts[0], STR_PBKDF2_PREFIX) then
   Exit;

  if not TryStrToInt(Parts[1], Iterations) or (Iterations < 1) then
   Exit;

  Salt := HexToBytes(Parts[2]);
  Expected := HexToBytes(Parts[3]);

  if (Length(Salt) = 0) or (Length(Expected) = 0) then
   Exit;

  Actual := Pbkdf2HmacSha256(TEncoding.UTF8.GetBytes(pPassword), Salt, Iterations, Length(Expected));
  Result := FixedTimeEquals(Actual, Expected);
 end;

end.
