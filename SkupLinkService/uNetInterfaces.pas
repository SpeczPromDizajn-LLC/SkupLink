unit uNetInterfaces;

// Enumerate IPv4 broadcast addresses for all non-loopback adapters
// (LAN, Wi-Fi, VPN), same approach as KortexUpdate NetParams.EnumNetInterfaces.

interface

uses
 System.SysUtils,
 System.Classes;

function EnumBroadcastAddresses: TArray<string>;

implementation

{$IFDEF MSWINDOWS}
uses
 Winapi.Windows,
 Winapi.Winsock;

const
 SIO_GET_INTERFACE_LIST = $4004747F;

type
 SockAddrGen = packed record
 public
  AddressIn: sockaddr_in;
  filler:    packed array [0 .. 7] of AnsiChar;
 end;

 INTERFACE_INFO = packed record
 public
  iiFlags:            u_long;
  iiAddress:          SockAddrGen;
  iiBroadcastAddress: SockAddrGen;
  iiNetmask:          SockAddrGen;
 end;

function WSAIoctl(s: TSocket; cmd: DWORD; lpInBuffer: Pointer; dwInBufferLen: DWORD; lpOutBuffer: Pointer; dwOutBufferLen: DWORD;
 lpdwOutBytesReturned: LPDWORD; lpOverLapped: Pointer; lpOverLappedRoutine: Pointer): Integer; stdcall; external 'WS2_32.DLL' name 'WSAIoctl';
{$ENDIF}

function EnumBroadcastAddresses: TArray<string>;
 var
  List: TStringList;
{$IFDEF MSWINDOWS}
  sock:          TSocket;
  wsaD:          WSADATA;
  NumInterfaces: Integer;
  BytesReturned: u_long;
  Buffer:        array [0 .. 31] of INTERFACE_INFO;
  i:             Integer;
  ip, mask, broadcast: TInAddr;
  ipS, broadcastS: string;
{$ENDIF}

 begin
  List := TStringList.Create;
  try
   List.Sorted := TRUE;
   List.Duplicates := dupIgnore;

{$IFDEF MSWINDOWS}
   FillChar(wsaD, SizeOf(wsaD), 0);

   if WSAStartup($0101, wsaD) = 0 then
    try
     sock := Socket(AF_INET, SOCK_STREAM, 0);

     if sock <> INVALID_SOCKET then
      try
       BytesReturned := 0;

       if WSAIoctl(sock, SIO_GET_INTERFACE_LIST, nil, 0, @Buffer, SizeOf(Buffer), @BytesReturned, nil, nil) <> SOCKET_ERROR then
        begin
         NumInterfaces := Integer(BytesReturned) div SizeOf(INTERFACE_INFO);

         for i := 0 to NumInterfaces - 1 do
          begin
           ip := Buffer[i].iiAddress.AddressIn.sin_addr;
           mask := Buffer[i].iiNetmask.AddressIn.sin_addr;
           broadcast.S_addr := ip.S_addr or (not mask.S_addr);

           ipS := string(AnsiString(inet_ntoa(ip)));
           broadcastS := string(AnsiString(inet_ntoa(broadcast)));

           if (ipS <> '') and (ipS <> '127.0.0.1') and (broadcastS <> '') and (broadcastS <> '0.0.0.0') then
            List.Add(broadcastS);
          end;
        end;
      finally
       CloseSocket(sock);
      end;
    finally
     WSACleanup;
    end;
{$ENDIF}

   // Always include limited broadcast as a fallback (and for non-Windows).
   List.Add('255.255.255.255');

   SetLength(Result, List.Count);
   for var n := 0 to List.Count - 1 do
    Result[n] := List[n];
  finally
   List.Free;
  end;
 end;

end.
